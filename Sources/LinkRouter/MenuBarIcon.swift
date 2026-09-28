import AppKit

/// Template menu-bar glyph: the brand mark (one line fanning out to three).
enum MenuBarIcon {
    static let image: NSImage = {
        let img = NSImage(size: NSSize(width: 18, height: 18), flipped: true) { rect in
            let s = rect.width / 24
            func p(_ x: CGFloat, _ y: CGFloat) -> NSPoint { NSPoint(x: x * s, y: y * s) }
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let path = NSBezierPath()
            path.lineWidth = 2.1 * s
            path.lineCapStyle = .round
            path.move(to: p(3, 12)); path.line(to: p(10, 12))
            for y: CGFloat in [5, 12, 19] {
                path.move(to: p(10, 12))
                path.curve(to: p(18.5, y), controlPoint1: p(14, 12), controlPoint2: p(14, y))
            }
            path.stroke()
            for y: CGFloat in [5, 12, 19] {
                NSBezierPath(ovalIn: NSRect(x: 17.6 * s, y: (y - 2.3) * s, width: 4.6 * s, height: 4.6 * s)).fill()
            }
            NSBezierPath(ovalIn: NSRect(x: 1 * s, y: 9.9 * s, width: 4.2 * s, height: 4.2 * s)).fill()
            return true
        }
        img.isTemplate = true
        return img
    }()
}
