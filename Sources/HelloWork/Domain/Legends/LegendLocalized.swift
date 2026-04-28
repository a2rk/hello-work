import Foundation

/// Helper для resolve'а LocalizedRuEn в текущем UI-языке.
/// Возвращает текст + флаг что fallback (en вместо нативного — для zh).
/// `.system` резолвится через L10n.resolveSystem() — если system locale не ru/en,
/// fallback на en (тоже флаг fallback).
enum LegendLocalized {
    /// Результат resolve.
    struct Resolved {
        let text: String
        /// true когда мы вернули .en потому что родного перевода нет
        /// (zh; system→non-ru/en). UI может показать «EN» badge.
        let isFallback: Bool
    }

    static func resolve(_ ru_en: LocalizedRuEn, in language: AppLanguage) -> Resolved {
        switch language {
        case .ru:
            return Resolved(text: ru_en.ru, isFallback: false)
        case .en:
            return Resolved(text: ru_en.en, isFallback: false)
        case .zh:
            return Resolved(text: ru_en.en, isFallback: true)
        case .system:
            // .system делегирует L10n.resolveSystemLanguage чтобы не дублировать
            // locale-detection. Recursive call даёт правильный fallback флаг.
            return resolve(ru_en, in: L10n.resolveSystemLanguage())
        }
    }

    /// Удобный shortcut когда fallback флаг не важен.
    static func text(_ ru_en: LocalizedRuEn, in language: AppLanguage) -> String {
        resolve(ru_en, in: language).text
    }
}
