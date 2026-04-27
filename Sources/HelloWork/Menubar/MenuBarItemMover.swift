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
        guard item.isHideable else { return false }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

        let startPoint = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let endPoint = CGPoint(x: targetX, y: item.frame.midY)
        // Промежуточная точка — нужна, чтобы macOS зарегистрировал drag, а не click.
        let midPoint = CGPoint(
            x: (startPoint.x + endPoint.x) / 2,
            y: startPoint.y
        )

        let events: [(MenuBarItemEventType, CGPoint)] = [
            (.move(.leftMouseDown),    startPoint),
            (.move(.leftMouseDragged), midPoint),
            (.move(.leftMouseDragged), endPoint),
            (.move(.leftMouseUp),      endPoint),
        ]

        for (type, location) in events {
            guard let event = CGEvent.menuBarItemEvent(
                type: type,
                location: location,
                windowID: item.windowID,
                pid: item.pid,
                source: source
            ) else {
                return false
            }
            event.postToPid(item.pid)
            // Маленькая пауза — даём процессу-владельцу прочитать событие из своей очереди
            // до того как кладём следующее. Без неё события склеиваются в click.
            Thread.sleep(forTimeInterval: 0.025)
        }

        // Проверяем, что item реально переехал — frame обновился.
        let moved = MenuBarItem.currentItems().first { $0.windowID == item.windowID }
        guard let nowFrame = moved?.frame else { return false }
        return abs(nowFrame.midX - targetX) < abs(item.frame.midX - targetX)
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
