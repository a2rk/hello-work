import Foundation

struct Slot: Identifiable, Equatable {
    let id: UUID
    var startMinutes: Int   // [0, minutesInDay)
    var endMinutes: Int     // (startMinutes, startMinutes + minutesInDay]

    var wraps: Bool { endMinutes > minutesInDay }
    var lengthMinutes: Int { endMinutes - startMinutes }

    func contains(minute: Int) -> Bool {
        if minute >= startMinutes && minute < endMinutes { return true }
        if wraps && minute + minutesInDay >= startMinutes && minute + minutesInDay < endMinutes {
            return true
        }
        return false
    }
}
