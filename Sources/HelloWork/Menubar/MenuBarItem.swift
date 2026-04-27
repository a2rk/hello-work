// MenuBarItem.swift — модель menubar item'а.
// Lite-версия адаптации из Ice (https://github.com/jordanbaird/Ice) — GPLv3.

import Cocoa

/// Представление одного menubar item — окна layer 25.
struct MenuBarItem: Equatable {
    let windowID: CGWindowID
    let pid: pid_t
    let frame: CGRect
    let title: String?
    let ownerName: String?

    /// bundleID владеющего приложения (через NSRunningApplication).
    var bundleID: String? {
        NSRunningApplication(processIdentifier: pid)?.bundleIdentifier
    }

    /// Apple-managed menubar items нельзя двигать (Time, Control Center, Spotlight, IME и т.п.).
    /// Это immutable secured zone — попытка двинуть приведёт к ошибке или ничему.
    var isMovable: Bool {
        guard let bid = bundleID else { return true }
        // Bundle IDs системных process'ов с защищёнными menubar items.
        let immovable: Set<String> = [
            "com.apple.controlcenter",
            "com.apple.systemuiserver",
            "com.apple.Spotlight",
            "com.apple.TextInputMenuAgent",
            "com.apple.notificationcenterui",
            "com.apple.dock"
        ]
        return !immovable.contains(bid)
    }

    /// Не двигаем сам Hello work — нашу H-иконку.
    var isOurOwn: Bool {
        bundleID == Bundle.main.bundleIdentifier
    }

    /// Item подходит для скрытия.
    var isHideable: Bool {
        isMovable && !isOurOwn
    }

    /// Список текущих menubar items через Bridging (приватный CGS API).
    static func currentItems() -> [MenuBarItem] {
        let ids = Bridging.getWindowList(option: [.menuBarItems, .onScreen])
        return ids.compactMap { id in
            guard let frame = Bridging.getWindowFrame(for: id) else { return nil }
            // pid и owner получаем через CGWindowList публичный API
            // (приватный CGSWindowGetOwner возможен но не нужен — есть публичная альтернатива).
            guard let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]],
                  let entry = info.first,
                  let pidNum = entry[kCGWindowOwnerPID as String] as? Int else {
                return nil
            }
            return MenuBarItem(
                windowID: id,
                pid: pid_t(pidNum),
                frame: frame,
                title: entry[kCGWindowName as String] as? String,
                ownerName: entry[kCGWindowOwnerName as String] as? String
            )
        }
        .sorted { $0.frame.minX < $1.frame.minX }   // слева направо
    }
}
