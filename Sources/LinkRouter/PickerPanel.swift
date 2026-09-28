import AppKit

/// Borderless, floating, frosted panel — the same chrome as Recallyx's
/// history panel. Subclassed so a borderless window can become key.
final class PickerPanel: NSPanel {
    init(contentView: NSView, size: NSSize) {
        super.init(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        isFloatingPanel = true
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.blendingMode = .behindWindow
        blur.state = .active
        blur.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false

        let host = NSView()
        host.wantsLayer = true
        host.layer?.cornerRadius = 14
        host.layer?.masksToBounds = true
        host.addSubview(blur)
        host.addSubview(contentView)
        for v in [blur, contentView] {
            NSLayoutConstraint.activate([
                v.topAnchor.constraint(equalTo: host.topAnchor),
                v.bottomAnchor.constraint(equalTo: host.bottomAnchor),
                v.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                v.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            ])
        }
        self.contentView = host
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
