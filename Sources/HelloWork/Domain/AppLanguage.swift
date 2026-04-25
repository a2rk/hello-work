import Foundation

enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case system, en, ru, zh

    var id: String { rawValue }

    /// Имя языка на самом языке (English/Русский/中文) — чтобы пользователь
    /// мог найти свой даже если UI на чужом.
    func displayName(_ t: Translation) -> String {
        switch self {
        case .system: return t.languageSystem
        case .en:     return "English"
        case .ru:     return "Русский"
        case .zh:     return "中文"
        }
    }
}

enum L10n {
    static func resolved(_ language: AppLanguage) -> Translation {
        switch language {
        case .system: return resolveSystem()
        case .en:     return .en
        case .ru:     return .ru
        case .zh:     return .zh
        }
    }

    static func resolveSystem() -> Translation {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let code = Locale(identifier: preferred).language.languageCode?.identifier ?? "en"
        switch code {
        case "ru": return .ru
        case "zh": return .zh
        default:   return .en
        }
    }
}
