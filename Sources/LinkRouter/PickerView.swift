import SwiftUI
import LinkRouterCore

/// The picker: search field, the link being opened, the browser list, and a
/// hint bar footer — Recallyx's panel layout, single column.
struct PickerView: View {
    @ObservedObject var viewModel: PickerViewModel
    let listHeight: CGFloat

    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var searchFocused: Bool
    private var theme: RXTheme { RXTheme.current(colorScheme) }

    static let rowHeight: CGFloat = 48
    static let chromeHeight: CGFloat = 54 + 36 + 38 + 12

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            linkBar
            if viewModel.filtered.isEmpty {
                noMatches.frame(height: listHeight)
            } else {
                list.frame(height: listHeight)
            }
            HintBar(items: hints, theme: theme, left: viewModel.sourceDescription.map { "from \($0)" })
        }
        .frame(width: PickerController.width)
        .background(theme.panelTint)
        .onAppear { searchFocused = true }
    }

    private var hints: [HintItem] {
        guard !viewModel.filtered.isEmpty else { return [HintItem(keys: ["esc"], label: "Close")] }
        return [
            HintItem(keys: ["↵"], label: "Open"),
            HintItem(keys: ["⌥", "↵"], label: "Always"),
            HintItem(keys: ["esc"], label: "Close"),
        ]
    }

    private var searchBar: some View {
        HStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(theme.textDim)
            TextField("Open in…", text: $viewModel.query)
                .textFieldStyle(.plain)
                .font(.system(size: 19))
                .foregroundStyle(theme.text)
                .focused($searchFocused)
            if viewModel.urls.count > 1 {
                Text("\(viewModel.urls.count) links")
                    .font(.system(size: 12))
                    .foregroundStyle(theme.textFaint)
            }
        }
        .padding(.horizontal, 18)
        .frame(height: 54)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.hairline).frame(height: 0.5) }
    }

    /// The link, host emphasized, middle-truncated.
    private var linkBar: some View {
        let url = viewModel.urls.first
        let host = url?.host ?? ""
        let full = url?.absoluteString ?? ""
        return HStack(spacing: 8) {
            Image(systemName: "link")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.textFaint)
            Text(host)
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(theme.text)
                .fixedSize()
            Text(full)
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(theme.textDim)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .frame(height: 36)
        .background(theme.rail)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.hairline).frame(height: 0.5) }
        .help(full)
    }

    private var list: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 1) {
                    ForEach(Array(viewModel.filtered.enumerated()), id: \.element.id) { idx, t in
                        TargetRow(
                            target: t,
                            active: idx == viewModel.selectedIndex,
                            quickKey: viewModel.commandHeld && idx < 9 ? idx + 1 : nil,
                            theme: theme
                        )
                        .id(t.id)
                        .contentShape(Rectangle())
                        .onTapGesture { viewModel.choose(at: idx, remember: NSEvent.modifierFlags.contains(.option)) }
                        .onHover { if $0 { viewModel.selectedIndex = idx } }
                    }
                }
                .padding(.vertical, 6)
            }
            .onChange(of: viewModel.selectedIndex) { _ in
                if let id = viewModel.selected?.id { proxy.scrollTo(id) }
            }
        }
    }

    private var noMatches: some View {
        VStack(spacing: 8) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(theme.textFaint)
            Text("No browsers match “\(viewModel.query)”")
                .font(.system(size: 13.5))
                .foregroundStyle(theme.textDim)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}

struct TargetRow: View {
    let target: BrowserTarget
    let active: Bool
    var quickKey: Int?
    let theme: RXTheme

    var body: some View {
        HStack(spacing: 12) {
            TargetIconView(target: target, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(target.title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(active ? .white : theme.text)
                if !target.subtitle.isEmpty {
                    Text(target.subtitle)
                        .font(.system(size: 11.5))
                        .foregroundStyle(active ? .white.opacity(0.7) : theme.textFaint)
                }
            }
            .lineLimit(1)
            Spacer(minLength: 8)
            if let quickKey {
                Keycap(label: "⌘\(quickKey)", theme: theme)
            } else if active {
                Text("↵")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
            }
        }
        .padding(.horizontal, 12)
        .frame(height: PickerView.rowHeight)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(active ? theme.sel : .clear)
                .shadow(color: active ? Color(rgba: 10, 90, 200, 0.35) : .clear, radius: 3, y: 1)
        )
        .padding(.horizontal, 8)
    }
}
