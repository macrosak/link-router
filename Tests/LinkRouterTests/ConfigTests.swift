import Foundation
import Testing
@testable import LinkRouterCore

@Suite("Config")
struct ConfigTests {
    @Test func roundTrips() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("lr-\(UUID()).json")
        defer { try? FileManager.default.removeItem(at: url) }
        let cfg = Config(
            browsers: [BrowserTarget(bundleID: "a", appPath: "/A.app", appName: "A", profileDirectory: "P", profileName: "N")],
            rules: [Rule(urlPattern: "x.com", targetID: "a#P")],
            showMenuBarIcon: false
        )
        try cfg.save(to: url)
        #expect(Config.load(from: url) == cfg)
    }

    @Test func missingFieldsDefault() throws {
        let cfg = try JSONDecoder().decode(Config.self, from: Data("{}".utf8))
        #expect(cfg.browsers.isEmpty && cfg.rules.isEmpty && cfg.showMenuBarIcon && !cfg.skipDefaultBrowserPrompt)
        #expect(cfg.switchShortcut == .switchBrowserDefault)
    }

    @Test func switchShortcutRoundTrips() throws {
        var cfg = Config()
        cfg.switchShortcut = Shortcut(keyCode: 11, carbonModifiers: 0, keyLabel: "b", enabled: false)
        let data = try JSONEncoder().encode(cfg)
        #expect(try JSONDecoder().decode(Config.self, from: data).switchShortcut == cfg.switchShortcut)
    }
}
