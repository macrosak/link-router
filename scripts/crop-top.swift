// Crops a PNG to <width>x<height> keeping the top-left corner, in place.
// (`sips -c` always crops around the centre, which cut off the Settings headers.)
// usage: swift scripts/crop-top.swift <file.png> <height> [width]
import AppKit

let args = CommandLine.arguments
guard args.count >= 3, let height = Int(args[2]),
      let image = NSImage(contentsOfFile: args[1]),
      let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    FileHandle.standardError.write("usage: crop-top.swift <file.png> <height> [width]\n".data(using: .utf8)!)
    exit(1)
}
let width = args.count > 3 ? Int(args[3]) ?? cg.width : cg.width
let rect = CGRect(x: 0, y: 0, width: min(width, cg.width), height: min(height, cg.height))
guard let cropped = cg.cropping(to: rect),
      let png = NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:]) else { exit(1) }
try png.write(to: URL(fileURLWithPath: args[1]))
