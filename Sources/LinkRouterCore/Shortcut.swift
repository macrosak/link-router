import Carbon.HIToolbox
import Foundation

/// One global hotkey binding: the Carbon-facing keyCode + modifier mask, plus a
/// display label captured at record time. Storing the label sidesteps the
/// keyCode→character `UCKeyTranslate` gymnastics; the trade-off is that the
/// label reflects the keyboard layout active when it was recorded.
/// (Same model as Recallyx's `Shortcut`.)
public struct Shortcut: Codable, Equatable, Sendable {
    /// Virtual key code (kVK_* / NSEvent.keyCode) — what `RegisterEventHotKey` wants.
    public var keyCode: UInt32
    /// Carbon cmdKey|shiftKey|controlKey|optionKey mask.
    public var carbonModifiers: UInt32
    /// Unshifted base character ("b", "7") or a special-key name ("Space", "←", "F5").
    /// Kept lowercase for letters; `glyphs` uppercases for display only.
    public var keyLabel: String
    public var enabled: Bool

    public init(keyCode: UInt32, carbonModifiers: UInt32, keyLabel: String, enabled: Bool = true) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
        self.keyLabel = keyLabel
        self.enabled = enabled
    }

    /// ⌃⇧B — "browser"; the sibling of Recallyx's ⌃⇧V. Unused by browsers and
    /// the common IDEs (⌘⌥B is Chrome's bookmark manager, ⌘⇧B its bookmarks bar).
    public static let switchBrowserDefault = Shortcut(
        keyCode: UInt32(kVK_ANSI_B),
        carbonModifiers: UInt32(controlKey | shiftKey),
        keyLabel: "b"
    )

    /// Keycap strings in Apple's canonical ⌃⌥⇧⌘ order, ending with the key.
    public var glyphs: [String] {
        var out: [String] = []
        if carbonModifiers & UInt32(controlKey) != 0 { out.append("⌃") }
        if carbonModifiers & UInt32(optionKey) != 0 { out.append("⌥") }
        if carbonModifiers & UInt32(shiftKey) != 0 { out.append("⇧") }
        if carbonModifiers & UInt32(cmdKey) != 0 { out.append("⌘") }
        out.append(keyLabel.count == 1 ? keyLabel.uppercased() : keyLabel)
        return out
    }

    public static func sameCombo(_ a: Shortcut, _ b: Shortcut) -> Bool {
        a.keyCode == b.keyCode && a.carbonModifiers == b.carbonModifiers
    }
}

// MARK: - Validation

public enum ShortcutError: Equatable, Sendable {
    case noModifier
    case systemReserved

    public var message: String {
        switch self {
        case .noModifier: return "Add ⌘, ⌃, or ⌥."
        case .systemReserved: return "That shortcut is reserved by macOS."
        }
    }
}

extension Shortcut {
    /// Combos `RegisterEventHotKey` would happily grab globally, shadowing them
    /// in every app. Deliberately tiny — anything else is the user's call;
    /// ✕/re-record is the escape hatch.
    private static let systemReserved: [(keyCode: UInt32, modifiers: UInt32)] = [
        (UInt32(kVK_ANSI_Q), UInt32(cmdKey)), // ⌘Q
        (UInt32(kVK_ANSI_W), UInt32(cmdKey)), // ⌘W
        (UInt32(kVK_Tab), UInt32(cmdKey)),    // ⌘⇥
    ]

    /// Pure validation of a freshly recorded candidate. Carbon-layer failures
    /// (combo taken by another app) surface separately via `HotkeyManager.apply`.
    public static func validate(_ candidate: Shortcut) -> ShortcutError? {
        if candidate.carbonModifiers & UInt32(cmdKey | controlKey | optionKey) == 0 {
            return .noModifier
        }
        if systemReserved.contains(where: {
            $0.keyCode == candidate.keyCode && $0.modifiers == candidate.carbonModifiers
        }) {
            return .systemReserved
        }
        return nil
    }
}
