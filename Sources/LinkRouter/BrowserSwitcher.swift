import AppKit
import ApplicationServices
import LinkRouterCore

/// Brings a browser — or one Chromium profile's window — to the front without
/// opening anything (the switch-browser hotkey).
///
/// A Chromium profile is switched through the browser's own Profiles menu,
/// pressed via Accessibility: Chromium then raises that profile's last active
/// window (on whichever screen or Space it is) and only opens a new window
/// when the profile has none. Command-line switches can't do this — a running
/// Chromium given `--profile-directory` and no URL always opens a new window —
/// and the Accessibility window list only covers the current Space, so
/// matching windows ourselves would miss the ones that are hardest to find.
enum BrowserSwitcher {
    static func switchTo(_ target: BrowserTarget) {
        let start = DispatchTime.now()
        let appURL = URL(fileURLWithPath: target.appPath)
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).first else {
            // Not running: launch it straight into the profile.
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            if let dir = target.profileDirectory { cfg.arguments = ["--profile-directory=\(dir)"] }
            NSWorkspace.shared.openApplication(at: appURL, configuration: cfg) { _, error in
                if let error { Log.error("switch: launch \(target.id) failed: \(error)") }
            }
            Log.info("switch → \(target.id): launched")
            return
        }

        if let dir = target.profileDirectory {
            guard let title = pressProfileMenuItem(app: app, bundleID: target.bundleID, profileDirectory: dir) else {
                Log.info("switch → \(target.id): no profile menu, activating the browser")
                Launcher.activate(target.bundleID)
                return
            }
            // Activate only once the profile's window is the browser's focused
            // one: activating right away races Chromium raising (or creating)
            // it, and macOS then switches to the Space of an older window.
            waitForFocusedWindow(of: app, titleSuffix: " - \(title)", deadline: .now() + 0.8) { found in
                Launcher.activate(target.bundleID)
                Log.info("switch → \(target.id): '\(title)' window \(found ? "focused" : "not seen") (\(Log.ms(since: start)))")
            }
            return
        }

        // A plain browser: LaunchServices' reopen brings its windows forward,
        // and opens one if it has none (like clicking its Dock icon).
        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        NSWorkspace.shared.openApplication(at: appURL, configuration: cfg) { _, error in
            if let error { Log.error("switch: reopen \(target.id) failed: \(error)") }
        }
        Log.info("switch → \(target.id): reopened (\(Log.ms(since: start)))")
    }

    /// Polls the browser's focused window until its title ends with
    /// `titleSuffix` (Chromium titles windows "<page> - Google Chrome - <profile>")
    /// or the deadline passes. Polls on the main queue; never blocks it.
    private static func waitForFocusedWindow(of app: NSRunningApplication, titleSuffix: String,
                                             deadline: DispatchTime, then done: @escaping (Bool) -> Void) {
        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 0.2)
        func poll() {
            let window: AXUIElement? = attribute(root, kAXFocusedWindowAttribute)
            let title: String? = window.flatMap { attribute($0, kAXTitleAttribute) }
            if title?.hasSuffix(titleSuffix) == true { return done(true) }
            if DispatchTime.now() >= deadline { return done(false) }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: poll)
        }
        poll()
    }

    /// Finds the profile's item in the browser's Profiles menu and presses it;
    /// returns the item's title. The menu is found by its contents rather than
    /// its (localized) title: the top-level menu whose items match the most of
    /// the browser's profiles.
    private static func pressProfileMenuItem(app: NSRunningApplication, bundleID: String, profileDirectory: String) -> String? {
        guard AXIsProcessTrusted(),
              let profiles = ChromiumProfiles.profiles(for: bundleID),
              let profile = profiles.first(where: { $0.directory == profileDirectory })
        else { return nil }

        let root = AXUIElementCreateApplication(app.processIdentifier)
        AXUIElementSetMessagingTimeout(root, 1.0)
        guard let bar: AXUIElement = attribute(root, kAXMenuBarAttribute) else { return nil }

        var best: (items: [(AXUIElement, String)], score: Int) = ([], 0)
        for top in children(bar) {
            let items = children(top).flatMap(children).compactMap { item -> (AXUIElement, String)? in
                guard let title: String = attribute(item, kAXTitleAttribute), !title.isEmpty else { return nil }
                return (item, title)
            }
            let score = items.filter { _, title in profiles.contains { $0.matchesMenuTitle(title) } }.count
            if score > best.score { best = (items, score) }
        }
        // Exact titles first; the "(name)" suffix only as a fallback.
        let match = best.items.first { profile.menuTitles.contains($0.1) }
            ?? best.items.first { profile.matchesMenuTitle($0.1) }
        guard let (item, title) = match else { return nil }
        let err = AXUIElementPerformAction(item, kAXPressAction as CFString)
        Log.info("switch: pressed profile menu item '\(title)' err=\(err.rawValue)")
        return err == .success ? title : nil
    }

    private static func attribute<T>(_ element: AXUIElement, _ name: String) -> T? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, name as CFString, &value) == .success else { return nil }
        return value as? T
    }

    private static func children(_ element: AXUIElement) -> [AXUIElement] {
        attribute(element, kAXChildrenAttribute) ?? []
    }
}
