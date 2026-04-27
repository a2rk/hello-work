import AppKit

enum MenuBarIcon {
    static func make(style: StatusIconStyle = .solid) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            switch style {
            case .solid:
                drawSolid(in: rect)
            case .outline:
                drawOutline(in: rect)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    private static func drawSolid(in rect: NSRect) {
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
    }

    private static func drawOutline(in rect: NSRect) {
        // Тонкая «H» — обводка через NSStroke (negative stroke width — outline+fill, но мы хотим
        // только outline, поэтому рисуем clear fill через .strokeWidth = 5, и .strokeColor.
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.clear,
            .strokeColor: NSColor.black,
            .strokeWidth: 5
        ]
        let str = NSAttributedString(string: "H", attributes: attrs)
        let strSize = str.size()
        let point = NSPoint(
            x: (rect.width - strSize.width) / 2,
            y: (rect.height - strSize.height) / 2
        )
        str.draw(at: point)
    }
}
