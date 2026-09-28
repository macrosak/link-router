import AppKit
import SwiftUI

/// Owns the Settings window. LSUIElement apps have no Dock-driven Preferences
/// path, so it's opened from the menu-bar item, from relaunching the app in
/// Finder, and on first launch.
@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    private let store: ConfigStore
    private let shortcutActions: ShortcutActions
    private var window: NSWindow?

    init(store: ConfigStore, shortcutActions: ShortcutActions) {
        self.store = store
        self.shortcutActions = shortcutActions
        super.init()
    }

    func show(tab: SettingsTab = .general) {
        if let window {
            NotificationCenter.default.post(name: .selectSettingsTab, object: tab)
            NSApp.activate(ignoringOtherApps: true)
            window.makeKeyAndOrderFront(nil)
            return
        }
        let hosting = NSHostingController(rootView: SettingsView(store: store, shortcutActions: shortcutActions, initialTab: tab))
        let window = NSWindow(contentViewController: hosting)
        window.title = "Link Router Settings"
        window.styleMask = [.titled, .closable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.setContentSize(NSSize(width: 720, height: 640))
        window.center()
        window.delegate = self
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}

extension Notification.Name {
    static let selectSettingsTab = Notification.Name("LinkRouter.selectSettingsTab")
}
