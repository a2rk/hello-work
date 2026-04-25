#!/usr/bin/env swift

import AppKit

let sizes: [(name: String, px: Int)] = [
    ("icon_16x16.png",       16),
    ("icon_16x16@2x.png",    32),
    ("icon_32x32.png",       32),
    ("icon_32x32@2x.png",    64),
    ("icon_128x128.png",    128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png",    256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png",    512),
    ("icon_512x512@2x.png", 1024),
]

let scriptDir = (CommandLine.arguments[0] as NSString).deletingLastPathComponent
let outDir = "\(scriptDir)/AppIcon.iconset"

try FileManager.default.createDirectory(
    atPath: outDir, withIntermediateDirectories: true
)

for (name, px) in sizes {
    let img = NSImage(size: NSSize(width: px, height: px))
    img.lockFocus()

    NSColor.white.setFill()
    let rect = NSRect(x: 0, y: 0, width: px, height: px)
    let radius = CGFloat(px) * 0.22
    NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

    let fontSize = CGFloat(px) * 0.62
    let attrs: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
        .foregroundColor: NSColor.black
    ]
    let str = NSAttributedString(string: "H", attributes: attrs)
    let strSize = str.size()
    str.draw(at: NSPoint(
        x: (CGFloat(px) - strSize.width) / 2,
        y: (CGFloat(px) - strSize.height) / 2
    ))

    img.unlockFocus()

    guard let tiff = img.tiffRepresentation,
          let rep = NSBitmapImageRep(data: tiff),
          let png = rep.representation(using: .png, properties: [:])
    else { continue }

    try png.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
    print("  ✓ \(name)  \(px)x\(px)")
}

print("✓ Generated \(sizes.count) icons in \(outDir)")
