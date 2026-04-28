import Foundation

/// Aggregated stats meditation-сессий. Persist'ится через `VersionedMeditationStats`.
/// `record(_:)` инкрементит счётчики; aborted сессии (ESC) тоже зачитываются
/// в total seconds — юзер всё-таки потратил время — но НЕ инкрементят count.
struct MeditationStats: Codable, Equatable {
    var sessionsCount: Int
    var totalSeconds: TimeInterval
    var lastSessionDate: Date?

    static let empty = MeditationStats(sessionsCount: 0, totalSeconds: 0, lastSessionDate: nil)

    mutating func record(_ session: MeditationSession) {
        totalSeconds += session.completedDuration
        lastSessionDate = session.startedAt
        if session.completedNaturally {
            sessionsCount += 1
        }
    }

    /// Округлённое значение для UI: «N минут».
    var totalMinutes: Int {
        Int((totalSeconds / 60.0).rounded())
    }
}

/// Versioned-wrapper для будущих миграций schema. Зеркало паттерна
/// `VersionedLegendsState` / `VersionedManagedAppsState`.
struct VersionedMeditationStats: Codable {
    let version: Int
    let stats: MeditationStats

    static let currentVersion = 1

    init(stats: MeditationStats) {
        self.version = Self.currentVersion
        self.stats = stats
    }
}
