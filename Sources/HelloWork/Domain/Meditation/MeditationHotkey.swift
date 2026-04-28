import Foundation
import AppKit
import Carbon.HIToolbox

/// Хоткей для запуска meditation-сессии. Зеркало `FocusHotkey` /
/// `MenubarHotkey`. По умолчанию `⌃⌥M`. Не пересекается с `⌃⇧B` (menubar)
/// и `⌃⌥F` (focus).
enum MeditationHotkey: Codable, Equatable, Hashable {
    case preset(Preset)
    case custom(keyCode: UInt32, modifiers: UInt32)

    enum Preset: String, CaseIterable, Codable {
        case ctrlOptM
        case f17
        case hyperM         // ⌃⌥⌘M

        var keyCode: UInt32 {
            switch self {
            case .ctrlOptM:  return UInt32(kVK_ANSI_M)
            case .f17:       return UInt32(kVK_F17)
            case .hyperM:    return UInt32(kVK_ANSI_M)
            }
        }

        var modifiers: UInt32 {
            switch self {
            case .ctrlOptM:  return UInt32(controlKey | optionKey)
            case .f17:       return 0
            case .hyperM:    return UInt32(controlKey | optionKey | cmdKey)
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

    /// Адаптер для HotkeyManager (он принимает FocusHotkey).
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

    static func deserialize(_ raw: String) -> MeditationHotkey? {
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

    static let `default`: MeditationHotkey = .preset(.ctrlOptM)
}
