import AppKit
import Carbon.HIToolbox
import LinkRouterCore

private func hotkeyCarbonCallback(
    _ callRef: EventHandlerCallRef?,
    _ eventRef: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    return manager.handleHotkeyEvent(eventRef)
}

/// Carbon global-hotkey registration for the switch-browser shortcut (the
/// same approach as Recallyx's `HotkeyManager`). All changes flow through
/// `apply`; the app delegate pairs it with the config write.
@MainActor
final class HotkeyManager {
    /// Outcome of `apply`. `.failed(-9878)` = combo registered globally by
    /// another app (eventHotKeyExistsErr).
    enum ApplyResult: Equatable {
        case ok
        case disabled
        case failed(OSStatus)
    }

    private let onTrigger: @MainActor () -> Void
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    /// The binding to restore after recording.
    private var current: Shortcut?

    private nonisolated static let signature: UInt32 = 0x4C4E4B52 // "LNKR"
    private nonisolated static let switchID: UInt32 = 1

    init(onTrigger: @escaping @MainActor () -> Void) {
        self.onTrigger = onTrigger
        installEventHandler()
    }

    deinit {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
    }

    /// Re-register: drop the existing ref (if any), then register the new
    /// combo unless the shortcut is disabled.
    func apply(_ shortcut: Shortcut) -> ApplyResult {
        unregister()
        guard shortcut.enabled else {
            current = shortcut
            Log.info("switch hotkey disabled")
            return .disabled
        }
        let hotKeyID = EventHotKeyID(signature: Self.signature, id: Self.switchID)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        if status == noErr, let ref {
            hotKeyRef = ref
            current = shortcut
            Log.info("RegisterEventHotKey \(shortcut.glyphs.joined()) ok")
            return .ok
        }
        Log.error("RegisterEventHotKey \(shortcut.glyphs.joined()) failed status=\(status) (eventHotKeyExistsErr=-9878, paramErr=-50)")
        return .failed(status)
    }

    /// Unregister while the Settings recorder captures keys — Carbon swallows
    /// a registered combo before the app's local NSEvent monitor sees it, so
    /// re-recording the current binding would fire it instead of capturing.
    func suspend() {
        unregister()
        Log.info("hotkey suspended for recording")
    }

    /// Re-apply the binding after recording ends (commit or cancel).
    func resume(_ shortcut: Shortcut) {
        _ = apply(shortcut)
    }

    private func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        hotKeyRef = nil
    }

    nonisolated func handleHotkeyEvent(_ eventRef: EventRef?) -> OSStatus {
        var hkID = EventHotKeyID()
        if let eventRef {
            GetEventParameter(
                eventRef,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hkID
            )
        }
        guard hkID.signature == Self.signature, hkID.id == Self.switchID else { return OSStatus(eventNotHandledErr) }
        Task { @MainActor in self.onTrigger() }
        return noErr
    }

    private func installEventHandler() {
        var spec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let context = Unmanaged.passUnretained(self).toOpaque()
        let status = InstallEventHandler(
            GetApplicationEventTarget(),
            hotkeyCarbonCallback,
            1,
            &spec,
            context,
            &handlerRef
        )
        Log.info("InstallEventHandler status=\(status) (noErr=0)")
    }
}
