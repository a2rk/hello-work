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
