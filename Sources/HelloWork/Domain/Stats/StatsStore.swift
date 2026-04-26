import Foundation

/// In-memory структура агрегатов: дата ("yyyy-MM-dd") → bundleID → DailyStat.
struct StatsStore: Codable, Equatable {
    var days: [String: [String: DailyStat]] = [:]

    /// Сколько дней максимум держим. ~13 месяцев — для heatmap 53×7.
    static let retentionDays = 400

    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func date(fromDayKey key: String) -> Date? {
        dayFormatter.date(from: key)
    }

    /// Срез по диапазону дат (включительно). Возвращает агрегат по всем приложениям.
    func aggregate(from start: Date, to end: Date) -> [String: DailyStat] {
        var result: [String: DailyStat] = [:]
        let cal = Calendar.current
        var cursor = cal.startOfDay(for: start)
        let last = cal.startOfDay(for: end)
        while cursor <= last {
            let key = Self.dayKey(cursor)
            if let day = days[key] {
                for (bid, stat) in day {
                    result[bid] = (result[bid] ?? DailyStat()) + stat
                }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: cursor) else { break }
            cursor = next
        }
        return result
    }

    /// Сумма за день (все приложения).
    func totalForDay(_ date: Date) -> DailyStat {
        let key = Self.dayKey(date)
        guard let day = days[key] else { return DailyStat() }
        return day.values.reduce(DailyStat(), +)
    }

    /// Сумма за один bundleID за день.
    func dayStat(_ date: Date, bundleID: String) -> DailyStat {
        days[Self.dayKey(date)]?[bundleID] ?? DailyStat()
    }

    /// Подрезаем хвост старше retentionDays относительно сегодня.
    mutating func prune(now: Date = Date()) {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -Self.retentionDays, to: cal.startOfDay(for: now)) else { return }
        let cutoffKey = Self.dayKey(cutoff)
        days = days.filter { $0.key >= cutoffKey }
    }

    /// Все дни в порядке возрастания.
    var sortedDayKeys: [String] {
        days.keys.sorted()
    }
}
