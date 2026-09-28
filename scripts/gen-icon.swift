import AppKit

// Renders the 1024×1024 Link Router app icon: a macOS squircle with a
// teal→blue→indigo diagonal gradient and a white "router" mark — one link
// coming in from the left, fanning out into three browser nodes.
//
//   swift scripts/gen-icon.swift Sources/LinkRouter/Resources/icon.png

let S: CGFloat = 1024
let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(S), pixelsHigh: Int(S),
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
let gctx = NSGraphicsContext(bitmapImageRep: rep)!
NSGraphicsContext.current = gctx
let ctx = gctx.cgContext
ctx.clear(CGRect(x: 0, y: 0, width: S, height: S))

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// macOS icon grid: rounded square inset 100px, corner ≈ 0.2237·side.
let margin: CGFloat = 100
let side = S - 2 * margin
let squircle = CGPath(roundedRect: CGRect(x: margin, y: margin, width: side, height: side),
                      cornerWidth: side * 0.2237, cornerHeight: side * 0.2237, transform: nil)

// Drop shadow under the squircle.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 28, color: rgb(0x000000, 0.35))
ctx.addPath(squircle); ctx.setFillColor(rgb(0x1A6FE8)); ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(squircle); ctx.clip()
let bg = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [rgb(0x22D3B6), rgb(0x1A7CF5), rgb(0x3C2E9E)] as CFArray,
                    locations: [0, 0.52, 1])!
ctx.drawLinearGradient(bg, start: CGPoint(x: margin, y: S - margin), end: CGPoint(x: S - margin, y: margin), options: [])
let hi = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),
                    colors: [rgb(0xFFFFFF, 0.20), rgb(0xFFFFFF, 0)] as CFArray, locations: [0, 1])!
ctx.drawLinearGradient(hi, start: CGPoint(x: 0, y: S - margin), end: CGPoint(x: 0, y: S - margin - side * 0.5), options: [])
ctx.restoreGState()

// ── Mark, on a 24-unit grid mapped into the squircle (y-down like the SVG).
let markSize: CGFloat = 560
let ox = (S - markSize) / 2, oy = (S - markSize) / 2
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
    CGPoint(x: ox + x / 24 * markSize, y: S - (oy + y / 24 * markSize))
}
let u = markSize / 24

ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -6), blur: 16, color: rgb(0x0B1E5B, 0.35))
ctx.setStrokeColor(rgb(0xFFFFFF))
ctx.setLineWidth(2.1 * u)
ctx.setLineCap(.round)
let path = CGMutablePath()
path.move(to: p(3.5, 12)); path.addLine(to: p(10, 12))
for y: CGFloat in [5, 12, 19] {
    path.move(to: p(10, 12))
    path.addCurve(to: p(18.6, y), control1: p(14.2, 12), control2: p(14.2, y))
}
ctx.addPath(path); ctx.strokePath()

// Three browser nodes (hollow rings) and the source dot.
for y: CGFloat in [5, 12, 19] {
    let c = p(19.6, y)
    let r = 2.5 * u
    ctx.setFillColor(rgb(0xFFFFFF))
    ctx.fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
}
let src = p(3.2, 12)
ctx.setFillColor(rgb(0xFFFFFF))
ctx.fillEllipse(in: CGRect(x: src.x - 2.0 * u, y: src.y - 2.0 * u, width: 4 * u, height: 4 * u))
ctx.restoreGState()

// Tint the middle node's center so the "chosen" route reads.
let mid = p(19.6, 12)
ctx.setFillColor(rgb(0x1A7CF5))
ctx.fillEllipse(in: CGRect(x: mid.x - 1.1 * u, y: mid.y - 1.1 * u, width: 2.2 * u, height: 2.2 * u))

NSGraphicsContext.restoreGraphicsState()
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("✓ Wrote \(out)")
