// MenuBarItemMover.swift — Ice-style menubar item drag.
// Адаптация подхода Ice (https://github.com/jordanbaird/Ice) — GPLv3.
//
// Ключевые принципы:
//   1. Sequence: mouseDown (off-screen + cmd) + mouseUp (anchor location, no cmd).
//   2. windowID-field на Down = item, на Up = ANCHOR (relative-to команда WS).
//   3. CGEventSource(.hidSystemState) для events + permitAllEvents на
//      CGEventSource(.combinedSessionState).
//   4. scrombleEvent через double-tap chain (.pid → .session → .pid)
//      — Sequoia принимает как valid relay вместо external injection.
//   5. Permissions: AX (Accessibility) + IOHID listen access (Input Monitoring).
//      Без Input Monitoring — CGEvent.tapCreate возвращает nil.

import Cocoa
import IOKit.hid

@MainActor
enum MenuBarItemMover {
    /// Куда двигаем item: слева или справа от anchor item'а.
    enum Destination {
        case leftOf(MenuBarItem)
        case rightOf(MenuBarItem)

        var anchor: MenuBarItem {
            switch self {
            case .leftOf(let i), .rightOf(let i): return i
            }
        }

        /// Точка в которую ставим mouseUp. Чуть левее или правее anchor'а.
        var endPoint: CGPoint {
            switch self {
            case .leftOf(let a):  return CGPoint(x: a.frame.minX - 4, y: a.frame.midY)
            case .rightOf(let a): return CGPoint(x: a.frame.maxX + 4, y: a.frame.midY)
            }
        }
    }

    /// Проверяет и при необходимости запрашивает Input Monitoring permission.
    /// CGEvent.tapCreate / tapCreateForPid требуют либо kIOHIDRequestTypeListenEvent,
    /// либо AX trust. На Sequoia для menubar-уровня обычно нужны ОБА.
    /// Возвращает текущий статус после возможного запроса.
    @discardableResult
    static func ensureInputMonitoring() -> IOHIDAccessType {
        let current = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        devlog("mover", "IOHIDCheckAccess(ListenEvent) = \(inputMonitoringName(current))")
        if current == kIOHIDAccessTypeUnknown || current == kIOHIDAccessTypeDenied {
            devlog("mover", "IOHIDRequestAccess(ListenEvent) — system prompt should appear")
            let granted = IOHIDRequestAccess(kIOHIDRequestTypeListenEvent)
            devlog("mover", "IOHIDRequestAccess returned granted=\(granted)")
            let after = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
            devlog("mover", "IOHIDCheckAccess after request = \(inputMonitoringName(after))")
            return after
        }
        return current
    }

    private static func inputMonitoringName(_ t: IOHIDAccessType) -> String {
        switch t {
        case kIOHIDAccessTypeGranted: return "GRANTED"
        case kIOHIDAccessTypeDenied:  return "DENIED"
        case kIOHIDAccessTypeUnknown: return "UNKNOWN(not-asked)"
        default:                       return "raw=\(t.rawValue)"
        }
    }

    @discardableResult
    static func move(item: MenuBarItem, to destination: Destination) -> Bool {
        let trusted = AXIsProcessTrusted()
        let imAccess = IOHIDCheckAccess(kIOHIDRequestTypeListenEvent)
        let anchor = destination.anchor
        devlog("mover", "ENTER move wid=\(item.windowID) bid=\(item.bundleID ?? "nil") AX=\(trusted) IM=\(inputMonitoringName(imAccess)) → \(destinationLogString(destination)) anchor wid=\(anchor.windowID) bid=\(anchor.bundleID ?? "nil")")

        guard item.isHideable else {
            devlog("mover", "skip wid=\(item.windowID) — not hideable")
            return false
        }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            devlog("mover", "FAIL CGEventSource(hidSystemState) is nil")
            return false
        }
        guard let permitSource = CGEventSource(stateID: .combinedSessionState) else {
            devlog("mover", "FAIL CGEventSource(combinedSessionState) is nil")
            return false
        }

        let permitMask: CGEventFilterMask = [
            .permitLocalMouseEvents,
            .permitLocalKeyboardEvents,
            .permitSystemDefinedEvents
        ]
        permitSource.setLocalEventsFilterDuringSuppressionState(
            permitMask, state: .eventSuppressionStateRemoteMouseDrag
        )
        permitSource.setLocalEventsFilterDuringSuppressionState(
            permitMask, state: .eventSuppressionStateSuppressionInterval
        )
        permitSource.localEventsSuppressionInterval = 0

        let cursorBefore = NSEvent.mouseLocation
        let savedCursorCG = CGPoint(
            x: cursorBefore.x,
            y: (NSScreen.screens.first?.frame.height ?? 0) - cursorBefore.y
        )

