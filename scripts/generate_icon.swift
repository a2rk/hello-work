#!/usr/bin/env swift

import AppKit

// generate_icon.swift — генерит ДВА icon set'а:
//   AppIcon.iconset           — белый фон, чёрная H (engine)
//   AppIconInstaller.iconset  — чёрный фон, белая H (installer/stub)

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

struct IconVariant {
    let outDirName: String
    let bg: NSColor
    let fg: NSColor
}

let variants: [IconVariant] = [
    IconVariant(outDirName: "AppIcon.iconset",          bg: .white, fg: .black),
    IconVariant(outDirName: "AppIconInstaller.iconset", bg: .black, fg: .white),
]

for variant in variants {
    let outDir = "\(scriptDir)/\(variant.outDirName)"

    try FileManager.default.createDirectory(
        atPath: outDir, withIntermediateDirectories: true
    )

    print("▶ \(variant.outDirName)")
    for (name, px) in sizes {
        let img = NSImage(size: NSSize(width: px, height: px))
        img.lockFocus()

        variant.bg.setFill()
        let rect = NSRect(x: 0, y: 0, width: px, height: px)
        let radius = CGFloat(px) * 0.22
        NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()

        let fontSize = CGFloat(px) * 0.62
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .heavy),
            .foregroundColor: variant.fg
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
    }
    print("  ✓ \(sizes.count) png в \(outDir)")
}
