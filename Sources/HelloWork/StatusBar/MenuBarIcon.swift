import AppKit

enum MenuBarIcon {
    /// Иконка для status bar.
    /// `collapsed = false` (всё видно) → SOLID H (плотная заливка).
    /// `collapsed = true` (всё скрыто) → OUTLINE H (контур, как индикатор «свёрнуто»).
    static func make(style: StatusIconStyle = .solid, collapsed: Bool = false) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // collapsed → outline (контур). expanded → solid.
            // Если юзер выбрал стиль outline в Settings — он берётся для expanded состояния.
            // collapsed всегда показывается как outline для индикации.
            if collapsed {
                drawOutline(in: rect)
            } else {
                switch style {
                case .solid:    drawSolid(in: rect)
                case .outline:  drawOutline(in: rect)
                }
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
