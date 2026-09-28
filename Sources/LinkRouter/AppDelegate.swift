import AppKit
import Combine
import LinkRouterCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let store = ConfigStore()
    let picker = PickerController()
    private(set) lazy var settings = SettingsWindowController(store: store)
    private var statusItem: NSStatusItem?
    private var cancellables: Set<AnyCancellable> = []
    private var debugHooks: DebugHooks?

    func applicationWillFinishLaunching(_ notification: Notification) {
        // Our own GURL handler (instead of application(_:open:)) so we can read
        // the sender PID — that's how rules know which app a link came from.
        NSAppleEventManager.shared().setEventHandler(
            self,
            andSelector: #selector(handleGetURL(_:reply:)),
            forEventClass: AEEventClass(kInternetEventClass),
            andEventID: AEEventID(kAEGetURL)
        )
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        SourceContext.startTracking()
        let firstRun = store.config.browsers.isEmpty
        store.refreshBrowsers()
        IconCache.shared.preload(store.config.enabledBrowsers)

        store.$config.map(\.showMenuBarIcon).removeDuplicates()
            .sink { [weak self] show in self?.setStatusItemVisible(show) }
            .store(in: &cancellables)

        if ProcessInfo.processInfo.environment["LINKROUTER_DEBUG"] == "1" {
            debugHooks = DebugHooks(app: self)
        }

        // Let a link that launched us show its picker first; offer afterwards.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            if firstRun && !self.picker.isVisible { self.settings.show(tab: .general) }
            self.offerDefaultBrowserIfNeeded()
        }
        Log.info("launched; \(store.config.browsers.count) targets, \(store.config.rules.count) rules")
    }

    /// Opening the app again (Finder, Spotlight, `open -a`) shows Settings —
    /// the way back when the menu-bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settings.show()
        return false
    }

    // MARK: - Links

    @objc private func handleGetURL(_ event: NSAppleEventDescriptor, reply: NSAppleEventDescriptor) {
        let start = DispatchTime.now()
        // Read modifiers first: ⌥ held while clicking forces the picker.
        let forcePicker = NSEvent.modifierFlags.contains(.option)
        guard let s = event.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
              let url = URL(string: s.trimmingCharacters(in: .whitespacesAndNewlines))
        else { return }
        let pid = event.attributeDescriptor(forKeyword: keySenderPIDAttr)?.int32Value
        route([url], senderPID: pid, forcePicker: forcePicker, start: start)
    }

    /// Files handed to us as the default HTML viewer.
    func application(_ application: NSApplication, open urls: [URL]) {
        guard !urls.isEmpty else { return }
        route(urls, senderPID: nil, forcePicker: NSEvent.modifierFlags.contains(.option), start: .now())
    }

    func route(_ urls: [URL], senderPID: pid_t?, forcePicker: Bool, start: DispatchTime = .now()) {
        let ctx = SourceContext.capture(url: urls[0], senderPID: senderPID)
        Log.info("link \(urls[0].absoluteString) from \(ctx.sourceBundleID ?? "?") window=\(ctx.windowTitle ?? "-") (\(Log.ms(since: start)))")

        if !forcePicker, let (rule, target) = RuleMatcher.match(store.config.rules, context: ctx, targets: store.config.browsers) {
            Log.info("rule \(rule.summary) → \(target.id)")
            Launcher.open(urls, in: target)
            store.recordLink(ctx, openedIn: target, viaRule: true)
            refreshBrowsersSoon()
            return
        }

        let targets = store.config.enabledBrowsers
        guard !targets.isEmpty else {
            settings.show(tab: .browsers)
            return
        }
        picker.show(urls: urls, context: ctx, targets: targets) { [weak self] target, remember, all in
            Launcher.open(all, in: target)
            guard let self else { return }
            self.store.recordLink(ctx, openedIn: target, viaRule: false)
            if remember {
                self.store.config.rules.append(Rule.suggested(from: ctx, targetID: target.id))
                Log.info("remembered rule for \(ctx.sourceBundleID ?? ctx.url.host ?? "?") → \(target.id)")
            }
            self.refreshBrowsersSoon()
        }
    }

    /// New Chrome profiles etc. show up without a manual re-detect; done after
    /// the link is on its way so it never delays a click.
    private func refreshBrowsersSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.store.refreshBrowsers()
            if let targets = self?.store.config.enabledBrowsers { IconCache.shared.preload(targets) }
        }
    }

    // MARK: - Default browser

    private func offerDefaultBrowserIfNeeded() {
        guard !DefaultBrowser.isDefault, !store.config.skipDefaultBrowserPrompt,
              ProcessInfo.processInfo.environment["LINKROUTER_NO_DEFAULT_PROMPT"] != "1"
        else { return }
        let alert = NSAlert()
        alert.messageText = "Make Link Router your default browser?"
        alert.informativeText = "Link Router only sees links when it's the default browser. It then opens each link in the browser or profile your rules pick — or lets you choose.\n\nCurrent default: \(DefaultBrowser.currentName ?? "unknown")."
        alert.addButton(withTitle: "Make Default")
        alert.addButton(withTitle: "Not Now")
        alert.showsSuppressionButton = true
        alert.suppressionButton?.title = "Don't ask again"
        NSApp.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        if alert.suppressionButton?.state == .on { store.config.skipDefaultBrowserPrompt = true }
        if response == .alertFirstButtonReturn { DefaultBrowser.claim() }
    }

    // MARK: - Menu bar

    private func setStatusItemVisible(_ visible: Bool) {
        if !visible {
            if let item = statusItem { NSStatusBar.system.removeStatusItem(item) }
            statusItem = nil
            return
        }
        guard statusItem == nil else { return }
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.image = MenuBarIcon.image
        item.button?.toolTip = "Link Router"
        let menu = NSMenu()
        menu.delegate = self
        item.menu = menu
        statusItem = item
    }

    @objc private func openSettings() { settings.show(tab: .general) }
    @objc private func openBrowsers() { settings.show(tab: .browsers) }
    @objc private func openRules() { settings.show(tab: .rules) }
    @objc private func makeDefault() { DefaultBrowser.claim() }
    @objc private func openClipboardLink() {
        guard let s = NSPasteboard.general.string(forType: .string)?.trimmingCharacters(in: .whitespacesAndNewlines),
              let url = URL(string: s), url.scheme?.hasPrefix("http") == true else { NSSound.beep(); return }
        route([url], senderPID: nil, forcePicker: true)
    }
}

extension AppDelegate: NSMenuDelegate {
    /// Rebuilt on open so "Make Default Browser" reflects the current state.
    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        func add(_ title: String, _ action: Selector, _ key: String = "") {
            let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
            item.target = self
            menu.addItem(item)
        }
        if !DefaultBrowser.isDefault {
            add("Make Link Router the Default Browser", #selector(makeDefault))
            menu.addItem(.separator())
        }
        add("Open Link from Clipboard…", #selector(openClipboardLink))
        menu.addItem(.separator())
        add("Settings…", #selector(openSettings), ",")
        add("Browsers…", #selector(openBrowsers))
        add("Rules…", #selector(openRules))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Link Router", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
    }
}
