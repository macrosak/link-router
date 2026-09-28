import Foundation

/// An installed app that can open http(s) URLs.
public struct InstalledBrowser: Equatable, Sendable {
    public let bundleID: String
    public let appPath: String
    public let name: String

    public init(bundleID: String, appPath: String, name: String) {
        self.bundleID = bundleID
        self.appPath = appPath
        self.name = name
    }
}

public enum BrowserCatalog {
    /// Apps that register as web browsers but aren't useful targets: other
    /// link pickers (routing to them would bounce the link again) and
    /// terminals that claim http(s).
    public static let excludedBundleIDs: Set<String> = [
        "com.mattsenter.Burly",
        "com.sindresorhus.Velja",
        "com.choosyosx.Choosy",
        "net.kassett.finicky",
        "com.will-stone.browserosaurus",
        "com.loshadki.OpenIn",
        "com.loshadki.OpenIn4",
        "com.monokai.bumpr",
        "com.googlecode.iterm2",
    ]

    public static func isCandidate(bundleID: String) -> Bool {
        !excludedBundleIDs.contains(bundleID)
    }

    /// Expands installed browsers into picker targets: one per profile for a
    /// Chromium browser with readable profiles, one plain entry otherwise.
    public static func targets(
        for browsers: [InstalledBrowser],
        profiles: (String) -> [ChromiumProfile]? = { ChromiumProfiles.profiles(for: $0) }
    ) -> [BrowserTarget] {
        browsers.flatMap { b -> [BrowserTarget] in
            if let list = profiles(b.bundleID), !list.isEmpty {
                return list.map {
                    BrowserTarget(bundleID: b.bundleID, appPath: b.appPath, appName: b.name,
                                  profileDirectory: $0.directory, profileName: $0.name, profileEmail: $0.email)
                }
            }
            return [BrowserTarget(bundleID: b.bundleID, appPath: b.appPath, appName: b.name)]
        }
    }

    /// Merges a fresh detection into the saved list: saved entries keep their
    /// position and enabled flag (metadata is refreshed), new entries are
    /// appended enabled, entries no longer installed are dropped.
    public static func merge(saved: [BrowserTarget], detected: [BrowserTarget]) -> [BrowserTarget] {
        let fresh = Dictionary(detected.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        var result: [BrowserTarget] = saved.compactMap { old in
            guard var updated = fresh[old.id] else { return nil }
            updated.enabled = old.enabled
            return updated
        }
        let known = Set(result.map(\.id))
        result += detected.filter { !known.contains($0.id) }
        return result
    }
}
