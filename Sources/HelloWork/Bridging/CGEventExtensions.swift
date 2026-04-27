// CGEventExtensions.swift — симуляция cmd+drag для перемещения чужих menubar items.
// Адаптация из Ice (https://github.com/jordanbaird/Ice) — GPLv3.

import CoreGraphics

// MARK: - Event types

enum MenuBarItemEventButtonState {
    case leftMouseDown
    case leftMouseUp
    case leftMouseDragged
    case rightMouseDown
    case rightMouseUp
    case otherMouseDown
    case otherMouseUp
}

enum MenuBarItemEventType {
    case move(MenuBarItemEventButtonState)
    case click(MenuBarItemEventButtonState)

    var buttonState: MenuBarItemEventButtonState {
        switch self {
        case .move(let s), .click(let s): return s
        }
    }

    var cgEventType: CGEventType {
        switch buttonState {
        case .leftMouseDown:    return .leftMouseDown
        case .leftMouseUp:      return .leftMouseUp
        case .leftMouseDragged: return .leftMouseDragged
        case .rightMouseDown:   return .rightMouseDown
        case .rightMouseUp:     return .rightMouseUp
        case .otherMouseDown:   return .otherMouseDown
        case .otherMouseUp:     return .otherMouseUp
        }
    }

    /// Для .move на mouseDown и mouseDragged держим maskCommand —
    /// macOS только при ⌘+drag интерпретирует движение как «таскаем menubar item».
    /// На mouseUp флаг убираем (как реальный отпуск кнопки).
    var cgEventFlags: CGEventFlags {
        switch self {
        case .move(.leftMouseDown), .move(.leftMouseDragged): return .maskCommand
        case .move, .click:                                   return []
        }
    }

    var mouseButton: CGMouseButton {
        switch buttonState {
        case .leftMouseDown, .leftMouseUp, .leftMouseDragged: return .left
        case .rightMouseDown, .rightMouseUp:                  return .right
        case .otherMouseDown, .otherMouseUp:                  return .center
        }
    }
}

// MARK: - CGEventField helpers

extension CGEventField {
    /// Скрытое поле — windowID (0x33). Используется для адресации события на конкретное окно.
    static let menubarItemWindowID = CGEventField(rawValue: 0x33)!
}

// MARK: - CGEvent constructor

extension CGEvent {
    /// Создаёт mouse event адресованный конкретному menubar item.
    /// pid — owner процесса item'а; мы маршалируем event как будто пришёл от его процесса.
    static func menuBarItemEvent(
        type: MenuBarItemEventType,
        location: CGPoint,
        windowID: CGWindowID,
        pid: pid_t,
        source: CGEventSource
    ) -> CGEvent? {
        let mouseType = type.cgEventType
        let mouseButton = type.mouseButton

        guard let event = CGEvent(
            mouseEventSource: source,
            mouseType: mouseType,
            mouseCursorPosition: location,
            mouseButton: mouseButton
        ) else {
            return nil
        }

        event.flags = type.cgEventFlags

        let targetPID = Int64(pid)
        let userData = Int64(truncatingIfNeeded: Int(bitPattern: ObjectIdentifier(event)))
        let widValue = Int64(windowID)

        event.setIntegerValueField(.eventTargetUnixProcessID, value: targetPID)
        event.setIntegerValueField(.eventSourceUserData, value: userData)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointer, value: widValue)
        event.setIntegerValueField(.mouseEventWindowUnderMousePointerThatCanHandleThisEvent, value: widValue)
        event.setIntegerValueField(.menubarItemWindowID, value: widValue)

        if case .click = type {
            event.setIntegerValueField(.mouseEventClickState, value: 1)
        }

        return event
    }
}
