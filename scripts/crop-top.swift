import AppKit

// Keeps the top <height> pixels of a PNG (sips -c crops around the centre and
// ignores --cropOffset, which cut the Settings header off the screenshots).
//   swift scripts/crop-top.swift <in.png> <out.png> <height>

let args = CommandLine.arguments
guard args.count == 4, let height = Int(args[3]),
      let src = NSImage(contentsOfFile: args[1])?.cgImage(forProposedRect: nil, context: nil, hints: nil),
      let cropped = src.cropping(to: CGRect(x: 0, y: 0, width: src.width, height: min(height, src.height))),
      let png = NSBitmapImageRep(cgImage: cropped).representation(using: .png, properties: [:])
else { fatalError("usage: crop-top.swift <in.png> <out.png> <height>") }
try! png.write(to: URL(fileURLWithPath: args[2]))
