import Carbon.HIToolbox
import Testing
@testable import LinkRouterCore

@Suite("Shortcut")
struct ShortcutTests {
    @Test func defaultIsControlShiftB() {
        #expect(Shortcut.switchBrowserDefault.glyphs == ["⌃", "⇧", "B"])
        #expect(Shortcut.validate(.switchBrowserDefault) == nil)
    }

    @Test func glyphsUseCanonicalOrder() {
        let all = Shortcut(keyCode: UInt32(kVK_Space),
                           carbonModifiers: UInt32(cmdKey | shiftKey | optionKey | controlKey),
                           keyLabel: "Space")
        #expect(all.glyphs == ["⌃", "⌥", "⇧", "⌘", "Space"])
    }

    @Test func needsARealModifier() {
        let shiftOnly = Shortcut(keyCode: UInt32(kVK_ANSI_B), carbonModifiers: UInt32(shiftKey), keyLabel: "b")
        #expect(Shortcut.validate(shiftOnly) == .noModifier)
    }

    @Test func rejectsSystemCombos() {
        let quit = Shortcut(keyCode: UInt32(kVK_ANSI_Q), carbonModifiers: UInt32(cmdKey), keyLabel: "q")
        #expect(Shortcut.validate(quit) == .systemReserved)
    }
}
