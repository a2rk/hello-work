#!/usr/bin/env swift

import AppKit

// generate_dmg_background.swift — генерит 600×400 PNG для DMG background.
// Левая колонка: place HelloWork.app (instruction). Правая: Applications shortcut.
// Стрелка между. Тёмный фон, светлый текст. Без эмодзи.
//
// Output: scripts/dmg-background.png

let scriptDir = (CommandLine.arguments[0] as NSString).deletingLastPathComponent
let outPath = "\(scriptDir)/dmg-background.png"

let width: CGFloat = 600
let height: CGFloat = 400

let img = NSImage(size: NSSize(width: width, height: height))
img.lockFocus()

// Фон — почти-чёрный gradient.
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.07, green: 0.08, blue: 0.10, alpha: 1.0),
    NSColor(calibratedRed: 0.10, green: 0.11, blue: 0.13, alpha: 1.0)
])!
gradient.draw(in: NSRect(x: 0, y: 0, width: width, height: height), angle: 90)

// Заголовок сверху, центрированно.
let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 18, weight: .semibold),
    .foregroundColor: NSColor.white
]
let titleStr = NSAttributedString(string: "Drag HelloWork to Applications", attributes: titleAttrs)
let titleSize = titleStr.size()
titleStr.draw(at: NSPoint(x: (width - titleSize.width) / 2, y: height - 60))

// Подсказка под заголовком.
let hintAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 11, weight: .regular),
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.55)
]
let hintStr = NSAttributedString(
    string: "Open dragged app, allow permissions in System Settings",
    attributes: hintAttrs
)
let hintSize = hintStr.size()
hintStr.draw(at: NSPoint(x: (width - hintSize.width) / 2, y: height - 90))

// Стрелка по середине, между двумя icon-областями. Тонкая, accent-зелёная.
NSColor(calibratedRed: 0.40, green: 0.95, blue: 0.45, alpha: 0.85).setStroke()
let arrowPath = NSBezierPath()
arrowPath.lineWidth = 3
arrowPath.lineCapStyle = .round
let arrowStartX: CGFloat = 230
let arrowEndX: CGFloat = 370
let arrowY: CGFloat = 180
arrowPath.move(to: NSPoint(x: arrowStartX, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowEndX, y: arrowY))
// Наконечник
arrowPath.move(to: NSPoint(x: arrowEndX - 14, y: arrowY + 9))
arrowPath.line(to: NSPoint(x: arrowEndX, y: arrowY))
arrowPath.line(to: NSPoint(x: arrowEndX - 14, y: arrowY - 9))
arrowPath.stroke()

// Подписи под зонами для drag-source и Applications-shortcut.
// Координаты приблизительно матчат AppleScript-layout в package.sh:
// .app кладётся в (160, 180), Applications shortcut в (440, 180).
let labelAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 10, weight: .medium),
    .foregroundColor: NSColor(calibratedWhite: 1.0, alpha: 0.75)
]
let leftLabel = NSAttributedString(string: "HelloWork.app", attributes: labelAttrs)
let leftSize = leftLabel.size()
leftLabel.draw(at: NSPoint(x: 160 - leftSize.width / 2, y: 100))

let rightLabel = NSAttributedString(string: "Applications", attributes: labelAttrs)
let rightSize = rightLabel.size()
rightLabel.draw(at: NSPoint(x: 440 - rightSize.width / 2, y: 100))

img.unlockFocus()

guard let tiff = img.tiffRepresentation,
      let rep = NSBitmapImageRep(data: tiff),
      let png = rep.representation(using: .png, properties: [:])
else {
    print("✗ failed to render PNG")
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outPath))
print("✓ \(outPath)")
