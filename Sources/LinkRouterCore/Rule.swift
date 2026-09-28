import Foundation

/// Where a link came from, captured when the open-URL event arrives.
public struct LinkContext: Equatable, Sendable {
    public var url: URL
    public var sourceBundleID: String?
    public var sourceAppName: String?
    /// Title of the source app's focused window (needs Accessibility).
    public var windowTitle: String?

    public init(url: URL, sourceBundleID: String? = nil, sourceAppName: String? = nil, windowTitle: String? = nil) {
        self.url = url
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.windowTitle = windowTitle
    }
}

/// A routing rule. Every condition that is set must match; empty conditions
/// match anything. The first enabled matching rule wins and opens its target
/// directly, skipping the picker.
public struct Rule: Codable, Identifiable, Hashable, Sendable {
    public enum URLMatch: String, Codable, CaseIterable, Sendable {
        /// Starts with the pattern; `*` is a wildcard. A pattern without a
        /// scheme also matches after `https://` / `http://` / `www.`.
        case prefix
        case contains
        case regex

        public var label: String {
            switch self {
            case .prefix: return "starts with"
            case .contains: return "contains"
            case .regex: return "matches regex"
            }
        }
    }

    public var id: UUID
    public var enabled: Bool
    public var urlPattern: String
    public var urlMatch: URLMatch
    /// Source app bundle id; empty = any app.
    public var sourceBundleID: String
    /// Display name for `sourceBundleID` (for the rules list).
    public var sourceAppName: String
    /// Case-insensitive substring of the source window title; empty = any.
    public var windowTitleContains: String
    /// `BrowserTarget.id` to open in.
    public var targetID: String

    public init(
        id: UUID = UUID(),
        enabled: Bool = true,
        urlPattern: String = "",
        urlMatch: URLMatch = .prefix,
        sourceBundleID: String = "",
        sourceAppName: String = "",
        windowTitleContains: String = "",
        targetID: String
    ) {
        self.id = id
        self.enabled = enabled
        self.urlPattern = urlPattern
        self.urlMatch = urlMatch
        self.sourceBundleID = sourceBundleID
        self.sourceAppName = sourceAppName
        self.windowTitleContains = windowTitleContains
        self.targetID = targetID
    }

    /// A rule with no conditions would swallow every link — never match it.
    public var hasConditions: Bool {
        !urlPattern.trimmed.isEmpty || !sourceBundleID.trimmed.isEmpty || !windowTitleContains.trimmed.isEmpty
    }

    public func matches(_ ctx: LinkContext) -> Bool {
        guard enabled, hasConditions else { return false }
        let app = sourceBundleID.trimmed
        if !app.isEmpty, app.caseInsensitiveCompare(ctx.sourceBundleID ?? "") != .orderedSame { return false }
        let title = windowTitleContains.trimmed
        if !title.isEmpty {
            guard let wt = ctx.windowTitle, wt.range(of: title, options: .caseInsensitive) != nil else { return false }
        }
        let pattern = urlPattern.trimmed
        if !pattern.isEmpty, !Self.url(ctx.url.absoluteString, matches: pattern, kind: urlMatch) { return false }
        return true
    }

    static func url(_ url: String, matches pattern: String, kind: URLMatch) -> Bool {
        switch kind {
        case .contains:
            return url.range(of: pattern, options: .caseInsensitive) != nil
        case .regex:
            guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return false }
            return re.firstMatch(in: url, range: NSRange(url.startIndex..., in: url)) != nil
        case .prefix:
            let candidates = pattern.contains("://") ? [url] : strippedVariants(url)
            return candidates.contains { globPrefix($0, pattern) }
        }
    }

    /// The URL without its scheme, and additionally without a leading `www.`.
    private static func strippedVariants(_ url: String) -> [String] {
        var s = url
        if let r = s.range(of: "://") { s = String(s[r.upperBound...]) }
        var out = [s]
        if s.lowercased().hasPrefix("www.") { out.append(String(s.dropFirst(4))) }
        return out
    }

    /// Case-insensitive "starts with", where `*` in the pattern matches any run.
    private static func globPrefix(_ s: String, _ pattern: String) -> Bool {
        guard pattern.contains("*") else {
            return s.lowercased().hasPrefix(pattern.lowercased())
        }
        let body = pattern.split(separator: "*", omittingEmptySubsequences: false)
            .map { NSRegularExpression.escapedPattern(for: String($0)) }
            .joined(separator: ".*")
        guard let re = try? NSRegularExpression(pattern: "^" + body, options: [.caseInsensitive]) else { return false }
        return re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }
}

public enum RuleMatcher {
    /// First enabled rule that matches and points at an enabled, known target.
    public static func match(_ rules: [Rule], context: LinkContext, targets: [BrowserTarget]) -> (Rule, BrowserTarget)? {
        let byID = Dictionary(targets.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for rule in rules where rule.matches(context) {
            if let t = byID[rule.targetID], t.enabled { return (rule, t) }
        }
        return nil
    }
}

extension String {
    var trimmed: String { trimmingCharacters(in: .whitespacesAndNewlines) }
}

extension Rule {
    /// The rule ⌥↵ ("always use this") saves: scoped to the source app and,
    /// when known, the stable part of its window title (the project name in
    /// IDE titles like "link-router – Rule.swift"). Without a source app it
    /// falls back to the link's host.
    public static func suggested(from ctx: LinkContext, targetID: String) -> Rule {
        guard let app = ctx.sourceBundleID, !app.isEmpty else {
            return Rule(urlPattern: ctx.url.host ?? ctx.url.absoluteString, targetID: targetID)
        }
        return Rule(
            sourceBundleID: app,
            sourceAppName: ctx.sourceAppName ?? app,
            windowTitleContains: ctx.windowTitle.map(stableTitlePart) ?? "",
            targetID: targetID
        )
    }

    /// First segment of a window title split on the usual separators
    /// (" – ", " — ", " - ", " | ").
    public static func stableTitlePart(_ title: String) -> String {
        var head = title
        for sep in [" – ", " — ", " - ", " | "] {
            if let r = head.range(of: sep) { head = String(head[..<r.lowerBound]) }
        }
        let t = head.trimmed
        return t.isEmpty ? title.trimmed : t
    }

    /// One-line human summary of the conditions.
    public var summary: String {
        var parts: [String] = []
        if !urlPattern.trimmed.isEmpty { parts.append("URL \(urlMatch.label) “\(urlPattern.trimmed)”") }
        if !sourceBundleID.trimmed.isEmpty { parts.append("from \(sourceAppName.trimmed.isEmpty ? sourceBundleID : sourceAppName)") }
        if !windowTitleContains.trimmed.isEmpty { parts.append("window “\(windowTitleContains.trimmed)”") }
        return parts.isEmpty ? "No conditions (never matches)" : parts.joined(separator: " · ")
    }
}

extension Rule {
    /// The picker's "Create rule…" draft: every condition this link offers
    /// (host prefix, source app, window project) pre-filled — the user clears
    /// what they don't want.
    public static func captured(from ctx: LinkContext, targetID: String) -> Rule {
        var host = ctx.url.host ?? ""
        if host.lowercased().hasPrefix("www.") { host = String(host.dropFirst(4)) }
        return Rule(
            urlPattern: host,
            sourceBundleID: ctx.sourceBundleID ?? "",
            sourceAppName: ctx.sourceAppName ?? "",
            windowTitleContains: ctx.windowTitle.map(stableTitlePart) ?? "",
            targetID: targetID
        )
    }
}
