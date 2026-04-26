import Foundation

/// Форматирование "9 мин 24 с". Для коротких — только секунды.
enum StatsFormatters {
    static func duration(seconds: Double, t: Translation) -> String {
        let total = max(0, Int(seconds))
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return "\(h) \(t.unitH) \(m) \(t.unitMin)"
        }
        if m > 0 {
            return s > 0 ? "\(m) \(t.unitMin) \(s) \(t.unitSec)" : "\(m) \(t.unitMin)"
        }
        return "\(s) \(t.unitSec)"
    }

    static func date(_ date: Date, language: AppLanguage) -> String {
        let f = DateFormatter()
        switch language {
        case .ru:     f.locale = Locale(identifier: "ru_RU")
        case .zh:     f.locale = Locale(identifier: "zh_CN")
        case .en:     f.locale = Locale(identifier: "en_US")
        case .system: f.locale = Locale.current
        }
        f.setLocalizedDateFormatFromTemplate("dMMMM")
        return f.string(from: date)
    }
}
