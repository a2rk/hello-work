import Foundation

/// Одна meditation-сессия. Создаётся при старте, фиксируется на stop.
/// `completedNaturally` отличает natural-finish (60 сек дошли) от ESC-abort
/// — это влияет на агрегацию в `MeditationStats.record(_:)`.
struct MeditationSession: Codable, Identifiable, Hashable {
    let id: UUID
    let startedAt: Date
    let plannedDuration: TimeInterval
    let completedDuration: TimeInterval
    let completedNaturally: Bool

    init(
        id: UUID = UUID(),
        startedAt: Date,
        plannedDuration: TimeInterval,
        completedDuration: TimeInterval,
        completedNaturally: Bool
    ) {
        self.id = id
        self.startedAt = startedAt
        self.plannedDuration = plannedDuration
        self.completedDuration = completedDuration
        self.completedNaturally = completedNaturally
    }
}
