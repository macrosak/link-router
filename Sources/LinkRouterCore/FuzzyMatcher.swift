import Foundation

/// Subsequence fuzzy matching with ranking (ported from Recallyx, trimmed to
/// short strings). A query matches when its characters appear in order,
/// case-insensitively. Best first: exact > prefix > word-prefix > substring >
/// subsequence. Returns nil when there's no match.
public enum FuzzyMatcher {
    public static func score(_ candidate: String, query: String) -> Int? {
        let q = query.lowercased()
        guard !q.isEmpty else { return 0 }
        let c = candidate.lowercased()

        if c == q { return 10_000 }
        if c.hasPrefix(q) { return 5_000 - candidate.count }
        if let range = c.range(of: q) {
            let offset = c.distance(from: c.startIndex, to: range.lowerBound)
            // A hit at a word boundary ("work" in "tado work") ranks above a
            // mid-word one.
            let before = c[c.index(before: range.lowerBound)]
            let boundary = !before.isLetter && !before.isNumber
            return (boundary ? 3_000 : 2_000) - offset
        }
        return subsequenceScore(c, q)
    }

    private static func subsequenceScore(_ c: String, _ q: String) -> Int? {
        var qi = q.startIndex
        var last: Int?
        var gaps = 0
        for (pos, ch) in c.enumerated() {
            guard qi < q.endIndex else { break }
            if ch == q[qi] {
                if let l = last { gaps += pos - l - 1 }
                last = pos
                qi = q.index(after: qi)
            }
        }
        guard qi == q.endIndex else { return nil }
        return 1_000 - gaps
    }

    /// Filters `targets` by `query` across their search fields; sorted by best
    /// score, ties keeping the configured order. Empty query → unchanged.
    public static func filter(_ targets: [BrowserTarget], query: String) -> [BrowserTarget] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return targets }
        return targets.enumerated()
            .compactMap { idx, t -> (Int, Int, BrowserTarget)? in
                let best = t.searchFields.compactMap { score($0, query: q) }.max()
                return best.map { ($0, idx, t) }
            }
            .sorted { $0.0 != $1.0 ? $0.0 > $1.0 : $0.1 < $1.1 }
            .map(\.2)
    }
}
