import AppKit
import SwiftUI
import LinkRouterCore

/// Ordered routing rules + recent links (to build rules from real clicks).
struct SettingsRulesView: View {
    @ObservedObject var store: ConfigStore
    let theme: SettingsTheme

    @State private var editing: Rule?

    var body: some View {
        VStack(spacing: 17) {
            VStack(spacing: 0) {
                HStack(alignment: .bottom) {
                    SectionLabel(text: "Rules — first match opens directly", theme: theme)
                    SettingsButton(title: "Add rule", kind: .primary, theme: theme) {
                        editing = Rule(targetID: store.config.enabledBrowsers.first?.id ?? "")
                    }
                    .padding(.bottom, 6)
                }
                SettingsCard(theme: theme) {
                    if store.config.rules.isEmpty {
                        SettingsRow(label: "No rules yet", desc: "Every link shows the picker. Add a rule, press ⌥↵ in the picker, or create one from a recent link below.", last: true, theme: theme) { EmptyView() }
                    }
                    ForEach(Array(store.config.rules.enumerated()), id: \.element.id) { idx, rule in
                        ruleRow(rule, idx: idx, last: idx == store.config.rules.count - 1)
                    }
                }
                Text("All conditions set on a rule must match. URL “starts with” ignores http(s):// and www. when you leave the scheme out, and * is a wildcard. Hold ⌥ while clicking a link to bypass rules.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.textDim)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 10)
                    .padding(.horizontal, 4)
            }

            VStack(spacing: 0) {
                SectionLabel(text: "Recent links", theme: theme)
                SettingsCard(theme: theme) {
                    if store.recentLinks.isEmpty {
                        SettingsRow(label: "No links routed since launch", last: true, theme: theme) { EmptyView() }
                    }
                    ForEach(Array(store.recentLinks.enumerated()), id: \.element.id) { idx, link in
                        recentRow(link, last: idx == store.recentLinks.count - 1)
                    }
                }
            }
        }
        .sheet(item: $editing) { rule in
            RuleEditor(rule: rule, store: store, theme: theme) { saved in
                if let saved {
                    if let i = store.config.rules.firstIndex(where: { $0.id == saved.id }) {
                        store.config.rules[i] = saved
                    } else {
                        store.config.rules.append(saved)
                    }
                }
                editing = nil
            }
        }
    }

    private func target(_ id: String) -> BrowserTarget? { store.config.browsers.first { $0.id == id } }

    private func ruleRow(_ rule: Rule, idx: Int, last: Bool) -> some View {
        HStack(spacing: 12) {
            Toggle("", isOn: Binding(
                get: { rule.enabled },
                set: { on in if let i = store.config.rules.firstIndex(where: { $0.id == rule.id }) { store.config.rules[i].enabled = on } }
            ))
            .toggleStyle(.switch).controlSize(.mini).labelsHidden()
            VStack(alignment: .leading, spacing: 2) {
                Text(rule.summary)
                    .font(.system(size: 13))
                    .foregroundStyle(rule.enabled ? theme.text : theme.textFaint)
                    .lineLimit(2)
                HStack(spacing: 5) {
                    Image(systemName: "arrow.turn.down.right").font(.system(size: 10))
                    if let t = target(rule.targetID) {
                        TargetIconView(target: t, size: 14)
                        Text(t.subtitle.isEmpty ? t.title : "\(t.title) — \(t.appName)")
                        if !t.enabled { Text("(disabled)").foregroundStyle(theme.bad) }
                    } else {
                        Text("Missing browser").foregroundStyle(theme.bad)
                    }
                }
                .font(.system(size: 11.5))
                .foregroundStyle(theme.textDim)
            }
            Spacer()
            iconButton("chevron.up", enabled: idx > 0) { store.config.rules.swapAt(idx, idx - 1) }
            iconButton("chevron.down", enabled: !last) { store.config.rules.swapAt(idx, idx + 1) }
            iconButton("pencil", enabled: true) { editing = rule }
            iconButton("trash", enabled: true) { store.config.rules.removeAll { $0.id == rule.id } }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(theme.rowSep).frame(height: 0.5) } }
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { editing = rule }
    }

