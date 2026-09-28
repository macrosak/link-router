import SwiftUI
import LinkRouterCore

struct SettingsGeneralView: View {
    @ObservedObject var store: ConfigStore
    let shortcutActions: ShortcutActions
    let theme: SettingsTheme

    @State private var isDefault = DefaultBrowser.isDefault
    @State private var currentDefault = DefaultBrowser.currentName
    @State private var axGranted = SourceContext.accessibilityGranted
    @State private var launchAtLogin = LaunchAtLogin.isEnabled
    @State private var launchError: String?
    @State private var shortcutError: String?

    /// Permission / default-browser state can change behind our back (System
    /// Settings, the macOS confirmation dialog) — poll while visible.
    private let poll = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 17) {
            VStack(spacing: 0) {
                SectionLabel(text: "Default browser", theme: theme)
                SettingsCard(theme: theme) {
                    SettingsRow(
                        label: isDefault ? "Link Router is your default browser" : "Link Router is not the default browser",
                        desc: isDefault ? "Links you click anywhere are routed by your rules, or you pick." : "Current default: \(currentDefault ?? "unknown"). Links won't reach Link Router until it's the default.",
                        last: true, theme: theme
                    ) {
                        if isDefault {
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0x30D158))
                        } else {
                            SettingsButton(title: "Make default", kind: .primary, theme: theme) {
                                DefaultBrowser.claim { isDefault = $0 }
                            }
                        }
                    }
                }
            }

            VStack(spacing: 0) {
                SectionLabel(text: "Shortcut", theme: theme)
                SettingsCard(theme: theme) {
                    SettingsRow(
                        label: "Switch to a browser",
                        desc: shortcutError ?? "Opens the picker without a link: pick a browser or profile to bring its window to the front. Click to record a new shortcut.",
                        last: true, theme: theme
                    ) {
                        ShortcutRecorder(shortcut: store.config.switchShortcut, actions: shortcutActions,
                                         error: $shortcutError, theme: theme)
                    }
                }
            }

            VStack(spacing: 0) {
                SectionLabel(text: "Permissions", theme: theme)
                SettingsCard(theme: theme) {
                    SettingsRow(
                        label: "Accessibility",
                        desc: "Needed for rules on the source window title (e.g. one IntelliJ project per browser) and to switch to a Chrome profile's window. After granting, quit and relaunch Link Router.",
                        last: true, theme: theme
                    ) {
                        if axGranted {
                            Text("Granted").font(.system(size: 12.5)).foregroundStyle(theme.textDim)
                            Image(systemName: "checkmark.circle.fill").foregroundStyle(Color(hex: 0x30D158))
                        } else {
                            SettingsButton(title: "Grant…", theme: theme) { SourceContext.requestAccessibility() }
                        }
                    }
                }
            }

            VStack(spacing: 0) {
                SectionLabel(text: "App", theme: theme)
                SettingsCard(theme: theme) {
                    SettingsRow(label: "Launch at login", desc: launchError, theme: theme) {
                        Toggle("", isOn: Binding(get: { launchAtLogin }, set: { on in
                            do { try LaunchAtLogin.set(on); launchError = nil } catch { launchError = error.localizedDescription }
                            launchAtLogin = LaunchAtLogin.isEnabled
                        }))
                        .toggleStyle(.switch).controlSize(.small).labelsHidden()
                    }
                    SettingsRow(label: "Show menu bar icon", desc: "When hidden, open Link Router from Finder / Spotlight to get back here.", theme: theme) {
                        Toggle("", isOn: $store.config.showMenuBarIcon)
                            .toggleStyle(.switch).controlSize(.small).labelsHidden()
                    }
                    SettingsRow(label: "Offer to become the default browser on launch", last: true, theme: theme) {
                        Toggle("", isOn: Binding(
                            get: { !store.config.skipDefaultBrowserPrompt },
                            set: { store.config.skipDefaultBrowserPrompt = !$0 }
                        ))
                        .toggleStyle(.switch).controlSize(.small).labelsHidden()
                    }
                }
            }

            VStack(spacing: 0) {
                SectionLabel(text: "Picker keys", theme: theme)
                SettingsCard(theme: theme) {
                    keyRow(["type"], "Filter browsers")
                    keyRow(["↑", "↓"], "Move selection")
                    keyRow(["↵"], "Open in the selected browser")
                    keyRow(["⌘", "1–9"], "Open in the Nth browser")
                    keyRow(["⇥"], "Actions: record a rule, always use this browser, copy link, settings")
                    keyRow(["esc"], "Clear filter, leave actions, then close")
                    keyRow(["⌥", "click link"], "Hold ⌥ while clicking a link to skip rules and show the picker", last: true)
                }
            }
        }
        .onReceive(poll) { _ in
            isDefault = DefaultBrowser.isDefault
            currentDefault = DefaultBrowser.currentName
            axGranted = SourceContext.accessibilityGranted
        }
    }

    private func keyRow(_ keys: [String], _ label: String, last: Bool = false) -> some View {
        SettingsRow(label: label, last: last, theme: theme) {
            ShortcutChips(keys: keys, theme: theme)
        }
    }
}
