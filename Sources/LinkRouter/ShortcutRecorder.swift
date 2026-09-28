import AppKit
import Carbon.HIToolbox
import SwiftUI
import LinkRouterCore

// MARK: - Recording (NSEvent → Shortcut)

extension Shortcut {
    /// Build a candidate from a recorder keyDown. Nil when the key yields no
    /// usable label (dead keys, unmapped function keys).
    static func from(event: NSEvent) -> Shortcut? {
        guard let label = keyLabel(for: event) else { return nil }
        return Shortcut(
            keyCode: UInt32(event.keyCode),
            carbonModifiers: carbonModifiers(from: event.modifierFlags),
            keyLabel: label
        )
    }

    /// Cocoa → Carbon modifier mask.
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mask: UInt32 = 0
        if flags.contains(.control) { mask |= UInt32(controlKey) }
        if flags.contains(.option) { mask |= UInt32(optionKey) }
        if flags.contains(.shift) { mask |= UInt32(shiftKey) }
        if flags.contains(.command) { mask |= UInt32(cmdKey) }
        return mask
    }

    /// Special keys first (arrows/F-keys come back from `characters` as
    /// private-use Unicode, space/return/tab as whitespace), then the unshifted
    /// base character via `characters(byApplyingModifiers: [])` — NOT
    /// `charactersIgnoringModifiers`, which keeps ⇧ applied and would capture
    /// "B"/"&" instead of "b"/"7".
    private static func keyLabel(for event: NSEvent) -> String? {
        if let special = specialKeyLabels[Int(event.keyCode)] { return special }
        guard
            let chars = event.characters(byApplyingModifiers: []),
            chars.count == 1,
            let scalar = chars.unicodeScalars.first,
            scalar.value >= 0x20, // printable; no control chars
            !(0xF700...0xF8FF).contains(scalar.value) // no NSEvent function-key range
        else { return nil }
        return chars.lowercased()
    }

    private static let specialKeyLabels: [Int: String] = [
        kVK_Space: "Space", kVK_Return: "Return", kVK_ANSI_KeypadEnter: "Return", kVK_Tab: "Tab",
        kVK_Delete: "⌫", kVK_ForwardDelete: "⌦",
        kVK_LeftArrow: "←", kVK_RightArrow: "→", kVK_UpArrow: "↑", kVK_DownArrow: "↓",
        kVK_Home: "↖", kVK_End: "↘", kVK_PageUp: "⇞", kVK_PageDown: "⇟",
        kVK_F1: "F1", kVK_F2: "F2", kVK_F3: "F3", kVK_F4: "F4", kVK_F5: "F5", kVK_F6: "F6",
        kVK_F7: "F7", kVK_F8: "F8", kVK_F9: "F9", kVK_F10: "F10", kVK_F11: "F11", kVK_F12: "F12",
    ]
}

/// The app delegate's hotkey seam, handed down to the Settings UI. `apply` is
/// the single mutation point (Carbon first, then the config); `suspend` /
/// `resume` bracket recording so the live hotkey can't swallow the keys being
/// captured.
@MainActor
struct ShortcutActions {
    let apply: (Shortcut) -> HotkeyManager.ApplyResult
    let suspend: () -> Void
    let resume: () -> Void
}

/// Click-to-record shortcut field (Recallyx's recorder). Idle shows the
/// current binding's keycaps (or "Disabled"); click → "Press keys…" and the
/// next valid combo is validated, then registered + saved live. ✕ disables;
/// esc cancels. Errors surface through the `error` binding (the row's
/// description slot).
struct ShortcutRecorder: View {
    let shortcut: Shortcut
    let actions: ShortcutActions
    @Binding var error: String?
    let theme: SettingsTheme

    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 6) {
            Button {
                recording ? cancel() : begin()
            } label: {
                if recording {
                    fieldText("Press keys…", color: theme.textDim, border: theme.accent)
                } else if shortcut.enabled {
                    ShortcutChips(keys: shortcut.glyphs, theme: theme)
                } else {
                    fieldText("Disabled", color: theme.textFaint, border: theme.btnBorder)
                }
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .help(recording ? "Press the new shortcut, or esc to cancel" : "Click to record a new shortcut")

            if shortcut.enabled && !recording {
                Button(action: disable) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(theme.textFaint)
                }
                .buttonStyle(.plain)
                .help("Disable this shortcut")
            }
        }
        .onDisappear { if recording { cancel() } }
        // The settings window losing key focus must end recording — otherwise
        // the local monitor (and the hotkey suspension) would dangle.
        .onReceive(NotificationCenter.default.publisher(for: NSWindow.didResignKeyNotification)) { _ in
            if recording { cancel() }
        }
    }

    private func fieldText(_ label: String, color: Color, border: Color) -> some View {
        Text(label)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(color)
            .frame(minHeight: 20)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 5)
                    .fill(theme.segBg)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(border, lineWidth: 0.5))
            )
    }

    // MARK: - Recording lifecycle

    private func begin() {
        error = nil
        actions.suspend()
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .flagsChanged]) { event in
            // Modifiers held alone: stay recording, let the event through.
            guard event.type == .keyDown else { return event }
            handle(event)
            return nil // consume — the keypress is ours
        }
    }

    /// Every exit path funnels here so the monitor teardown and the hotkey
    /// resume can't come apart.
    private func end(with message: String?) {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        error = message
        actions.resume()
    }

    private func cancel() { end(with: nil) }

    private func handle(_ event: NSEvent) {
        if Int(event.keyCode) == kVK_Escape, Shortcut.carbonModifiers(from: event.modifierFlags) == 0 {
            cancel()
            return
        }
        guard let candidate = Shortcut.from(event: event) else { return } // unusable key — keep recording

        if let problem = Shortcut.validate(candidate) {
            end(with: problem.message)
            return
        }
        switch actions.apply(candidate) {
        case .ok, .disabled:
            end(with: nil)
        case .failed(let status):
            end(with: status == OSStatus(eventHotKeyExistsErr)
                ? "That shortcut is in use by another app."
                : "Couldn't register that shortcut.")
        }
    }

    private func disable() {
        if recording { cancel() }
        error = nil
        var off = shortcut
        off.enabled = false
        _ = actions.apply(off)
    }
}
