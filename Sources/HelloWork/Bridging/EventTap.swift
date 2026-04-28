// EventTap.swift — Ice-style scrombleEvent для надёжной доставки CGEvent'а
// в WindowServer на macOS Sequoia. Адаптация Ice (https://github.com/jordanbaird/Ice) — GPLv3.
//
// Sequoia блокирует прямой event.post(.cgSessionEventTap) из user-process'а
// как «external injection». scrombleEvent обходит это:
//   1. nullEvent создан с unique userData
//   2. Tap1 на .pid(ownerPID) — ловит nullEvent, В CALLBACK'е постит realEvent на .sessionEventTap
//   3. Tap2 на .sessionEventTap — ловит realEvent, В CALLBACK'е перепостит обратно на .pid и сигналит «доставлено»
//   4. Постим nullEvent на .pid → запускает цепочку
//
// Финальная доставка realEvent попадает «как relayed» через event flow процесса-
// владельца, что Sequoia принимает как valid event.

import CoreGraphics
import Foundation

@MainActor
enum EventTap {
    /// Куда таp'аем. Враппер над двумя API: tapCreate vs tapCreateForPid.
    enum Location {
        case sessionEventTap
        case hidEventTap
        case annotatedSessionEventTap
        case pid(pid_t)

        var logString: String {
            switch self {
            case .sessionEventTap:           return "session"
            case .hidEventTap:               return "hid"
            case .annotatedSessionEventTap:  return "annotated"
            case .pid(let p):                return "pid(\(p))"
            }
        }
    }

    /// Постит event в указанный location. Для .pid используем postToPid.
    static func postEvent(_ event: CGEvent, to loc: Location) {
        switch loc {
        case .sessionEventTap:           event.post(tap: .cgSessionEventTap)
        case .hidEventTap:                event.post(tap: .cghidEventTap)
        case .annotatedSessionEventTap:  event.post(tap: .cgAnnotatedSessionEventTap)
        case .pid(let p):                event.postToPid(p)
        }
    }

    /// Создаёт tap port. .pid → tapCreateForPid; иначе → tapCreate.
    private static func createTap(
        location: Location,
        options: CGEventTapOptions,
        mask: CGEventMask,
        callback: CGEventTapCallBack,
        userInfo: UnsafeMutableRawPointer?
    ) -> CFMachPort? {
        if case .pid(let pid) = location {
            return CGEvent.tapCreateForPid(
                pid: pid,
                place: .tailAppendEventTap,
                options: options,
                eventsOfInterest: mask,
                callback: callback,
                userInfo: userInfo
            )
        }
        let cgLoc: CGEventTapLocation = {
            switch location {
            case .hidEventTap:               return .cghidEventTap
            case .sessionEventTap:           return .cgSessionEventTap
            case .annotatedSessionEventTap:  return .cgAnnotatedSessionEventTap
            case .pid:                       return .cgSessionEventTap // unreachable
            }
        }()
        return CGEvent.tapCreate(
            tap: cgLoc,
            place: .tailAppendEventTap,
            options: options,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: userInfo
        )
    }

    /// Ice'овский scromble: relayed-injection event'а через double-tap chain.
    /// Возврат: true если real event прошёл всю цепочку в timeout.
    @discardableResult
    static func scrombleEvent(
        _ event: CGEvent,
        from firstLocation: Location,
        to secondLocation: Location,
        timeoutMs: Int = 100
    ) -> Bool {
        guard let nullEvent = CGEvent(source: nil) else {
            devlog("evtap", "scromble: failed to create null event")
            return false
        }
        let nullUserData = Int64(truncatingIfNeeded: Int(bitPattern: ObjectIdentifier(nullEvent)))
        nullEvent.setIntegerValueField(.eventSourceUserData, value: nullUserData)
        let realUserData = event.getIntegerValueField(.eventSourceUserData)

        final class Box {
            var done = false
            let nullUD: Int64
            let realUD: Int64
            let realEvent: CGEvent
            let firstLoc: Location
            let secondLoc: Location
            init(_ nUD: Int64, _ rUD: Int64, _ ev: CGEvent, _ fLoc: Location, _ sLoc: Location) {
                nullUD = nUD; realUD = rUD; realEvent = ev; firstLoc = fLoc; secondLoc = sLoc
            }
        }
        let box = Box(nullUserData, realUserData, event, firstLocation, secondLocation)
        let boxPtr = Unmanaged.passUnretained(box).toOpaque()

        // Tap1: на firstLocation (.pid). Ловит null event, постит real на secondLocation.
        let nullMask: CGEventMask = 1 << UInt64(nullEvent.type.rawValue)
        guard let tap1 = createTap(
            location: firstLocation,
            options: .defaultTap,
            mask: nullMask,
            callback: { _, type, ev, refcon in
                guard let refcon else { return Unmanaged.passUnretained(ev) }
                let b = Unmanaged<Box>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    return Unmanaged.passUnretained(ev)
                }
                if ev.getIntegerValueField(.eventSourceUserData) == b.nullUD {
                    EventTap.postEvent(b.realEvent, to: b.secondLoc)
                }
                return Unmanaged.passUnretained(ev)
            },
            userInfo: boxPtr
        ) else {
            devlog("evtap", "scromble: tap1 create failed (firstLocation=\(firstLocation.logString))")
            return false
        }

        // Tap2: на secondLocation (.session). Ловит real event, перепостит обратно
        // на firstLocation (= завершит цепочку), set'ит done.
        let realMask: CGEventMask = 1 << UInt64(event.type.rawValue)
        guard let tap2 = createTap(
            location: secondLocation,
            options: .listenOnly,
            mask: realMask,
            callback: { _, type, ev, refcon in
                guard let refcon else { return Unmanaged.passUnretained(ev) }
                let b = Unmanaged<Box>.fromOpaque(refcon).takeUnretainedValue()
                if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                    return Unmanaged.passUnretained(ev)
                }
                if ev.getIntegerValueField(.eventSourceUserData) == b.realUD {
                    // Перепостим обратно на firstLocation — финальный leg цепочки.
                    EventTap.postEvent(b.realEvent, to: b.firstLoc)
                    b.done = true
                }
                return Unmanaged.passUnretained(ev)
            },
            userInfo: boxPtr
        ) else {
            devlog("evtap", "scromble: tap2 create failed (secondLocation=\(secondLocation.logString))")
            CFMachPortInvalidate(tap1)
            return false
        }

        let src1 = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap1, 0)
        let src2 = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap2, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src1, .commonModes)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src2, .commonModes)
        CGEvent.tapEnable(tap: tap1, enable: true)
        CGEvent.tapEnable(tap: tap2, enable: true)

        // Запускаем цепочку: null event → tap1.
        postEvent(nullEvent, to: firstLocation)

        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000.0)
        while !box.done && Date() < deadline {
            CFRunLoopRunInMode(.defaultMode, 0.005, true)
        }

        CGEvent.tapEnable(tap: tap1, enable: false)
        CGEvent.tapEnable(tap: tap2, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src1, .commonModes)
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), src2, .commonModes)
        CFMachPortInvalidate(tap1)
        CFMachPortInvalidate(tap2)

        return box.done
    }
}
