import AppKit
import LinkRouterCore

/// Opens URLs in a target browser as fast as possible.
///
/// - Chromium profile, browser running: write the command line straight into
///   the browser's `SingletonSocket` (sub-millisecond), then activate it.
/// - Chromium profile, browser not running: launch it with
///   `--profile-directory=…` + the URLs.
/// - Anything else: `NSWorkspace.open(_:withApplicationAt:)`.
enum Launcher {
    static func open(_ urls: [URL], in target: BrowserTarget) {
        let start = DispatchTime.now()
        let appURL = URL(fileURLWithPath: target.appPath)

        // A profile directory that no longer exists (profile deleted since
        // detection) would make Chromium silently create a new, empty profile —
        // open in the browser's last-used profile instead.
        var profileDirectory = target.profileDirectory
        if let p = profileDirectory, let dir = ChromiumProfiles.userDataDir(for: target.bundleID),
           !FileManager.default.fileExists(atPath: dir.appendingPathComponent(p).path) {
            Log.error("profile \(p) of \(target.bundleID) is gone — opening without a profile")
            profileDirectory = nil
        }

        guard let profile = profileDirectory,
              let dataDir = ChromiumProfiles.userDataDir(for: target.bundleID)
        else {
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.open(urls, withApplicationAt: appURL, configuration: cfg) { _, error in
                if let error { Log.error("open in \(target.id) failed: \(error)") }
                Log.info("opened via LaunchServices in \(target.id) (\(Log.ms(since: start)))")
            }
            return
        }

        let args = ["--profile-directory=\(profile)"] + urls.map(\.absoluteString)
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: target.bundleID).first

        if running != nil, let socket = ChromiumSingleton.socketPath(userDataDir: dataDir) {
            let executable = Bundle(url: appURL)?.executablePath ?? appURL.path
            switch ChromiumSingleton.send(socketPath: socket, argv: [executable] + args, timeout: 1.5) {
            case .success:
                activate(target.bundleID)
                Log.info("opened via singleton socket in \(target.id) (\(Log.ms(since: start)))")
                return
            case .failure(let f):
                Log.error("singleton socket failed for \(target.id): \(f) — falling back to launch")
            }
        }

        let cfg = NSWorkspace.OpenConfiguration()
        cfg.activates = true
        cfg.arguments = args
        // A running browser ignores arguments on a plain open; a second
        // instance forwards them through the singleton itself (slow path).
        cfg.createsNewApplicationInstance = running != nil
        NSWorkspace.shared.openApplication(at: appURL, configuration: cfg) { _, error in
            if let error { Log.error("launch \(target.id) failed: \(error)") }
            Log.info("opened via launch in \(target.id) (\(Log.ms(since: start)))")
        }
    }

    /// Brings the browser forward. Chromium raises the right window itself but
    /// can't take activation from us under macOS 14+ cooperative activation,
    /// so we hand it over explicitly.
    private static func activate(_ bundleID: String) {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { return }
        let ok: Bool
        if #available(macOS 14.0, *) {
            NSApp.yieldActivation(to: app)
            ok = app.activate()
        } else {
            ok = app.activate(options: [])
        }
        if !ok, let url = app.bundleURL {
            // Activation refused: LaunchServices can always bring an app
            // forward (same as `open -a`).
            let cfg = NSWorkspace.OpenConfiguration()
            cfg.activates = true
            NSWorkspace.shared.openApplication(at: url, configuration: cfg)
        }
        Log.info("activate \(bundleID) ok=\(ok)")
    }
}
