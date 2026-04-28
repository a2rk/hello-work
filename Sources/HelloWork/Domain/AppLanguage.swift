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
        switch resolveSystemLanguage() {
        case .ru: return .ru
        case .zh: return .zh
        case .en, .system: return .en
        }
    }

    /// Резолвит .system → конкретный AppLanguage по primary system locale.
    /// Используется и в L10n.resolveSystem (для UI Translation), и в
    /// LegendLocalized (для fallback решения по контенту легенд).
    static func resolveSystemLanguage() -> AppLanguage {
        let preferred = Locale.preferredLanguages.first ?? "en"
        let code = Locale(identifier: preferred).language.languageCode?.identifier ?? "en"
        switch code {
        case "ru": return .ru
        case "zh": return .zh
        default:   return .en
        }
    }

    /// Sanity-check всех локалей на пустые строки и placeholder'ы. Вызывается
    /// в DEBUG-сборке при старте; в release — no-op. Падает не ассертом,
    /// а через `devlog("i18n", ...)` чтобы было видно в Diagnostics-tab.
    static func validateAll() {
        #if DEBUG
        let placeholders: Set<String> = ["TODO", "translate me", "FIXME", "TBD"]
        for lang: Translation in [.en, .ru, .zh] {
            let mirror = Mirror(reflecting: lang)
            for child in mirror.children {
                guard let label = child.label else { continue }
                if let s = child.value as? String {
                    if s.isEmpty {
                        devlog("i18n", "EMPTY \(label) in locale at \(child.label ?? "?")")
                    }
                    if placeholders.contains(s) {
                        devlog("i18n", "PLACEHOLDER \(label) — value '\(s)'")
                    }
                }
            }
        }
        #endif
    }
}
