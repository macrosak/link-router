import Foundation
import Testing
@testable import LinkRouterCore

@Suite("Browser catalog & profiles")
struct CatalogTests {
    let localState = """
    {"profile":{"profiles_order":["Profile 2","Default"],"info_cache":{
      "Default":{"name":"Michal","user_name":"me@example.com"},
      "Profile 2":{"name":"Work","user_name":""},
      "Profile 9":{"name":"","user_name":""}}}}
    """.data(using: .utf8)!

    @Test func parsesProfilesInChromeOrder() throws {
        let p = try #require(ChromiumProfiles.parse(localState: localState))
        #expect(p.map(\.directory) == ["Profile 2", "Default", "Profile 9"])
        #expect(p[0] == ChromiumProfile(directory: "Profile 2", name: "Work", email: nil))
        #expect(p[1].email == "me@example.com")
        #expect(p[2].name == "Profile 9")  // empty name falls back to the dir
    }

    @Test func garbageLocalStateIsNil() {
        #expect(ChromiumProfiles.parse(localState: Data("nope".utf8)) == nil)
    }

    @Test func expandsChromiumIntoProfiles() {
        let apps = [
            InstalledBrowser(bundleID: "com.google.Chrome", appPath: "/Chrome.app", name: "Google Chrome"),
            InstalledBrowser(bundleID: "com.apple.Safari", appPath: "/Safari.app", name: "Safari"),
        ]
        let targets = BrowserCatalog.targets(for: apps) { id in
            id == "com.google.Chrome" ? ChromiumProfiles.parse(localState: localState) : nil
        }
        #expect(targets.map(\.id) == [
            "com.google.Chrome#Profile 2", "com.google.Chrome#Default", "com.google.Chrome#Profile 9", "com.apple.Safari",
        ])
        #expect(targets[1].subtitle == "Google Chrome · me@example.com")
        #expect(targets[3].title == "Safari")
    }

    @Test func mergeKeepsOrderAndFlagsAppendsNewDropsGone() {
        var s1 = BrowserTarget(bundleID: "safari", appPath: "/S.app", appName: "Safari")
        s1.enabled = false
        let c1 = BrowserTarget(bundleID: "chrome", appPath: "/C.app", appName: "Chrome")
        let gone = BrowserTarget(bundleID: "old", appPath: "/O.app", appName: "Old")
        let saved = [s1, gone, c1]
        let detected = [
            BrowserTarget(bundleID: "chrome", appPath: "/new/C.app", appName: "Chrome"),
            BrowserTarget(bundleID: "firefox", appPath: "/F.app", appName: "Firefox"),
            BrowserTarget(bundleID: "safari", appPath: "/S.app", appName: "Safari"),
        ]
        let merged = BrowserCatalog.merge(saved: saved, detected: detected)
        #expect(merged.map(\.id) == ["safari", "chrome", "firefox"])
        #expect(merged[0].enabled == false)
        #expect(merged[1].appPath == "/new/C.app")
        #expect(merged[2].enabled)
    }
}
