import SwiftUI
import LinkRouterCore

/// Detect, reorder and enable/disable the picker's browsers and profiles.
struct SettingsBrowsersView: View {
    @ObservedObject var store: ConfigStore
    let theme: SettingsTheme

    @State private var dragging: String?
    /// Row being renamed, and its draft name.
    @State private var renaming: String?
    @State private var draftName = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .bottom) {
                SectionLabel(text: "Browsers & profiles — picker order", theme: theme)
                SettingsButton(title: "Detect browsers", theme: theme) { store.refreshBrowsers() }
                    .padding(.bottom, 6)
            }
            if store.config.browsers.isEmpty {
                SettingsCard(theme: theme) {
                    SettingsRow(label: "No browsers yet", desc: "Click Detect browsers.", last: true, theme: theme) { EmptyView() }
                }
            } else {
                SettingsCard(theme: theme) {
                    ForEach(Array(store.config.browsers.enumerated()), id: \.element.id) { idx, t in
                        row(t, idx: idx, last: idx == store.config.browsers.count - 1)
                            .onDrag {
                                dragging = t.id
                                return NSItemProvider(object: t.id as NSString)
                            }
                            .onDrop(of: [.text], delegate: ReorderDrop(targetID: t.id, dragging: $dragging, store: store))
                    }
                }
            }
            Text("Drag rows (or use the arrows) to reorder. Double-click a name (or the pencil) to rename it; clear the name to go back to the detected one. Disabled entries are hidden from the picker; rules pointing at them fall back to the picker. Chromium-family browsers (Chrome, Brave, Edge, Vivaldi…) are listed per profile.")
                .font(.system(size: 11.5))
                .foregroundStyle(theme.textDim)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 10)
                .padding(.horizontal, 4)
        }
    }

    private func row(_ t: BrowserTarget, idx: Int, last: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(theme.textFaint)
            TargetIconView(target: t, size: 24)
                .opacity(t.enabled ? 1 : 0.4)
            VStack(alignment: .leading, spacing: 1) {
                if renaming == t.id {
                    SettingsField(text: $draftName, placeholder: t.detectedName, width: 240, theme: theme,
                                  onEditingEnded: { commitRename(t.id) }, autoFocus: true)
                    .onExitCommand { renaming = nil }
                } else {
                    Text(t.title).font(.system(size: 13.5)).foregroundStyle(t.enabled ? theme.text : theme.textFaint)
                        .onTapGesture(count: 2) { startRename(t) }
                }
                let sub = [t.customName != nil && t.title != t.detectedName ? t.detectedName : nil, t.subtitle.isEmpty ? nil : t.subtitle]
                    .compactMap { $0 }.joined(separator: " · ")
                if !sub.isEmpty {
                    Text(sub).font(.system(size: 11.5)).foregroundStyle(theme.textDim)
                }
            }
            Spacer()
            arrow("pencil", enabled: true) { renaming == t.id ? commitRename(t.id) : startRename(t) }
            arrow("chevron.up", enabled: idx > 0) { move(idx, by: -1) }
            arrow("chevron.down", enabled: !last) { move(idx, by: 1) }
            Toggle("", isOn: Binding(
                get: { t.enabled },
                set: { on in if let i = store.config.browsers.firstIndex(where: { $0.id == t.id }) { store.config.browsers[i].enabled = on } }
            ))
            .toggleStyle(.switch).controlSize(.small).labelsHidden()
        }
        .padding(.horizontal, 14)
        .frame(height: 50)
        .background(dragging == t.id ? theme.segBg : .clear)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(theme.rowSep).frame(height: 0.5) } }
        .contentShape(Rectangle())
    }

    private func arrow(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11, weight: .semibold)).frame(width: 20, height: 20)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? theme.textDim : theme.textFaint.opacity(0.4))
        .disabled(!enabled)
    }

    private func startRename(_ t: BrowserTarget) {
        draftName = t.title
        renaming = t.id
    }

    /// Empty (or unchanged-from-detected) clears the custom name.
    private func commitRename(_ id: String) {
        guard renaming == id, let i = store.config.browsers.firstIndex(where: { $0.id == id }) else { return }
        let name = draftName.trimmingCharacters(in: .whitespaces)
        store.config.browsers[i].customName = name.isEmpty || name == store.config.browsers[i].detectedName ? nil : name
        renaming = nil
    }

    private func move(_ idx: Int, by delta: Int) {
        let to = idx + delta
        guard store.config.browsers.indices.contains(to) else { return }
        store.config.browsers.swapAt(idx, to)
    }
}

/// Live reorder while dragging a row over another.
private struct ReorderDrop: DropDelegate {
    let targetID: String
    @Binding var dragging: String?
    let store: ConfigStore

    func dropEntered(info: DropInfo) {
        guard let dragging, dragging != targetID else { return }
        Task { @MainActor in
            var list = store.config.browsers
            guard let from = list.firstIndex(where: { $0.id == dragging }),
                  let to = list.firstIndex(where: { $0.id == targetID }) else { return }
            withAnimation(.easeOut(duration: 0.12)) {
                list.move(fromOffsets: IndexSet(integer: from), toOffset: to > from ? to + 1 : to)
                store.config.browsers = list
            }
        }
    }

    func dropUpdated(info: DropInfo) -> DropProposal? { DropProposal(operation: .move) }

    func performDrop(info: DropInfo) -> Bool {
        dragging = nil
        return true
    }
}
