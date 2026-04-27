import AppKit

/// Сканирует текущий menubar через CGWindowList (layer 25 = status menu layer).
/// Возвращает список реальных menubar items с pid + иконкой владельца + bounds.
enum MenubarItemsScanner {
    struct Item: Identifiable, Equatable {
        let id: Int        // CGWindowID
        let pid: pid_t
        let name: String
        let icon: NSImage?
        let bounds: CGRect

        static func == (lhs: Item, rhs: Item) -> Bool { lhs.id == rhs.id }
    }

    /// kCGStatusWindowLevel = 25.
    private static let statusLayer = 25

    static func scan() -> [Item] {
        let options: CGWindowListOption = [.optionOnScreenOnly]
        guard let info = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return []
        }

        var items: [Item] = []
        for w in info {
            guard
                let layer = w[kCGWindowLayer as String] as? Int, layer == statusLayer,
                let bounds = w[kCGWindowBounds as String] as? [String: CGFloat],
                let x = bounds["X"], let y = bounds["Y"],
                let width = bounds["Width"], let height = bounds["Height"],
                let winNum = w[kCGWindowNumber as String] as? Int,
                let pidNum = w[kCGWindowOwnerPID as String] as? Int,
                width > 4, height > 4, height < 40   // фильтруем не-status окна
            else { continue }

            let rect = CGRect(x: x, y: y, width: width, height: height)
            let pid = pid_t(pidNum)

            // Имя владельца
            let ownerName = (w[kCGWindowOwnerName as String] as? String) ?? "Unknown"
            let app = NSRunningApplication(processIdentifier: pid)
            let displayName = app?.localizedName ?? ownerName
            let icon = app?.icon

            items.append(Item(
                id: winNum,
                pid: pid,
                name: displayName,
                icon: icon,
                bounds: rect
            ))
        }

        // Сортировка слева направо по X.
        items.sort { $0.bounds.origin.x < $1.bounds.origin.x }
        return items
    }
}