    private func recentRow(_ link: RecentLink, last: Bool) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(link.context.url.absoluteString)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(theme.text)
                    .lineLimit(1).truncationMode(.middle)
                Text([link.context.sourceAppName, link.context.windowTitle.map { "“\($0)”" },
                      link.targetTitle.map { "→ \($0)" + (link.viaRule ? " (rule)" : "") } ?? "→ cancelled"]
                    .compactMap { $0 }.joined(separator: " · "))
                    .font(.system(size: 11.5))
                    .foregroundStyle(theme.textDim)
                    .lineLimit(1)
            }
            Spacer()
            SettingsButton(title: "Create rule…", theme: theme) {
                let targetID = store.config.browsers.first { $0.title == link.targetTitle }?.id
                    ?? store.config.enabledBrowsers.first?.id ?? ""
                editing = Rule.suggested(from: link.context, targetID: targetID)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
        .overlay(alignment: .bottom) { if !last { Rectangle().fill(theme.rowSep).frame(height: 0.5) } }
    }

    private func iconButton(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 11.5, weight: .medium)).frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .foregroundStyle(enabled ? theme.textDim : theme.textFaint.opacity(0.4))
        .disabled(!enabled)
    }
}

/// Sheet for creating / editing one rule.
struct RuleEditor: View {
    @State var rule: Rule
    @ObservedObject var store: ConfigStore
    let theme: SettingsTheme
    let done: (Rule?) -> Void

    private var apps: [(id: String, name: String)] {
        var seen = Set<String>()
        var out: [(String, String)] = []
        let recent = store.recentLinks.compactMap { l in l.context.sourceBundleID.map { ($0, l.context.sourceAppName ?? $0) } }
        let running = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap { a in a.bundleIdentifier.map { ($0, a.localizedName ?? $0) } }
        for (id, name) in recent + running where seen.insert(id).inserted { out.append((id, name)) }
        return out.sorted { $0.1.localizedCaseInsensitiveCompare($1.1) == .orderedAscending }
    }

    private var titleSuggestions: [String] {
        Array(Set(store.recentLinks
            .filter { rule.sourceBundleID.isEmpty || $0.context.sourceBundleID == rule.sourceBundleID }
            .compactMap { $0.context.windowTitle }
            .map(Rule.stableTitlePart))).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(store.config.rules.contains { $0.id == rule.id } ? "Edit rule" : "New rule")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(theme.text)

            SettingsCard(theme: theme) {
                SettingsRow(label: "URL", desc: "Leave empty to match any link.", theme: theme) {
                    Picker("", selection: $rule.urlMatch) {
                        ForEach(Rule.URLMatch.allCases, id: \.self) { Text($0.label).tag($0) }
                    }
                    .labelsHidden().frame(width: 130)
                    SettingsField(text: $rule.urlPattern, placeholder: "github.com/my-org", mono: true, width: 220, theme: theme)
                }
                SettingsRow(label: "Source app", desc: rule.sourceBundleID.isEmpty ? "Any app" : rule.sourceBundleID, theme: theme) {
                    Menu(rule.sourceBundleID.isEmpty ? "Any app" : (rule.sourceAppName.isEmpty ? rule.sourceBundleID : rule.sourceAppName)) {
                        Button("Any app") { rule.sourceBundleID = ""; rule.sourceAppName = "" }
                        Divider()
                        ForEach(apps, id: \.id) { app in
                            Button(app.name) { rule.sourceBundleID = app.id; rule.sourceAppName = app.name }
                        }
                    }
                    .frame(width: 220)
                }
                SettingsRow(label: "Window title contains",
                            desc: SourceContext.accessibilityGranted ? "Case-insensitive. Leave empty for any window." : "Requires Accessibility (Settings → General).",
                            last: true, theme: theme) {
                    if !titleSuggestions.isEmpty {
                        Menu("Recent") {
                            ForEach(titleSuggestions, id: \.self) { t in Button(t) { rule.windowTitleContains = t } }
                        }
                        .fixedSize()
                    }
                    SettingsField(text: $rule.windowTitleContains, placeholder: "my-project", width: 220, theme: theme)
                }
            }

            SettingsCard(theme: theme) {
                SettingsRow(label: "Open in", last: true, theme: theme) {
                    Picker("", selection: $rule.targetID) {
                        ForEach(store.config.browsers) { t in
                            Text(t.subtitle.isEmpty ? t.title : "\(t.title) — \(t.appName)").tag(t.id)
                        }
                    }
                    .labelsHidden().frame(width: 280)
                }
            }

            if !rule.hasConditions {
                Text("Set at least one condition — a rule without any never matches.")
                    .font(.system(size: 11.5)).foregroundStyle(theme.bad)
            }

            HStack {
                Spacer()
                SettingsButton(title: "Cancel", theme: theme) { done(nil) }
                    .keyboardShortcut(.cancelAction)
                SettingsButton(title: "Save", kind: .primary, theme: theme) { done(rule) }
                    .keyboardShortcut(.defaultAction)
                    .disabled(!rule.hasConditions || rule.targetID.isEmpty)
                    .opacity(!rule.hasConditions || rule.targetID.isEmpty ? 0.5 : 1)
            }
        }
        .padding(22)
        .frame(width: 640)
        .background(theme.body)
    }
}
