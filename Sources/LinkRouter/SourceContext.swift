import AppKit
import ApplicationServices
import LinkRouterCore

/// Works out which app (and window) a link came from.
@MainActor
enum SourceContext {
    /// The last app other than us to be active. LaunchServices activates the
    /// browser (us) before delivering the link, so by the time the event
    /// arrives `frontmostApplication` is already Link Router.
    private static var lastExternalApp: NSRunningApplication?
    private static var observer: NSObjectProtocol?

    static func startTracking() {
        let own = Bundle.main.bundleIdentifier
        let front = NSWorkspace.shared.frontmostApplication
        if front?.bundleIdentifier != own { lastExternalApp = front }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier != own else { return }
            MainActor.assumeIsolated { lastExternalApp = app }
        }
    }

    /// Resolution order:
    /// 1. the Apple event's sender, or the nearest regular app among its
    ///    parent processes — links opened via the `open` CLI (IDEs, terminals,
    ///    scripts) are sent by `open`, whose parent is the real app;
    /// 2. the last app that was active before us.
    static func capture(url: URL, senderPID: pid_t?) -> LinkContext {
        let app = senderPID.flatMap(regularAncestor) ?? lastExternalApp
        return LinkContext(
            url: url,
            sourceBundleID: app?.bundleIdentifier,
            sourceAppName: app?.localizedName,
            windowTitle: app.flatMap { focusedWindowTitle(pid: $0.processIdentifier) }
        )
    }

    private static func regularAncestor(of pid: pid_t) -> NSRunningApplication? {
        var current = pid
        for _ in 0..<12 where current > 1 {
            if let app = NSRunningApplication(processIdentifier: current),
               app.activationPolicy == .regular,
               app.bundleIdentifier != Bundle.main.bundleIdentifier {
                return app
            }
            guard let parent = parentPID(of: current), parent != current else { return nil }
            current = parent
        }
        return nil
    }

    private static func parentPID(of pid: pid_t) -> pid_t? {
        var info = kinfo_proc()
        var size = MemoryLayout<kinfo_proc>.stride
        var mib: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_PID, pid]
        guard sysctl(&mib, 4, &info, &size, nil, 0) == 0, size > 0 else { return nil }
        return info.kp_eproc.e_ppid
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