        // Ice-style: Down off-screen с cmd, Up на anchor location без cmd.
        // КЛЮЧЕВОЕ: windowID на Down = item (двигаем), на Up = anchor (relative to).
        let startPoint = CGPoint(x: 20_000, y: 20_000)
        let endPoint = destination.endPoint

        devlog("mover",
               "PLAN item-wid=\(item.windowID) anchor-wid=\(anchor.windowID) start=(20000,20000) end=(\(String(format: "%.0f", endPoint.x)),\(String(format: "%.0f", endPoint.y)))")

        guard let downEvent = CGEvent.menuBarItemEvent(
            type: .move(.leftMouseDown),
            location: startPoint,
            windowID: item.windowID,        // Down таргетит item который двигаем
            pid: item.pid,
            source: source
        ) else {
            devlog("mover", "FAIL down event creation")
            return false
        }
        guard let upEvent = CGEvent.menuBarItemEvent(
            type: .move(.leftMouseUp),
            location: endPoint,
            windowID: anchor.windowID,      // Up таргетит ANCHOR — relative-to команда
            pid: item.pid,                  // pid всё равно item-owner'а (перехватывает он)
            source: source
        ) else {
            devlog("mover", "FAIL up event creation")
            return false
        }

        // POST mouseDown через scrombleEvent: null event → tap on .pid →
        // callback постит real event на session tap → tap2 ловит и
        // перепостит обратно на .pid. Цепочка которую WS принимает как
        // «valid relay», а не «external injection».
        let downType = downEvent.type.rawValue
        let downFlags = downEvent.flags.rawValue
        let downWid = downEvent.getIntegerValueField(.menubarItemWindowID)
        let downPid = downEvent.getIntegerValueField(.eventTargetUnixProcessID)
        devlog("mover", "SCROMBLE DOWN cgType=\(downType) flags=\(String(format: "0x%X", downFlags)) wid-field=\(downWid) target-pid=\(downPid)")
        let downReceived = EventTap.scrombleEvent(
            downEvent,
            from: .pid(item.pid),
            to: .sessionEventTap,
            timeoutMs: 100
        )
        devlog("mover", "SCROMBLE DOWN delivered=\(downReceived)")

        let midFrame = Bridging.getWindowFrame(for: item.windowID)
        devlog("mover", "MID frame=\(midFrame.map { String(format: "(%.0f,%.0f)", $0.midX, $0.midY) } ?? "nil")")

        let upType = upEvent.type.rawValue
        let upFlags = upEvent.flags.rawValue
        let upWid = upEvent.getIntegerValueField(.menubarItemWindowID)
        let upPid = upEvent.getIntegerValueField(.eventTargetUnixProcessID)
        devlog("mover", "SCROMBLE UP cgType=\(upType) flags=\(String(format: "0x%X", upFlags)) wid-field=\(upWid) target-pid=\(upPid)")
        let upReceived = EventTap.scrombleEvent(
            upEvent,
            from: .pid(item.pid),
            to: .sessionEventTap,
            timeoutMs: 100
        )
        devlog("mover", "SCROMBLE UP delivered=\(upReceived)")

        CGWarpMouseCursorPosition(savedCursorCG)
        Thread.sleep(forTimeInterval: 0.04)

        guard let nowFrame = Bridging.getWindowFrame(for: item.windowID) else {
            devlog("mover", "EXIT wid=\(item.windowID) frame nil — считаем успехом (off-screen)")
            return true
        }
        let success = abs(nowFrame.midX - item.frame.midX) > 50  // двинулся хоть куда-то
        devlog("mover",
               "EXIT wid=\(item.windowID) midX=\(String(format: "%.0f", nowFrame.midX)) origMidX=\(String(format: "%.0f", item.frame.midX)) success=\(success)")
        return success
    }

    /// Скрыть: двигаем за Apple-managed зону (left того что слева).
    /// Передаём anchor — кто будет соседом-якорем для Up event'а.
    @discardableResult
    static func hide(_ item: MenuBarItem, parkAnchor: MenuBarItem) -> Bool {
        return move(item: item, to: .leftOf(parkAnchor))
    }

    /// Восстановить рядом с известным соседом.
    @discardableResult
    static func restore(_ item: MenuBarItem, rightOf neighbor: MenuBarItem) -> Bool {
        return move(item: item, to: .rightOf(neighbor))
    }

    /// Найти park-anchor: самый левый Apple-managed (immovable) item.
    /// Наши hideable items уйдут левее него — за край видимой зоны.
    static func findParkAnchor(in items: [MenuBarItem]) -> MenuBarItem? {
        items
            .filter { !$0.isMovable }
            .min(by: { $0.frame.midX < $1.frame.midX })
    }

    private static func destinationLogString(_ d: Destination) -> String {
        switch d {
        case .leftOf:  return "leftOf"
        case .rightOf: return "rightOf"
        }
    }
}
