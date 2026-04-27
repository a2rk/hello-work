// MenuBarItemMover.swift — двигает чужие menubar items через симуляцию ⌘+drag.
// Адаптация из Ice (https://github.com/jordanbaird/Ice) — GPLv3.
//
// Поток событий, который macOS принимает за «таскаем menubar item»:
//   1. .leftMouseDown с .maskCommand в позиции item'а
//   2. одна или несколько .leftMouseDragged (с .maskCommand) на пути
//   3. .leftMouseUp в целевой позиции (без флагов)
//
// Только Down+Up без Dragged — macOS трактует как обычный ⌘+click, item не уезжает.

import Cocoa

@MainActor
enum MenuBarItemMover {
    /// Перемещает item в указанную абсолютную screen-позицию X.
    /// Возвращает true, если item реально съехал (frame изменился).
    @discardableResult
    static func move(item: MenuBarItem, toX targetX: CGFloat) -> Bool {
        guard item.isHideable else {
            devlog("mover", "skip wid=\(item.windowID) — not hideable")
            return false
        }
        guard let source = CGEventSource(stateID: .hidSystemState) else {
            devlog("mover", "FAIL CGEventSource(hidSystemState) is nil — kernel rejected source creation")
            return false
        }

        let startPoint = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let endPoint = CGPoint(x: targetX, y: item.frame.midY)
        let midPoint = CGPoint(x: (startPoint.x + endPoint.x) / 2, y: startPoint.y)

        devlog("mover",
               "move wid=\(item.windowID) pid=\(item.pid) bid=\(item.bundleID ?? "nil") from=\(String(format: "%.0f", startPoint.x)) to=\(String(format: "%.0f", endPoint.x))")

        let events: [(MenuBarItemEventType, CGPoint)] = [
            (.move(.leftMouseDown),    startPoint),
            (.move(.leftMouseDragged), midPoint),
            (.move(.leftMouseDragged), endPoint),
            (.move(.leftMouseUp),      endPoint),
        ]

        for (idx, (type, location)) in events.enumerated() {
            guard let event = CGEvent.menuBarItemEvent(
                type: type,
                location: location,
                windowID: item.windowID,
                pid: item.pid,
                source: source
            ) else {
                devlog("mover", "FAIL event creation idx=\(idx) for wid=\(item.windowID)")
                return false
            }
            event.postToPid(item.pid)
            Thread.sleep(forTimeInterval: 0.025)
        }

        let moved = MenuBarItem.currentItems().first { $0.windowID == item.windowID }
        guard let nowFrame = moved?.frame else {
            devlog("mover", "post-move: item wid=\(item.windowID) исчез из списка — считаем успехом")
            // Если item удалился из списка — это тоже валидно (например для hide, item ушёл за край).
            return true
        }
        let success = abs(nowFrame.midX - targetX) < abs(item.frame.midX - targetX)
        devlog("mover",
               "post-move wid=\(item.windowID) midX=\(String(format: "%.0f", nowFrame.midX)) target=\(String(format: "%.0f", targetX)) success=\(success)")
        return success
    }

    /// Перемещает item за левый край экрана (off-screen left).
    @discardableResult
    static func hide(_ item: MenuBarItem) -> Bool {
        return move(item: item, toX: -1000)
    }

    /// Возвращает item в сохранённую позицию.
    @discardableResult
    static func restore(_ item: MenuBarItem, toX originalX: CGFloat) -> Bool {
        return move(item: item, toX: originalX)
    }
}
