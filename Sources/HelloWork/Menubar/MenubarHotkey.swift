import Foundation
import AppKit
import Carbon.HIToolbox

/// Хоткей для menubar-hider. Структура зеркальная FocusHotkey, но со своими пресетами:
/// мнемоника B (Bar) или M (Menubar).
enum MenubarHotkey: Codable, Equatable, Hashable {
    case preset(Preset)
    case custom(keyCode: UInt32, modifiers: UInt32)

    enum Preset: String, CaseIterable, Codable {
        case ctrlShiftB
        case ctrlOptB
        case f18
        case hyperM        // ⌃⌥⌘M

        var keyCode: UInt32 {
            switch self {
            case .ctrlShiftB:  return UInt32(kVK_ANSI_B)
            case .ctrlOptB:    return UInt32(kVK_ANSI_B)
            case .f18:         return UInt32(kVK_F18)
            case .hyperM:      return UInt32(kVK_ANSI_M)
            }
        }

        var modifiers: UInt32 {
            switch self {
            case .ctrlShiftB:  return UInt32(controlKey | shiftKey)
            case .ctrlOptB:    return UInt32(controlKey | optionKey)
            case .f18:         return 0
            case .hyperM:      return UInt32(controlKey | optionKey | cmdKey)
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

    /// Адаптер для HotkeyManager (он принимает FocusHotkey, но логика та же — keyCode + modifiers).
    var asFocusHotkey: FocusHotkey {
        .custom(keyCode: keyCode, modifiers: modifiers)
    }

    var serialized: String {
        switch self {
        case .preset(let p):
            return "preset:\(p.rawValue)"
        case .custom(let kc, let mods):
            return "custom:\(kc):\(mods)"
        }
    }

    static func deserialize(_ raw: String) -> MenubarHotkey? {
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

    static let `default`: MenubarHotkey = .preset(.ctrlShiftB)
}
