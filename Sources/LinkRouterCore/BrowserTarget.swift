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

    public init(
        bundleID: String,
        appPath: String,
        appName: String,
        profileDirectory: String? = nil,
        profileName: String? = nil,
        profileEmail: String? = nil,
        enabled: Bool = true
    ) {
        self.id = Self.makeID(bundleID: bundleID, profileDirectory: profileDirectory)
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
        guard profileDirectory != nil else { return "" }
        if let profileEmail, !profileEmail.isEmpty { return "\(appName) · \(profileEmail)" }
        return appName
    }

    /// Everything the picker's type-to-filter searches.
    public var searchFields: [String] {
        [title, detectedName, appName, profileEmail ?? ""].filter { !$0.isEmpty }
    }
}
