import SwiftUI
import LinkRouterCore

enum SettingsTab: String, Hashable, CaseIterable {
    case general, browsers, rules

    var title: String {
        switch self {
        case .general: return "General"
        case .browsers: return "Browsers"
        case .rules: return "Rules"
        }
    }
}

/// Root of the Settings window: a custom header (segmented tabs + brand) over
/// a transparent title bar, then the tab body — Recallyx's settings chrome.
struct SettingsView: View {
    @ObservedObject var store: ConfigStore
    let shortcutActions: ShortcutActions
    @State private var tab: SettingsTab

    @Environment(\.colorScheme) private var colorScheme
    private var theme: SettingsTheme { SettingsTheme.current(colorScheme) }

    init(store: ConfigStore, shortcutActions: ShortcutActions, initialTab: SettingsTab = .general) {
        self.store = store
        self.shortcutActions = shortcutActions
        self._tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                Group {
                    switch tab {
                    case .general: SettingsGeneralView(store: store, shortcutActions: shortcutActions, theme: theme)
                    case .browsers: SettingsBrowsersView(store: store, theme: theme)
                    case .rules: SettingsRulesView(store: store, theme: theme)
                    }
                }
                .padding(.horizontal, 22)
                .padding(.vertical, 20)
            }
        }
        .background(theme.body)
        .frame(minWidth: 620, minHeight: 540)
        .ignoresSafeArea(.container, edges: .top)
        .onReceive(NotificationCenter.default.publisher(for: .selectSettingsTab)) { note in
            if let t = note.object as? SettingsTab { tab = t }
        }
    }

    private var header: some View {
        ZStack {
            theme.chrome
            SegmentedTabs(tabs: SettingsTab.allCases, selection: $tab, theme: theme)
            HStack {
                Spacer()
                HStack(spacing: 7) {
                    BrandMark(size: 16, color: theme.accent)
                    Text("Link Router")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.textDim)
                }
            }
            .padding(.horizontal, 16)
        }
        .frame(height: 48)
        .overlay(alignment: .bottom) { Rectangle().fill(theme.cardBorder).frame(height: 0.5) }
    }
}

/// Pill segmented control in the title bar.
struct SegmentedTabs: View {
    let tabs: [SettingsTab]
    @Binding var selection: SettingsTab
    let theme: SettingsTheme

    var body: some View {
        HStack(spacing: 4) {
            ForEach(tabs, id: \.self) { tab in
                let on = tab == selection
                Text(tab.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(on ? theme.text : theme.textDim)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 5)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(on ? (theme.isDark ? Color(hex: 0x47474B) : .white) : .clear)
                            .shadow(color: on && !theme.isDark ? .black.opacity(0.12) : .clear, radius: 1, y: 0.5)
                    )
                    .contentShape(Rectangle())
                    .onTapGesture { selection = tab }
            }
        }
        .padding(3)
        .background(RoundedRectangle(cornerRadius: 9).fill(theme.isDark ? Color(hex: 0x37373A) : theme.segBg))
    }
}

/// Brand mark: one line splitting into three — a link fanning out to browsers.
struct BrandMark: View {
    var size: CGFloat = 18
    var color: Color = Color(hex: 0x0A84FF)

    var body: some View {
        Canvas { ctx, rect in
            let s = rect.width / 24
            func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            var path = Path()
            path.move(to: p(3, 12)); path.addLine(to: p(10, 12))
            for y: CGFloat in [5, 12, 19] {
                path.move(to: p(10, 12))
                path.addCurve(to: p(19, y), control1: p(14, 12), control2: p(14, y))
            }
            ctx.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 2 * s, lineCap: .round))
            for y: CGFloat in [5, 12, 19] {
                ctx.fill(Path(ellipseIn: CGRect(x: 18 * s, y: (y - 2.2) * s, width: 4.4 * s, height: 4.4 * s)), with: .color(color))
            }
            ctx.fill(Path(ellipseIn: CGRect(x: 1 * s, y: 9.8 * s, width: 4.4 * s, height: 4.4 * s)), with: .color(color.opacity(0.5)))
        }
        .frame(width: size, height: size)
    }
}
