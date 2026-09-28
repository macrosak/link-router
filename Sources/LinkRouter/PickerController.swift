import AppKit
import SwiftUI
import LinkRouterCore

/// Owns the picker panel: builds it per link, centers it on the mouse's
/// screen, and routes navigation keys to the view model while typed characters
/// reach the search field.
@MainActor
final class PickerController {
    static let width: CGFloat = 600
    private static let maxVisibleRows = 8

    private var panel: PickerPanel?
    private(set) var viewModel: PickerViewModel?
    private var previousApp: NSRunningApplication?
    private var monitors: [Any] = []

    /// US-keyboard keyCodes for digits 1…9.
    private static let digitKeyCodes: [UInt16: Int] = [
        0x12: 1, 0x13: 2, 0x14: 3, 0x15: 4, 0x17: 5, 0x16: 6, 0x1A: 7, 0x1C: 8, 0x19: 9,
    ]

    var isVisible: Bool { panel?.isVisible == true }

    func show(
        urls: [URL],
        context: LinkContext,
        targets: [BrowserTarget],
        onCreateRule: @escaping (BrowserTarget?, [URL]) -> Void = { _, _ in },
        onChoose: @escaping (BrowserTarget, Bool, [URL]) -> Void
    ) {
        let start = DispatchTime.now()
        // A new link while the picker is up joins the pending batch.
        let pending = (viewModel?.urls ?? []) + urls
        let previous = isVisible ? previousApp : NSWorkspace.shared.frontmostApplication
        if isVisible { teardown(restoreFocus: false) }
        previousApp = previous

        let vm = PickerViewModel(urls: pending, context: context, targets: targets)
        vm.onChoose = { [weak self] target, remember in
            self?.teardown(restoreFocus: false)
            onChoose(target, remember, pending)
        }
        vm.onCancel = { [weak self] in self?.teardown(restoreFocus: true) }
        vm.onCreateRule = { [weak self, weak vm] in
            let selected = vm?.selected
            self?.teardown(restoreFocus: false)
            onCreateRule(selected, pending)
        }
        viewModel = vm

        let rows = max(1, min(targets.count, Self.maxVisibleRows))
        let listHeight = CGFloat(rows) * (PickerView.rowHeight + 1) + 12
        let size = NSSize(width: Self.width, height: PickerView.chromeHeight - 12 + listHeight)
        let hosting = NSHostingView(rootView: PickerView(viewModel: vm, listHeight: listHeight))
        hosting.frame = NSRect(origin: .zero, size: size)
        let panel = PickerPanel(contentView: hosting, size: size)
        self.panel = panel
        center(panel)
        installMonitors()

        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        Log.info("picker shown targets=\(targets.count) (\(Log.ms(since: start)))")
    }

    func dismiss() { teardown(restoreFocus: true) }

    private func teardown(restoreFocus: Bool) {
        monitors.forEach { NSEvent.removeMonitor($0) }
        monitors = []
        panel?.orderOut(nil)
        panel = nil
        viewModel = nil
        // Cancelling hands focus back to where the user clicked the link;
        // choosing leaves it to the browser, which the launcher activates.
        if restoreFocus { previousApp?.activate(options: []) }
        previousApp = nil
    }

    private func center(_ panel: NSPanel) {
        let mouse = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(mouse) }) ?? NSScreen.main else { return }
        let v = screen.visibleFrame
        let s = panel.frame.size
        let x = v.minX + (v.width - s.width) / 2
        let y = min(max(v.minY + v.height * 0.6 - s.height / 2, v.minY), v.maxY - s.height)
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func installMonitors() {
        if let m = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self] e in
            self?.handleKeyDown(e) ?? e
        }) { monitors.append(m) }
        if let m = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged, handler: { [weak self] e in
            self?.viewModel?.commandHeld = e.modifierFlags.contains(.command)
            return e
        }) { monitors.append(m) }
        // Clicking anywhere else cancels.
        if let m = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown], handler: { [weak self] _ in
            Task { @MainActor in self?.viewModel?.onCancel() }
        }) { monitors.append(m) }
    }

    func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard let vm = viewModel else { return event }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        if flags.contains(.command), let digit = Self.digitKeyCodes[event.keyCode] {
            vm.choose(at: digit - 1, remember: flags.contains(.option))
            return nil
        }
        if flags.contains(.command), event.charactersIgnoringModifiers == "r" {
            vm.onCreateRule()
            return nil
        }
        if flags.contains(.command), event.charactersIgnoringModifiers == "c",
           panel?.firstResponder.map({ ($0 as? NSTextView)?.selectedRange().length ?? 0 }) == 0 {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(vm.urls.map(\.absoluteString).joined(separator: "\n"), forType: .string)
            vm.onCancel()
            return nil
        }
        switch event.keyCode {
        case 0x7E: vm.moveUp(); return nil                                     // ↑
        case 0x7D: vm.moveDown(); return nil                                   // ↓
        case 0x24, 0x4C: vm.confirm(remember: flags.contains(.option)); return nil  // ↵
        case 0x35: vm.cancel(); return nil                                     // esc
        case 0x30: flags.contains(.shift) ? vm.moveUp() : vm.moveDown(); return nil  // ⇥
        default: return event
        }
    }
}
