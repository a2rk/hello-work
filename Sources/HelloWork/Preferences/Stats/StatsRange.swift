import Foundation

enum StatsRange: String, CaseIterable, Identifiable {
    case today, week, month, year, all
    var id: String { rawValue }

    func title(_ t: Translation) -> String {
        switch self {
        case .today: return t.statsRangeToday
        case .week:  return t.statsRangeWeek
        case .month: return t.statsRangeMonth
        case .year:  return t.statsRangeYear
        case .all:   return t.statsRangeAll
        }
    }

    /// Граница периода — startOfDay(now - N) ... endOfDay(now).
    /// Для .all возвращаем 400 дней назад (под retention).
    func interval(now: Date = Date()) -> (start: Date, end: Date) {
        let cal = Calendar.current
        let endOfToday = cal.startOfDay(for: now)
        let days: Int
        switch self {
        case .today: days = 0
        case .week:  days = 6
        case .month: days = 29
        case .year:  days = 364
        case .all:   days = StatsStore.retentionDays - 1
        }
        let start = cal.date(byAdding: .day, value: -days, to: endOfToday) ?? endOfToday
        return (start, endOfToday)
    }
}
