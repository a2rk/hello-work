import AppKit

enum MenuBarIcon {
    /// Базовая иконка H без сепаратора.
    static func make(style: StatusIconStyle = .solid) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            switch style {
            case .solid:    drawH(in: rect, weight: .heavy, stroke: false)
            case .outline:  drawH(in: rect, weight: .bold, stroke: true)
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Vertical line icon — visible marker для hider separator'а.
    /// Юзер видит эту палку и понимает: «слева от меня — зона скрытия».
    static func separatorLine() -> NSImage {
        let size = NSSize(width: 6, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            let bar = NSRect(x: 2, y: 3, width: 1.5, height: rect.height - 6)
            NSColor.black.setFill()
            bar.fill()
            return true
        }
        image.isTemplate = true
        return image
    }

    /// Иконка H с visible vertical separator-bar справа.
    /// Используется как middle-marker в нашей версии Hidden Bar approach.
    static func makeWithSeparator(style: StatusIconStyle = .solid) -> NSImage {
        let size = NSSize(width: 26, height: 18)
        let image = NSImage(size: size, flipped: false) { rect in
            // H в левой части
            let hRect = NSRect(x: 0, y: 0, width: 18, height: rect.height)
            switch style {
            case .solid:    drawH(in: hRect, weight: .heavy, stroke: false)
            case .outline:  drawH(in: hRect, weight: .bold, stroke: true)
            }

            // Vertical separator-bar справа от H
            let barRect = NSRect(x: rect.width - 4, y: 3, width: 1.5, height: rect.height - 6)
            NSColor.black.setFill()
            barRect.fill()

            return true
        }
        image.isTemplate = true
        return image
    }

    // MARK: - H drawing

    private static func drawH(in rect: NSRect, weight: NSFont.Weight, stroke: Bool) {
        let attrs: [NSAttributedString.Key: Any]
        if stroke {
            attrs = [
                .font: NSFont.systemFont(ofSize: 14, weight: weight),
                .foregroundColor: NSColor.clear,
                .strokeColor: NSColor.black,
                .strokeWidth: 5
            ]
        } else {
            attrs = [
                .font: NSFont.systemFont(ofSize: 14, weight: weight),
                .foregroundColor: NSColor.black
            ]
        }
        let str = NSAttributedString(string: "H", attributes: attrs)
        let strSize = str.size()
        let point = NSPoint(
            x: rect.origin.x + (rect.width - strSize.width) / 2,
            y: rect.origin.y + (rect.height - strSize.height) / 2
        )
        str.draw(at: point)
    }
}
