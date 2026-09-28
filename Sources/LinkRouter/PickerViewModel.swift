import Foundation
import LinkRouterCore

/// Something the picker's action menu (⇥) can do with the pending link.
enum PickerAction: String, CaseIterable, Identifiable {
    case recordRule
    case alwaysUse
    case copyLink
    case openSettings

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .recordRule: return "record.circle"
        case .alwaysUse: return "pin"
        case .copyLink: return "doc.on.doc"
        case .openSettings: return "gearshape"
        }
    }
}

/// One row of the action menu, with its labels resolved for this link.
struct PickerActionItem: Identifiable, Equatable {
    let action: PickerAction
    let title: String
    let subtitle: String
    var id: String { action.id }
}

/// State of one picker session: the pending link(s), the type-to-filter query,
/// the highlighted row, and which list is showing — browsers, or the ⇥ action
/// menu for the browser highlighted when ⇥ was pressed.
@MainActor
final class PickerViewModel: ObservableObject {
    enum Mode { case browsers, actions }

    let urls: [URL]
    let context: LinkContext
    private let targets: [BrowserTarget]

    @Published private(set) var mode: Mode = .browsers
    @Published var query = "" {
        didSet { refilter() }
    }
    @Published private(set) var filtered: [BrowserTarget]
    @Published private(set) var filteredActions: [PickerActionItem] = []
    @Published var selectedIndex = 0
    @Published var commandHeld = false

    /// The browser the action menu acts on ("always use …").
    private(set) var actionTarget: BrowserTarget?
    /// The browser list's filter + selection, restored when leaving actions.
    private var savedBrowserState: (query: String, index: Int)?

    /// (target, remember) — remember = also save a rule for this source.
    var onChoose: (BrowserTarget, Bool) -> Void = { _, _ in }
    var onCancel: () -> Void = {}
    /// (action, the browser highlighted when the menu opened)
    var onAction: (PickerAction, BrowserTarget?) -> Void = { _, _ in }

    init(urls: [URL], context: LinkContext, targets: [BrowserTarget]) {
        self.urls = urls
        self.context = context
        self.targets = targets
        self.filtered = targets
    }

    var selected: BrowserTarget? {
        mode == .browsers && filtered.indices.contains(selectedIndex) ? filtered[selectedIndex] : nil
    }

    private var rowCount: Int { mode == .browsers ? filtered.count : filteredActions.count }

    func moveUp() { if rowCount > 0 { selectedIndex = (selectedIndex - 1 + rowCount) % rowCount } }
    func moveDown() { if rowCount > 0 { selectedIndex = (selectedIndex + 1) % rowCount } }

    /// ↵: open in the selected browser, or run the selected action.
    func confirm() {
        switch mode {
        case .browsers:
            if let t = selected { onChoose(t, false) }
        case .actions:
            runAction(at: selectedIndex)
        }
    }

    /// Click / ⌘N in the browser list.
    func choose(at index: Int) {
        guard mode == .browsers, filtered.indices.contains(index) else { return }
        selectedIndex = index
        onChoose(filtered[index], false)
    }

    func runAction(at index: Int) {
        guard mode == .actions, filteredActions.indices.contains(index) else { return }
        onAction(filteredActions[index].action, actionTarget)
    }

    /// ⇥ toggles between the browser list and the action menu.
    func toggleActions() {
        mode == .browsers ? showActions() : showBrowsers()
    }

    func showActions() {
        guard mode == .browsers else { return }
        actionTarget = selected ?? filtered.first ?? targets.first
        savedBrowserState = (query, selectedIndex)
        mode = .actions
        query = ""
        selectedIndex = 0
    }

    func showBrowsers() {
        guard mode == .actions else { return }
        mode = .browsers
        let saved = savedBrowserState
        query = saved?.query ?? ""
        selectedIndex = min(saved?.index ?? 0, max(filtered.count - 1, 0))
    }

    /// esc: clear the filter, then leave the action menu, then close.
    func cancel() {
        if !query.isEmpty { query = ""; return }
        if mode == .actions { showBrowsers(); return }
        onCancel()
    }

    var actionItems: [PickerActionItem] {
        let source = sourceShortDescription
        var items = [
            PickerActionItem(action: .recordRule, title: "Record new rule…",
                             subtitle: "Pre-filled from this link — keep the conditions you want"),
        ]
        if let t = actionTarget {
            items.append(PickerActionItem(action: .alwaysUse, title: "Always open in \(t.title)",
                                          subtitle: source.map { "Saves a rule for links from \($0)" } ?? "Saves a rule for \(context.url.host ?? "this site")"))
        }
        items += [
            PickerActionItem(action: .copyLink, title: "Copy link to clipboard",
                             subtitle: urls.count > 1 ? "\(urls.count) links, one per line" : "Doesn't open it"),
            PickerActionItem(action: .openSettings, title: "Open Settings…",
                             subtitle: "Browsers, rules, permissions"),
        ]
        return items
    }

    private func refilter() {
        switch mode {
        case .browsers:
            filtered = FuzzyMatcher.filter(targets, query: query)
        case .actions:
            let q = query.trimmingCharacters(in: .whitespaces)
            filteredActions = q.isEmpty ? actionItems : actionItems
                .compactMap { item in FuzzyMatcher.score(item.title, query: q).map { (item, $0) } }
                .sorted { $0.1 > $1.1 }
                .map(\.0)
        }
        selectedIndex = 0
    }

    /// "IntelliJ IDEA · link-router – Rule.swift"
    var sourceDescription: String? {
        let parts = [context.sourceAppName, context.windowTitle].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// "IntelliJ IDEA · link-router" — the part an "always" rule keys on.
    private var sourceShortDescription: String? {
        guard let app = context.sourceAppName, !app.isEmpty else { return nil }
        guard let title = context.windowTitle, !title.isEmpty else { return app }
        return "\(app) · \(Rule.stableTitlePart(title))"
    }
}
