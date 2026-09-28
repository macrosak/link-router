import Foundation

/// One entry in the picker: an installed browser, or one profile of a
/// Chromium-family browser. Persisted in the config so the user's order and
/// enabled flags survive re-detection.
public struct BrowserTarget: Codable, Identifiable, Hashable, Sendable {
    /// Stable identity: the bundle id, plus `#<profile dir>` for a profile
    /// (e.g. `com.google.Chrome#Profile 1`).
    public var id: String
    public var bundleID: String
    /// Path of the `.app` bundle.
    public var appPath: String
    /// The app's display name ("Google Chrome").
    public var appName: String
    /// Chromium profile directory name ("Default", "Profile 1"); nil for a
    /// plain browser entry.
    public var profileDirectory: String?
    /// The profile's display name ("Work").
    public var profileName: String?
    /// The signed-in account of the profile, if any.
    public var profileEmail: String?
    public var enabled: Bool
    /// User-chosen label shown instead of the detected name; nil = detected.
    public var customName: String?
    /// A Chromium incognito window (`--incognito`) rather than a profile.
    public var incognito: Bool = false

    public init(
        bundleID: String,
        appPath: String,
        appName: String,
        profileDirectory: String? = nil,
        profileName: String? = nil,
        profileEmail: String? = nil,
        enabled: Bool = true,
        incognito: Bool = false
    ) {
        self.id = incognito ? Self.incognitoID(bundleID: bundleID) : Self.makeID(bundleID: bundleID, profileDirectory: profileDirectory)
        self.incognito = incognito
        self.bundleID = bundleID
        self.appPath = appPath
        self.appName = appName
        self.profileDirectory = profileDirectory
        self.profileName = profileName
        self.profileEmail = profileEmail
        self.enabled = enabled
    }

    public static func makeID(bundleID: String, profileDirectory: String?) -> String {
        guard let profileDirectory else { return bundleID }
        return "\(bundleID)#\(profileDirectory)"
    }

    public static func incognitoID(bundleID: String) -> String { "\(bundleID)#incognito" }

    /// Plain Chromium browser → its Incognito entry.
    public static func incognito(bundleID: String, appPath: String, appName: String) -> BrowserTarget {
        BrowserTarget(bundleID: bundleID, appPath: appPath, appName: appName, profileName: "Incognito", incognito: true)
    }

    /// Primary label: the custom name, else the profile name for a profile,
    /// else the app name.
    public var title: String {
        if let customName, !customName.trimmingCharacters(in: .whitespaces).isEmpty { return customName }
        return detectedName
    }

    /// The name detection found (profile name or app name).
    public var detectedName: String {
        if let profileName, !profileName.isEmpty { return profileName }
        return appName
    }

    /// Secondary label: "Google Chrome · me@example.com" for a profile, empty
    /// for a plain browser.
    public var subtitle: String {
        if incognito { return "\(appName) · private window" }
        guard profileDirectory != nil else { return "" }
        if let profileEmail, !profileEmail.isEmpty { return "\(appName) · \(profileEmail)" }
        return appName
    }

    /// Everything the picker's type-to-filter searches.
    public var searchFields: [String] {
        [title, detectedName, appName, profileEmail ?? ""].filter { !$0.isEmpty }
    }

    // Tolerant decoding: configs written before a field existed still load.
    private enum CodingKeys: String, CodingKey {
        case id, bundleID, appPath, appName, profileDirectory, profileName, profileEmail, enabled, customName, incognito
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        bundleID = try c.decode(String.self, forKey: .bundleID)
        appPath = try c.decode(String.self, forKey: .appPath)
        appName = try c.decode(String.self, forKey: .appName)
        profileDirectory = try c.decodeIfPresent(String.self, forKey: .profileDirectory)
        profileName = try c.decodeIfPresent(String.self, forKey: .profileName)
        profileEmail = try c.decodeIfPresent(String.self, forKey: .profileEmail)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        customName = try c.decodeIfPresent(String.self, forKey: .customName)
        incognito = try c.decodeIfPresent(Bool.self, forKey: .incognito) ?? false
    }
}
