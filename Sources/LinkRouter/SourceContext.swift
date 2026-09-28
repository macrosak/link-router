import AppKit
import ApplicationServices
import LinkRouterCore

/// Works out which app (and window) a link came from.
enum SourceContext {
    /// `senderPID` is the Apple event's sender. Links opened through a helper
    /// (the `open` CLI, LaunchServices agents) have a background sender, so we
    /// fall back to the frontmost app — the one the user clicked in.
    static func capture(url: URL, senderPID: pid_t?) -> LinkContext {
        var app: NSRunningApplication?
        if let pid = senderPID, pid > 0,
           let sender = NSRunningApplication(processIdentifier: pid),
           sender.activationPolicy == .regular,
           sender.bundleIdentifier != Bundle.main.bundleIdentifier {
            app = sender
        }
        if app == nil {
            let front = NSWorkspace.shared.frontmostApplication
            if front?.bundleIdentifier != Bundle.main.bundleIdentifier { app = front }
        }
        return LinkContext(
            url: url,
            sourceBundleID: app?.bundleIdentifier,
            sourceAppName: app?.localizedName,
            windowTitle: app.flatMap { focusedWindowTitle(pid: $0.processIdentifier) }
        )
    }

    /// Title of the app's focused (else main) window via Accessibility; nil
    /// without the permission.
    static func focusedWindowTitle(pid: pid_t) -> String? {
        guard AXIsProcessTrusted() else { return nil }
        let app = AXUIElementCreateApplication(pid)
        AXUIElementSetMessagingTimeout(app, 0.25)
        for attr in [kAXFocusedWindowAttribute, kAXMainWindowAttribute] {
            var window: CFTypeRef?
            guard AXUIElementCopyAttributeValue(app, attr as CFString, &window) == .success, let window else { continue }
            var title: CFTypeRef?
            // swiftlint:disable:next force_cast
            if AXUIElementCopyAttributeValue(window as! AXUIElement, kAXTitleAttribute as CFString, &title) == .success,
               let s = title as? String, !s.isEmpty {
                return s
            }
        }
        return nil
    }

    static var accessibilityGranted: Bool { AXIsProcessTrusted() }

    /// Shows the system prompt that deep-links to the Accessibility pane.
    static func requestAccessibility() {
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
    }
}
