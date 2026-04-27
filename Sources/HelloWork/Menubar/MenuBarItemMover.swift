// MenuBarItemMover.swift — двигает чужие menubar items через симуляцию cmd+drag.
// Адаптация из Ice (https://github.com/jordanbaird/Ice) — GPLv3.
//
// Принцип:
// 1. Создаём CGEvent .leftMouseDown с modifier .maskCommand в позиции текущего item'а.
//    macOS интерпретирует это как «юзер нажал ⌘+click на menubar item — собирается двигать».
// 2. Создаём .leftMouseUp в целевой позиции (например x=-1000, за край экрана).
//    macOS перемещает item туда.
// 3. windowID указывается в события через CGEventField, чтобы macOS знал что двигать.

import Cocoa

@MainActor
enum MenuBarItemMover {
    /// Перемещает item в указанную абсолютную screen-position.
    /// `targetX` — куда переместить center item'а (X-координата).
    /// Возвращает true при успехе.
    @discardableResult
    static func move(item: MenuBarItem, toX targetX: CGFloat) -> Bool {
        guard item.isHideable else { return false }
        guard let source = CGEventSource(stateID: .hidSystemState) else { return false }

        let startPoint = CGPoint(x: item.frame.midX, y: item.frame.midY)
        let endPoint = CGPoint(x: targetX, y: item.frame.midY)

        guard
            let mouseDown = CGEvent.menuBarItemEvent(
                type: .move(.leftMouseDown),
                location: startPoint,
                windowID: item.windowID,
                pid: item.pid,
                source: source
            ),
            let mouseUp = CGEvent.menuBarItemEvent(
                type: .move(.leftMouseUp),
                location: endPoint,
                windowID: item.windowID,
                pid: item.pid,
                source: source
            )
        else {
            return false
        }

        // Маршрутизируем event на конкретный pid процесса-владельца через
        // postToPid — событие приходит как будто от его собственного process.
        mouseDown.postToPid(item.pid)
        // Микро-задержка — macOS нужно time чтобы accept mouseDown перед mouseUp.
        Thread.sleep(forTimeInterval: 0.05)
        mouseUp.postToPid(item.pid)

        return true
    }

    /// Перемещает item за левый край экрана (off-screen left).
    @discardableResult
    static func hide(_ item: MenuBarItem) -> Bool {
        // -1000 гарантированно за пределами видимого menubar
        return move(item: item, toX: -1000)
    }

    /// Возвращает item в сохранённую позицию.
    @discardableResult
    static func restore(_ item: MenuBarItem, toX originalX: CGFloat) -> Bool {
        return move(item: item, toX: originalX)
    }
}
