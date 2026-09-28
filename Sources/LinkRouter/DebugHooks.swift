import AppKit
import LinkRouterCore

/// Lets scripts drive a `LINKROUTER_DEBUG=1` instance for manual UI testing
/// (see scripts/debug.sh). Commands arrive as distributed notifications
/// named `io.github.macrosak.linkrouter.debug` with the command in `object`:
///   query:<text>   set the picker's filter
///   key:<name>     up | down | return | esc | tab | cmd-<1-3>
///   state          write the picker state as JSON to $TMPDIR/linkrouter-debug.json
///   settings:<tab> open Settings on general | browsers | rules
///   demo-link:<url> show the picker for <url> with a synthetic IntelliJ source
///   snapshot:<path> render the picker (or Settings) window to a PNG — works
///                  without Screen Recording permission
@MainActor
final class DebugHooks {
    private weak var app: AppDelegate?
    private var observer: NSObjectProtocol?

    init(app: AppDelegate) {
        self.app = app
        observer = DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("io.github.macrosak.linkrouter.debug"), object: nil, queue: .main
        ) { [weak self] note in
            guard let cmd = note.object as? String else { return }
            Task { @MainActor in self?.handle(cmd) }
        }
        Log.info("debug hooks active")
    }

    private func handle(_ cmd: String) {
        guard let app else { return }
        let (name, arg) = cmd.split(separator: ":", maxSplits: 1).map(String.init).splitPair
        switch name {
        case "query": app.picker.viewModel?.query = arg
        case "key": key(arg)
        case "state": writeState()
        case "settings": app.settings.show(tab: SettingsTab(rawValue: arg) ?? .general)
        case "snapshot": snapshot(to: arg)
        case "demo-link":
            guard let url = URL(string: arg) else { return }
            let ctx = LinkContext(url: url, sourceBundleID: "com.jetbrains.intellij", sourceAppName: "IntelliJ IDEA",
                                  windowTitle: "link-router – Launcher.swift")
            app.picker.show(urls: [url], context: ctx, targets: app.store.config.enabledBrowsers) { _, _, _ in }
        default: Log.error("debug: unknown command \(cmd)")
        }
    }

    private func key(_ name: String) {
        let codes: [String: (UInt16, NSEvent.ModifierFlags)] = [
            "up": (0x7E, []), "down": (0x7D, []), "return": (0x24, []),
            "esc": (0x35, []), "tab": (0x30, []),
            "cmd-1": (0x12, .command), "cmd-2": (0x13, .command), "cmd-3": (0x14, .command),
        ]
        let chars = ""
        guard let (code, flags) = codes[name],
              let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: flags, timestamp: 0,
                                           windowNumber: 0, context: nil, characters: chars, charactersIgnoringModifiers: chars,
                                           isARepeat: false, keyCode: code)
        else { Log.error("debug: unknown key \(name)"); return }
        _ = app?.picker.handleKeyDown(event)
    }

    private func snapshot(to path: String) {
        let window = NSApp.windows.first { $0 is PickerPanel && $0.isVisible }
            ?? NSApp.windows.first { $0.isSheet && $0.isVisible }
            ?? NSApp.windows.first { $0.isVisible && $0.title == "Link Router Settings" }
        guard let view = window?.contentView,
              let rep = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { return }
        view.cacheDisplay(in: view.bounds, to: rep)
        try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: path))
    }

    private func writeState() {
        guard let app else { return }
        var state: [String: Any] = ["pickerVisible": app.picker.isVisible,
                                    "pickerIsKey": NSApp.isActive && NSApp.keyWindow is PickerPanel, "rules": app.store.config.rules.map(\.summary),
                                    "targets": app.store.config.browsers.map(\.id),
                                    "windows": NSApp.windows.map { "\(type(of: $0)) '\($0.title)' sheet=\($0.isSheet) visible=\($0.isVisible)" }]
        if let vm = app.picker.viewModel {
            state["query"] = vm.query
            state["filtered"] = vm.filtered.map(\.id)
            state["selectedIndex"] = vm.selectedIndex
            state["mode"] = vm.mode == .browsers ? "browsers" : "actions"
            state["actions"] = vm.filteredActions.map(\.title)
            state["urls"] = vm.urls.map(\.absoluteString)
            state["source"] = [vm.context.sourceBundleID ?? "", vm.context.windowTitle ?? ""]
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("linkrouter-debug.json")
        if let data = try? JSONSerialization.data(withJSONObject: state, options: [.prettyPrinted, .sortedKeys]) {
            try? data.write(to: url)
        }
    }
}

private extension Array where Element == String {
    var splitPair: (String, String) { (first ?? "", count > 1 ? self[1] : "") }
}
