import Foundation
import LinkRouterCore

/// State of one picker session: the pending link(s), the type-to-filter query
/// and the highlighted row.
@MainActor
final class PickerViewModel: ObservableObject {
    let urls: [URL]
    let context: LinkContext
    private let targets: [BrowserTarget]

    @Published var query = "" {
        didSet {
            filtered = FuzzyMatcher.filter(targets, query: query)
            selectedIndex = 0
        }
    }
    @Published private(set) var filtered: [BrowserTarget]
    @Published var selectedIndex = 0
    @Published var commandHeld = false

    /// (target, remember) — remember = also save a rule for this source.
    var onChoose: (BrowserTarget, Bool) -> Void = { _, _ in }
    var onCancel: () -> Void = {}
    var onCreateRule: () -> Void = {}

    init(urls: [URL], context: LinkContext, targets: [BrowserTarget]) {
        self.urls = urls
        self.context = context
        self.targets = targets
        self.filtered = targets
    }

    var selected: BrowserTarget? { filtered.indices.contains(selectedIndex) ? filtered[selectedIndex] : nil }

    func moveUp() { if !filtered.isEmpty { selectedIndex = (selectedIndex - 1 + filtered.count) % filtered.count } }
    func moveDown() { if !filtered.isEmpty { selectedIndex = (selectedIndex + 1) % filtered.count } }

    func confirm(remember: Bool = false) {
        guard let t = selected else { return }
        onChoose(t, remember)
    }

    func choose(at index: Int, remember: Bool = false) {
        guard filtered.indices.contains(index) else { return }
        selectedIndex = index
        onChoose(filtered[index], remember)
    }

    func cancel() {
        // First esc clears a query; the second closes.
        if !query.isEmpty { query = ""; return }
        onCancel()
    }

    /// "IntelliJ IDEA · link-router – Rule.swift"
    var sourceDescription: String? {
        let parts = [context.sourceAppName, context.windowTitle].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}
