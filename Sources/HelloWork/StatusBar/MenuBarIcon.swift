import AppKit

enum MenuBarIcon {
    /// Иконка для status bar. При `collapsed` иконка шире и содержит `›` справа от H.
    static func make(style: StatusIconStyle = .solid, collapsed: Bool = false) -> NSImage {
        let size = NSSize(width: collapsed ? 26 : 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            switch style {
            case .solid:
                drawSolid(in: rect)
            case .outline:
                drawOutline(in: rect)
            }
            if collapsed {
                drawChevron(in: rect)
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
            x: 2,
            y: (rect.height - strSize.height) / 2
        )
        str.draw(at: point)
    }

    private static func drawOutline(in rect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 14, weight: .bold),
            .foregroundColor: NSColor.clear,
            .strokeColor: NSColor.black,
            .strokeWidth: 5
        ]
        let str = NSAttributedString(string: "H", attributes: attrs)
        let strSize = str.size()
        let point = NSPoint(
            x: 2,
            y: (rect.height - strSize.height) / 2
        )
        str.draw(at: point)
    }

    /// Маленький `›` справа — индикатор collapsed-состояния.
    private static func drawChevron(in rect: NSRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .heavy),
            .foregroundColor: NSColor.black
        ]
        let str = NSAttributedString(string: "›", attributes: attrs)
        let strSize = str.size()
        let point = NSPoint(
            x: rect.width - strSize.width - 2,
            y: (rect.height - strSize.height) / 2
        )
        str.draw(at: point)
    }
}
