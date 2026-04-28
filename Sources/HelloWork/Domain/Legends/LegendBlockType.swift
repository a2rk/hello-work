import Foundation
import SwiftUI

/// Тип блока в 24-часовом расписании легенды.
/// Закрытое множество — каждый имеет свой цвет в ring chart.
/// Forward-compat: неизвестные строки попадают в `.unknown(raw)`.
enum LegendBlockType: Hashable {
    case sleep
    case morningRoutine
    case deepWork
    case comms
    case mealAndRead
    case leisureAndReflection
    case unknown(String)

    /// Все известные кейсы, для legend-вью под рингом.
    static let known: [LegendBlockType] = [
        .sleep, .morningRoutine, .deepWork, .comms, .mealAndRead, .leisureAndReflection
    ]

    /// Стабильный snake_case ключ как в JSON.
    var rawKey: String {
        switch self {
        case .sleep:                  return "sleep"
        case .morningRoutine:         return "morning_routine"
        case .deepWork:               return "deep_work"
        case .comms:                  return "comms"
        case .mealAndRead:            return "meal_and_read"
        case .leisureAndReflection:   return "leisure_and_reflection"
        case .unknown(let raw):       return raw
        }
    }

    init(rawKey: String) {
        switch rawKey {
        case "sleep":                  self = .sleep
        case "morning_routine":        self = .morningRoutine
        case "deep_work":              self = .deepWork
        case "comms":                  self = .comms
        case "meal_and_read":          self = .mealAndRead
        case "leisure_and_reflection": self = .leisureAndReflection
        default:                       self = .unknown(rawKey)
        }
    }
}

extension LegendBlockType: Codable {
    init(from decoder: Decoder) throws {
        let raw = try decoder.singleValueContainer().decode(String.self)
        self.init(rawKey: raw)
    }
    func encode(to encoder: Encoder) throws {
        var c = encoder.singleValueContainer()
        try c.encode(rawKey)
    }
}

extension LegendBlockType {
    /// Цвет арки в LegendRingChart и dot'а в block-type legend (TASK-L41/L43).
    var color: Color {
        switch self {
        case .sleep:
            return Color(red: 0.20, green: 0.22, blue: 0.32)
        case .morningRoutine:
            return Color(red: 1.00, green: 0.78, blue: 0.35)
        case .deepWork:
            return Theme.accent
        case .comms:
            return Color(red: 0.95, green: 0.55, blue: 0.30)
        case .mealAndRead:
            return Color(red: 0.40, green: 0.75, blue: 0.85)
        case .leisureAndReflection:
            return Color(red: 0.70, green: 0.55, blue: 0.95)
        case .unknown:
            return Color.white.opacity(0.25)
        }
    }
}
