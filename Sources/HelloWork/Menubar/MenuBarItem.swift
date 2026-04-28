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

    /// Apple-managed items внутри controlcenter/systemuiserver: только конкретные
    /// (Clock, Siri, BentoBox) — secured zone которую WindowServer не двигает.
    /// Остальные controlcenter items (Sound, Wi-Fi, Battery, FaceTime и т.п.)
    /// — двигаемы. (Так фильтрует Ice — наш предыдущий bundle-ID-фильтр был
    /// слишком широким, отрезал все 9 CC items как immovable.)
    var isMovable: Bool {
        // Drag-handle / separator между sections (Finder в menubar) — owner
        // == "Window Server", не реальный app process. Не двигаем.
        if ownerName == "Window Server" { return false }

        guard let bid = bundleID else { return true }

        // Системные процессы которые целиком immovable
        let immovableBundles: Set<String> = [
            "com.apple.Spotlight",
            "com.apple.TextInputMenuAgent",
            "com.apple.notificationcenterui",
            "com.apple.dock"
        ]
        if immovableBundles.contains(bid) { return false }

        // controlcenter и systemuiserver — фильтр по title окна (как у Ice).
        if bid == "com.apple.controlcenter" {
            // Точные title для immovable CC sub-items
            let immovableCCTitles: Set<String> = ["Clock", "BentoBox"]
            if let t = title, immovableCCTitles.contains(t) { return false }
        }
        if bid == "com.apple.systemuiserver" {
            let immovableSUITitles: Set<String> = ["Siri"]
            if let t = title, immovableSUITitles.contains(t) { return false }
        }

        return true
    }

    /// Не трогаем сам Hello work — нашу H-иконку. NSStatusItem'ы owned by
    /// `com.apple.controlcenter` через приватный API ControlCenter'а, поэтому
    /// bundleID-сравнение не работает. Фильтруем по title (мы ставим
    /// autosaveName "helloWork_main" в MenubarHiderController.createMain).
    var isOurOwn: Bool {
        title == "helloWork_main"
    }

    /// Item подходит для скрытия.
    var isHideable: Bool {
        isMovable && !isOurOwn
    }

    /// Список текущих menubar items через Bridging (приватный CGS API).
    static func currentItems() -> [MenuBarItem] {
        let ids = Bridging.getWindowList(option: [.menuBarItems, .onScreen])
        var dropped = 0
        let result: [MenuBarItem] = ids.compactMap { id in
            guard let frame = Bridging.getWindowFrame(for: id) else { dropped += 1; return nil }
            guard let pid = Bridging.getWindowOwnerPID(for: id) else { dropped += 1; return nil }
            let info = (CGWindowListCopyWindowInfo([.optionIncludingWindow], id) as? [[String: Any]])?.first
            return MenuBarItem(
                windowID: id,
                pid: pid,
                frame: frame,
                title: info?[kCGWindowName as String] as? String,
                ownerName: info?[kCGWindowOwnerName as String] as? String
            )
        }
        .sorted { $0.frame.minX < $1.frame.minX }
        if dropped > 0 {
            devlog("bridge", "currentItems: \(ids.count) raw IDs, \(dropped) dropped (no frame/pid), \(result.count) usable")
        }
        return result
    }
}
