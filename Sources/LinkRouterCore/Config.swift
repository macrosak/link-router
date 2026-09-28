import Foundation

/// Everything the user configures, stored as one JSON file.
public struct Config: Codable, Equatable, Sendable {
    public var browsers: [BrowserTarget]
    public var rules: [Rule]
    public var showMenuBarIcon: Bool
    /// Don't offer to become the default browser on launch.
    public var skipDefaultBrowserPrompt: Bool

    public init(browsers: [BrowserTarget] = [], rules: [Rule] = [], showMenuBarIcon: Bool = true, skipDefaultBrowserPrompt: Bool = false) {
        self.browsers = browsers
        self.rules = rules
        self.showMenuBarIcon = showMenuBarIcon
        self.skipDefaultBrowserPrompt = skipDefaultBrowserPrompt
    }

    // Tolerant decoding: fields added later default instead of failing the load.
    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        browsers = try c.decodeIfPresent([BrowserTarget].self, forKey: .browsers) ?? []
        rules = try c.decodeIfPresent([Rule].self, forKey: .rules) ?? []
        showMenuBarIcon = try c.decodeIfPresent(Bool.self, forKey: .showMenuBarIcon) ?? true
        skipDefaultBrowserPrompt = try c.decodeIfPresent(Bool.self, forKey: .skipDefaultBrowserPrompt) ?? false
    }

    public var enabledBrowsers: [BrowserTarget] { browsers.filter(\.enabled) }

    public static func load(from url: URL) -> Config? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(Config.self, from: data)
    }

    public func save(to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let enc = JSONEncoder()
        enc.outputFormatting = [.prettyPrinted, .sortedKeys]
        try enc.encode(self).write(to: url, options: .atomic)
    }

    public static var defaultURL: URL {
        if let override = ProcessInfo.processInfo.environment["LINKROUTER_CONFIG"] {
            return URL(fileURLWithPath: override)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Link Router/config.json")
    }
}
