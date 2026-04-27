// MenuBarItemMover.swift — двигает чужие menubar items через симуляцию ⌘+drag.
// Адаптация из Ice (https://github.com/jordanbaird/Ice) — GPLv3.
//
// Что важно для Sequoia:
//   1. Постим через .cghidEventTap (а не .postToPid) — события идут через
//      WindowServer, который реально обрабатывает menubar drag. .postToPid
//      в Sequoia доходит только до event loop процесса-владельца, минуя
//      WindowServer'овский «menubar item drag» state machine.
//   2. CGEventSource(stateID: .combinedSessionState) — события неотличимы
//      от реальных hardware events. Apple ужесточил фильтрацию synthetic'а
//      из .hidSystemState на menubar.
//   3. До и после постинга сохраняем/восстанавливаем реальную позицию курсора
//      через CGWarpMouseCursorPosition — иначе курсор «прыгает» на каждое
//      движение item'а.
//   4. Полная последовательность ⌘+drag: Down → Dragged(mid) → Dragged(end) → Up
//      Без промежуточных Dragged macOS видит просто ⌘+click и item не уезжает.

import Cocoa

@MainActor
enum MenuBarItemMover {
    @discardableResult
    static func move(item: MenuBarItem, toX targetX: CGFloat) -> Bool {
        guard item.isHideable else {
            devlog("mover", "skip wid=\(item.windowID) — not hideable")
            return false
        }
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            devlog("mover", "FAIL CGEventSource(combinedSessionState) is nil")
            return false
        }

        // Сохраняем реальную позицию курсора, чтобы восстановить после движения.
        let cursorBefore = NSEvent.mouseLocation
        let savedCursorCG = CGPoint(
            x: cursorBefore.x,
            y: (NSScreen.screens.first?.frame.height ?? 0) - cursorBefore.y
        )

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
                CGWarpMouseCursorPosition(savedCursorCG)
                return false
            }
            // Постим в session event tap — события идут через WindowServer.
            // Дублируем postToPid для подстраховки (некоторые apps читают только из своего queue).
            event.post(tap: .cghidEventTap)
            event.postToPid(item.pid)
            // Достаточно длинная пауза — Sequoia на меньшем интервале склеивает в click.
            Thread.sleep(forTimeInterval: 0.05)
        }

        // Восстанавливаем курсор на исходное место.
        CGWarpMouseCursorPosition(savedCursorCG)

        // Даём WindowServer обработать события.
        Thread.sleep(forTimeInterval: 0.04)

        // Проверяем frame через лёгкий per-window CGS вместо полного menubar enum.
        // Если окно исчезло (frame == nil) — это валидный «успех» для off-screen hide.
        guard let nowFrame = Bridging.getWindowFrame(for: item.windowID) else {
            devlog("mover", "post-move wid=\(item.windowID) frame nil — считаем успехом")
            return true
        }
        let success = abs(nowFrame.midX - targetX) < abs(item.frame.midX - targetX)
        devlog("mover",
               "post-move wid=\(item.windowID) midX=\(String(format: "%.0f", nowFrame.midX)) target=\(String(format: "%.0f", targetX)) success=\(success)")
        return success
    }

    @discardableResult
    static func hide(_ item: MenuBarItem) -> Bool {
        return move(item: item, toX: -1000)
    }

    @discardableResult
    static func restore(_ item: MenuBarItem, toX originalX: CGFloat) -> Bool {
        return move(item: item, toX: originalX)
    }
}
