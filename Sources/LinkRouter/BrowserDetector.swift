import AppKit
import LinkRouterCore

enum BrowserDetector {
    /// Apps registered for https, excluding Link Router itself. De-duplicated
    /// by bundle id (LaunchServices can list several copies of one app — keep
    /// the one in /Applications).
    static func installedBrowsers() -> [InstalledBrowser] {
        guard let probe = URL(string: "https://example.com") else { return [] }
        let own = Bundle.main.bundleIdentifier
        var seen = [String: InstalledBrowser]()
        for appURL in NSWorkspace.shared.urlsForApplications(toOpen: probe) {
            guard let bundle = Bundle(url: appURL), let id = bundle.bundleIdentifier, id != own else { continue }
            let name = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
                ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
                ?? appURL.deletingPathExtension().lastPathComponent
            let candidate = InstalledBrowser(bundleID: id, appPath: appURL.path, name: name)
            if let existing = seen[id], existing.appPath.hasPrefix("/Applications/") { continue }
            seen[id] = candidate
        }
        return seen.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
