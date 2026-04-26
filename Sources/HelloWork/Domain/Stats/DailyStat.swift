import Foundation

/// Агрегаты за один день для одного приложения. Никаких списков событий —
/// только счётчики, чтобы файл не разрастался.
struct DailyStat: Codable, Equatable {
    var taps: Int = 0
    var secondaryTaps: Int = 0
    var scrollSwipes: Int = 0
    var keystrokes: Int = 0
    var blockedSeconds: Double = 0   // суммарное время с overlay'ом поверх
    var peeks: Int = 0               // сессий "открыл-потыкал-ушёл"
    var graceUsedCount: Int = 0
    var graceUsedSeconds: Int = 0
    /// Распределение попыток (taps + secondaryTaps + scrollSwipes + keystrokes) по часам, 0..23.
    var hourlyAttempts: [Int] = Array(repeating: 0, count: 24)

    /// Всего попыток вмешательства — для hero-цифры и сортировок.
    var totalAttempts: Int {
        taps + secondaryTaps + scrollSwipes + keystrokes
    }

    init(
        taps: Int = 0,
        secondaryTaps: Int = 0,
        scrollSwipes: Int = 0,
        keystrokes: Int = 0,
        blockedSeconds: Double = 0,
        peeks: Int = 0,
        graceUsedCount: Int = 0,
        graceUsedSeconds: Int = 0,
        hourlyAttempts: [Int] = Array(repeating: 0, count: 24)
    ) {
        self.taps = taps
        self.secondaryTaps = secondaryTaps
        self.scrollSwipes = scrollSwipes
        self.keystrokes = keystrokes
        self.blockedSeconds = blockedSeconds
        self.peeks = peeks
        self.graceUsedCount = graceUsedCount
        self.graceUsedSeconds = graceUsedSeconds
        self.hourlyAttempts = hourlyAttempts.count == 24
            ? hourlyAttempts
            : Array(repeating: 0, count: 24)
    }

    /// Backward-совместимый decoder — все поля опциональны.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        taps = (try? c.decodeIfPresent(Int.self, forKey: .taps)) ?? 0
        secondaryTaps = (try? c.decodeIfPresent(Int.self, forKey: .secondaryTaps)) ?? 0
        scrollSwipes = (try? c.decodeIfPresent(Int.self, forKey: .scrollSwipes)) ?? 0
        keystrokes = (try? c.decodeIfPresent(Int.self, forKey: .keystrokes)) ?? 0
        blockedSeconds = (try? c.decodeIfPresent(Double.self, forKey: .blockedSeconds)) ?? 0
        peeks = (try? c.decodeIfPresent(Int.self, forKey: .peeks)) ?? 0
        graceUsedCount = (try? c.decodeIfPresent(Int.self, forKey: .graceUsedCount)) ?? 0
        graceUsedSeconds = (try? c.decodeIfPresent(Int.self, forKey: .graceUsedSeconds)) ?? 0
        let raw = (try? c.decodeIfPresent([Int].self, forKey: .hourlyAttempts)) ?? []
        hourlyAttempts = raw.count == 24 ? raw : Array(repeating: 0, count: 24)
    }

    static func + (lhs: DailyStat, rhs: DailyStat) -> DailyStat {
        var hours = Array(repeating: 0, count: 24)
        for i in 0..<24 { hours[i] = lhs.hourlyAttempts[i] + rhs.hourlyAttempts[i] }
        return DailyStat(
            taps: lhs.taps + rhs.taps,
            secondaryTaps: lhs.secondaryTaps + rhs.secondaryTaps,
            scrollSwipes: lhs.scrollSwipes + rhs.scrollSwipes,
            keystrokes: lhs.keystrokes + rhs.keystrokes,
            blockedSeconds: lhs.blockedSeconds + rhs.blockedSeconds,
            peeks: lhs.peeks + rhs.peeks,
            graceUsedCount: lhs.graceUsedCount + rhs.graceUsedCount,
            graceUsedSeconds: lhs.graceUsedSeconds + rhs.graceUsedSeconds,
            hourlyAttempts: hours
        )
    }
}
