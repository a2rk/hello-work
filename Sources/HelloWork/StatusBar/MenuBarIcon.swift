import AppKit

enum MenuBarIcon {
    static func make() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 14, weight: .heavy),
                .foregroundColor: NSColor.black
            ]
            let str = NSAttributedString(string: "H", attributes: attrs)
            let strSize = str.size()
            let point = NSPoint(
                x: (rect.width - strSize.width) / 2,
                y: (rect.height - strSize.height) / 2
            )
            str.draw(at: point)
            return true
        }
        image.isTemplate = true
        return image
    }
}
