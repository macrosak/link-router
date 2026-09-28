import Foundation
import LinkRouterCore

/// Observable owner of the persisted `Config`. Every mutation is written
/// straight to disk — the file is tiny and edits are rare.
@MainActor
final class ConfigStore: ObservableObject {
    @Published var config: Config {
        didSet { if config != oldValue { save() } }
    }
    /// The last few links routed, newest first — powers "create rule from a
    /// recent link" in Settings. In memory only.
    @Published private(set) var recentLinks: [RecentLink] = []

    /// A rule being recorded from the picker (⇥ → Record new rule…), shown in Settings → Rules.
    @Published var ruleDraft: RuleDraft?

    private let url: URL

    init(url: URL = Config.defaultURL) {
        self.url = url
        self.config = Config.load(from: url) ?? Config()
    }

    /// Re-runs browser detection and merges it into the saved list.
    func refreshBrowsers() {
        // Docs screenshots run on a hand-written demo config.
        guard ProcessInfo.processInfo.environment["LINKROUTER_NO_DETECT"] != "1" else { return }
        let detected = BrowserCatalog.targets(for: BrowserDetector.installedBrowsers())
        config.browsers = BrowserCatalog.merge(saved: config.browsers, detected: detected)
    }

    func recordLink(_ ctx: LinkContext, openedIn target: BrowserTarget?, viaRule: Bool) {
        recentLinks.insert(RecentLink(context: ctx, targetTitle: target?.title, viaRule: viaRule), at: 0)
        if recentLinks.count > 15 { recentLinks.removeLast(recentLinks.count - 15) }
    }

    private func save() {
        do { try config.save(to: url) } catch { Log.error("config save failed: \(error)") }
    }
}

struct RecentLink: Identifiable {
    let id = UUID()
    let context: LinkContext
    let targetTitle: String?
    let viaRule: Bool
    let date = Date()
}

/// "Create a rule for links like this": the pre-filled rule plus what to do
/// once the editor closes (saved rule, or nil when cancelled).
struct RuleDraft: Identifiable {
    let id = UUID()
    let rule: Rule
    let context: LinkContext
    let finish: (Rule?) -> Void
}
