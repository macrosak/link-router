import Foundation
import Testing
@testable import LinkRouterCore

@Suite("FuzzyMatcher")
struct FuzzyMatcherTests {
    let targets = [
        BrowserTarget(bundleID: "c", appPath: "/", appName: "Google Chrome", profileDirectory: "Default", profileName: "Michal", profileEmail: "me@gmail.com"),
        BrowserTarget(bundleID: "c", appPath: "/", appName: "Google Chrome", profileDirectory: "Profile 2", profileName: "Work", profileEmail: "me@tado.com"),
        BrowserTarget(bundleID: "s", appPath: "/", appName: "Safari"),
        BrowserTarget(bundleID: "f", appPath: "/", appName: "Firefox"),
    ]

    @Test func emptyQueryKeepsOrder() {
        #expect(FuzzyMatcher.filter(targets, query: " ").map(\.title) == ["Michal", "Work", "Safari", "Firefox"])
    }

    @Test func prefixBeatsSubstring() {
        #expect(FuzzyMatcher.filter(targets, query: "sa").map(\.title) == ["Safari"])
        #expect(FuzzyMatcher.filter(targets, query: "f").first?.title == "Firefox")
    }

    @Test func searchesEmailAndAppName() {
        #expect(FuzzyMatcher.filter(targets, query: "tado").map(\.title) == ["Work"])
        #expect(FuzzyMatcher.filter(targets, query: "chrome").map(\.title) == ["Michal", "Work"])
    }

    @Test func subsequence() {
        #expect(FuzzyMatcher.score("Firefox", query: "ffx") != nil)
        #expect(FuzzyMatcher.score("Safari", query: "xyz") == nil)
    }
}
