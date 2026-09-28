import Foundation

/// A profile read from a Chromium browser's `Local State`.
public struct ChromiumProfile: Equatable, Sendable {
    public let directory: String
    public let name: String
    public let email: String?
    /// First name of the signed-in account (`gaia_given_name`).
    public var givenName: String? = nil
    /// The name is Chromium's placeholder ("Person 1", "Your Chrome"…).
    public var usesDefaultName: Bool = false

    public init(directory: String, name: String, email: String?, givenName: String? = nil, usesDefaultName: Bool = false) {
        self.directory = directory
        self.name = name
        self.email = email
        self.givenName = givenName
        self.usesDefaultName = usesDefaultName
    }

    /// How the browser labels this profile in its Profiles menu, most likely
    /// first. Chromium shows the account's first name next to a custom
    /// profile name ("Michal (Work)"), just the first name when the two are
    /// equal or the profile name is a placeholder, else the profile name.
    public var menuTitles: [String] {
        guard let given = givenName, !given.isEmpty, given != name else { return [name] }
        return usesDefaultName ? [given, name] : ["\(given) (\(name))", name]
    }

    /// Whether a Profiles-menu item title belongs to this profile.
    public func matchesMenuTitle(_ title: String) -> Bool {
        menuTitles.contains(title) || title.hasSuffix("(\(name))")
    }
}

/// Knows where each Chromium-family browser keeps its user-data directory and
/// how to read the profile list out of it.
public enum ChromiumProfiles {
    /// Bundle id → user-data directory, relative to `~/Library/Application Support`.
    public static let userDataDirs: [String: String] = [
        "com.google.Chrome": "Google/Chrome",
        "com.google.Chrome.beta": "Google/Chrome Beta",
        "com.google.Chrome.dev": "Google/Chrome Dev",
        "com.google.Chrome.canary": "Google/Chrome Canary",
        "org.chromium.Chromium": "Chromium",
        "com.brave.Browser": "BraveSoftware/Brave-Browser",
        "com.brave.Browser.beta": "BraveSoftware/Brave-Browser-Beta",
        "com.brave.Browser.nightly": "BraveSoftware/Brave-Browser-Nightly",
        "com.microsoft.edgemac": "Microsoft Edge",
        "com.microsoft.edgemac.Beta": "Microsoft Edge Beta",
        "com.microsoft.edgemac.Dev": "Microsoft Edge Dev",
        "com.vivaldi.Vivaldi": "Vivaldi",
    ]

    public static func isChromium(_ bundleID: String) -> Bool {
        userDataDirs[bundleID] != nil
    }

    public static func userDataDir(for bundleID: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> URL? {
        guard let rel = userDataDirs[bundleID] else { return nil }
        return home.appendingPathComponent("Library/Application Support").appendingPathComponent(rel)
    }

    /// Profiles of `bundleID` in the browser's own menu order, or nil if the
    /// browser isn't Chromium-family or has no readable `Local State`.
    public static func profiles(for bundleID: String, home: URL = FileManager.default.homeDirectoryForCurrentUser) -> [ChromiumProfile]? {
        guard let dir = userDataDir(for: bundleID, home: home),
              let data = try? Data(contentsOf: dir.appendingPathComponent("Local State"))
        else { return nil }
        return parse(localState: data)
    }

    /// Parses `profile.info_cache` (+ `profile.profiles_order` for ordering)
    /// from a `Local State` JSON blob.
    public static func parse(localState data: Data) -> [ChromiumProfile]? {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let profile = root["profile"] as? [String: Any],
              let cache = profile["info_cache"] as? [String: Any]
        else { return nil }

        var profiles: [ChromiumProfile] = cache.compactMap { dir, value in
            guard let info = value as? [String: Any] else { return nil }
            let name = (info["name"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? dir
            let email = (info["user_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            let given = (info["gaia_given_name"] as? String).flatMap { $0.isEmpty ? nil : $0 }
            return ChromiumProfile(directory: dir, name: name, email: email, givenName: given,
                                   usesDefaultName: info["is_using_default_name"] as? Bool ?? false)
        }

        let order = profile["profiles_order"] as? [String] ?? []
        let rank = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { a, _ in a })
        profiles.sort { a, b in
            switch (rank[a.directory], rank[b.directory]) {
            case let (x?, y?): return x < y
            case (_?, nil): return true
            case (nil, _?): return false
            case (nil, nil): return a.directory.localizedStandardCompare(b.directory) == .orderedAscending
            }
        }
        return profiles
    }

    /// Chrome's per-profile avatar, present for signed-in profiles.
    public static func pictureURL(bundleID: String, profileDirectory: String) -> URL? {
        guard let dir = userDataDir(for: bundleID) else { return nil }
        let url = dir.appendingPathComponent(profileDirectory).appendingPathComponent("Google Profile Picture.png")
        return FileManager.default.fileExists(atPath: url.path) ? url : nil
    }
}
