import Foundation
import AppKit
import Carbon.HIToolbox

/// Один из 4 пресетов или кастомное сочетание.
enum FocusHotkey: Codable, Equatable, Hashable {
    case preset(Preset)
    case custom(keyCode: UInt32, modifiers: UInt32)

    enum Preset: String, CaseIterable, Codable {
        case ctrlShiftF
        case ctrlOptSpace
        case f19
        case hyperD       // ⌃⌥⌘D

        var keyCode: UInt32 {
            switch self {
            case .ctrlShiftF:    return UInt32(kVK_ANSI_F)
            case .ctrlOptSpace:  return UInt32(kVK_Space)
            case .f19:           return UInt32(kVK_F19)
            case .hyperD:        return UInt32(kVK_ANSI_D)
            }
        }

        var modifiers: UInt32 {
            switch self {
            case .ctrlShiftF:    return UInt32(controlKey | shiftKey)
            case .ctrlOptSpace:  return UInt32(controlKey | optionKey)
            case .f19:           return 0
            case .hyperD:        return UInt32(controlKey | optionKey | cmdKey)
            }
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .preset(let p):       return p.keyCode
        case .custom(let kc, _):   return kc
        }
    }

    var modifiers: UInt32 {
        switch self {
        case .preset(let p):           return p.modifiers
        case .custom(_, let mods):     return mods
        }
    }

    /// Сериализация в одну строку для UserDefaults.
    var serialized: String {
        switch self {
        case .preset(let p):
            return "preset:\(p.rawValue)"
        case .custom(let kc, let mods):
            return "custom:\(kc):\(mods)"
        }
    }

    static func deserialize(_ raw: String) -> FocusHotkey? {
        if raw.hasPrefix("preset:") {
            let name = String(raw.dropFirst("preset:".count))
            if let p = Preset(rawValue: name) { return .preset(p) }
        }
        if raw.hasPrefix("custom:") {
            let parts = raw.dropFirst("custom:".count).split(separator: ":")
            if parts.count == 2,
               let kc = UInt32(parts[0]),
               let mods = UInt32(parts[1]) {
                return .custom(keyCode: kc, modifiers: mods)
            }
        }
        return nil
    }

    /// Человеческое отображение через символы клавиш.
    func displayString() -> String {
        var parts: [String] = []
        let m = Int(modifiers)
        if (m & controlKey) != 0 { parts.append("⌃") }
        if (m & optionKey)  != 0 { parts.append("⌥") }
        if (m & shiftKey)   != 0 { parts.append("⇧") }
        if (m & cmdKey)     != 0 { parts.append("⌘") }
        parts.append(KeyCodeNames.symbol(for: keyCode))
        return parts.joined()
    }

    /// Дефолт.
    static let `default`: FocusHotkey = .preset(.ctrlShiftF)
}

/// Маппинг keyCode → видимый символ.
enum KeyCodeNames {
    static func symbol(for keyCode: UInt32) -> String {
        let kc = Int(keyCode)
        switch kc {
        case kVK_Space:       return "Space"
        case kVK_Return:      return "↩"
        case kVK_Tab:         return "⇥"
        case kVK_Delete:      return "⌫"
        case kVK_ForwardDelete: return "⌦"
        case kVK_Escape:      return "⎋"
        case kVK_LeftArrow:   return "←"
        case kVK_RightArrow:  return "→"
        case kVK_UpArrow:     return "↑"
        case kVK_DownArrow:   return "↓"
        case kVK_F1:  return "F1"
        case kVK_F2:  return "F2"
        case kVK_F3:  return "F3"
        case kVK_F4:  return "F4"
        case kVK_F5:  return "F5"
        case kVK_F6:  return "F6"
        case kVK_F7:  return "F7"
        case kVK_F8:  return "F8"
        case kVK_F9:  return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_F13: return "F13"
        case kVK_F14: return "F14"
        case kVK_F15: return "F15"
        case kVK_F16: return "F16"
        case kVK_F17: return "F17"
        case kVK_F18: return "F18"
        case kVK_F19: return "F19"
        case kVK_F20: return "F20"
        default: break
        }
        // Из ASCII ANSI клавиш — берём через UCKeyTranslate.
        if let s = printableSymbol(forKeyCode: keyCode) {
            return s.uppercased()
        }
        return "?"
    }

    private static func printableSymbol(forKeyCode keyCode: UInt32) -> String? {
        guard let layout = TISCopyCurrentKeyboardLayoutInputSource()?.takeRetainedValue(),
              let layoutDataPtr = TISGetInputSourceProperty(layout, kTISPropertyUnicodeKeyLayoutData)
        else { return nil }
        let data = unsafeBitCast(layoutDataPtr, to: CFData.self)
        let layoutBytes = CFDataGetBytePtr(data)
        let keyLayoutPtr = UnsafeRawPointer(layoutBytes!).assumingMemoryBound(to: UCKeyboardLayout.self)

        var deadKeyState: UInt32 = 0
        var actualLength: Int = 0
        let maxChars = 4
        var chars = [UniChar](repeating: 0, count: maxChars)
        let status = UCKeyTranslate(
            keyLayoutPtr,
            UInt16(keyCode),
            UInt16(kUCKeyActionDisplay),
            0,
            UInt32(LMGetKbdType()),
            UInt32(kUCKeyTranslateNoDeadKeysBit),
            &deadKeyState,
            maxChars,
            &actualLength,
            &chars
        )
        guard status == noErr, actualLength > 0 else { return nil }
        return String(utf16CodeUnits: chars, count: actualLength)
    }
}
