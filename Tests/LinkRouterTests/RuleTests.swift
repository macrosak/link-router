import Foundation
import Testing
@testable import LinkRouterCore

@Suite("Rule matching")
struct RuleTests {
    let gh = URL(string: "https://github.com/awattarenergy/repo/pull/1")!

    func ctx(_ url: URL, app: String? = nil, title: String? = nil) -> LinkContext {
        LinkContext(url: url, sourceBundleID: app, windowTitle: title)
    }

    @Test func prefixWithScheme() {
        let r = Rule(urlPattern: "https://github.com/awattarenergy", targetID: "x")
        #expect(r.matches(ctx(gh)))
        #expect(!r.matches(ctx(URL(string: "https://github.com/other")!)))
    }

    @Test func prefixWithoutSchemeIgnoresSchemeAndWWW() {
        let r = Rule(urlPattern: "github.com/awattar", targetID: "x")
        #expect(r.matches(ctx(gh)))
        #expect(r.matches(ctx(URL(string: "http://www.github.com/awattarenergy")!)))
    }

    @Test func prefixWildcard() {
        let r = Rule(urlPattern: "*.atlassian.net/browse", targetID: "x")
        #expect(r.matches(ctx(URL(string: "https://tado.atlassian.net/browse/X-1")!)))
        #expect(!r.matches(ctx(URL(string: "https://tado.atlassian.net/wiki")!)))
    }

    @Test func prefixIsCaseInsensitive() {
        let r = Rule(urlPattern: "GitHub.com", targetID: "x")
        #expect(r.matches(ctx(gh)))
    }

    @Test func containsAndRegex() {
        #expect(Rule(urlPattern: "pull/", urlMatch: .contains, targetID: "x").matches(ctx(gh)))
        #expect(Rule(urlPattern: #"github\.com/.+/pull/\d+$"#, urlMatch: .regex, targetID: "x").matches(ctx(gh)))
        #expect(!Rule(urlPattern: "(", urlMatch: .regex, targetID: "x").matches(ctx(gh)))
    }

    @Test func sourceAppAndWindowTitle() {
        let r = Rule(sourceBundleID: "com.jetbrains.intellij", windowTitleContains: "link-router", targetID: "x")
        #expect(r.matches(ctx(gh, app: "com.jetbrains.intellij", title: "link-router – Rule.swift")))
        #expect(!r.matches(ctx(gh, app: "com.jetbrains.intellij", title: "recallyx – main.swift")))
        #expect(!r.matches(ctx(gh, app: "com.apple.Terminal", title: "link-router")))
        #expect(!r.matches(ctx(gh, app: "com.jetbrains.intellij", title: nil)))
    }

    @Test func allConditionsMustMatch() {
        let r = Rule(urlPattern: "github.com", sourceBundleID: "com.jetbrains.intellij", targetID: "x")
        #expect(r.matches(ctx(gh, app: "com.jetbrains.intellij")))
        #expect(!r.matches(ctx(gh, app: "com.apple.Safari")))
    }

    @Test func emptyOrDisabledRuleNeverMatches() {
        #expect(!Rule(targetID: "x").matches(ctx(gh)))
        #expect(!Rule(enabled: false, urlPattern: "github.com", targetID: "x").matches(ctx(gh)))
    }

    @Test func matcherPicksFirstRuleWithEnabledTarget() {
        let a = BrowserTarget(bundleID: "a", appPath: "/A.app", appName: "A")
        var b = BrowserTarget(bundleID: "b", appPath: "/B.app", appName: "B")
        let c = BrowserTarget(bundleID: "c", appPath: "/C.app", appName: "C")
        b.enabled = false
        let rules = [
            Rule(urlPattern: "gitlab.com", targetID: "a"),
            Rule(urlPattern: "github.com", targetID: "b"),     // target disabled → skipped
            Rule(urlPattern: "github.com", targetID: "gone"),  // unknown target → skipped
            Rule(urlPattern: "github.com", targetID: "c"),
        ]
        let hit = RuleMatcher.match(rules, context: ctx(gh), targets: [a, b, c])
        #expect(hit?.1.id == "c")
        #expect(RuleMatcher.match(rules, context: ctx(URL(string: "https://x.org")!), targets: [a, b, c]) == nil)
    }
}

@Suite("Suggested rules")
struct SuggestedRuleTests {
    let url = URL(string: "https://github.com/a/b")!

    @Test func stableTitlePart() {
        #expect(Rule.stableTitlePart("link-router – Rule.swift") == "link-router")
        #expect(Rule.stableTitlePart("recallyx [~/p/recallyx] – main.swift") == "recallyx [~/p/recallyx]")
        #expect(Rule.stableTitlePart("Just a title") == "Just a title")
    }

    @Test func fromAppAndWindow() {
        let r = Rule.suggested(from: LinkContext(url: url, sourceBundleID: "com.jetbrains.intellij", sourceAppName: "IntelliJ IDEA", windowTitle: "link-router – Rule.swift"), targetID: "t")
        #expect(r.sourceBundleID == "com.jetbrains.intellij")
        #expect(r.windowTitleContains == "link-router")
        #expect(r.urlPattern.isEmpty)
        #expect(r.summary == "from IntelliJ IDEA · window “link-router”")
    }

    @Test func withoutSourceUsesHost() {
        let r = Rule.suggested(from: LinkContext(url: url), targetID: "t")
        #expect(r.urlPattern == "github.com")
        #expect(r.matches(LinkContext(url: url)))
    }
}
