import Foundation

struct UpdateInfo: Codable, Identifiable, Equatable {
    let version: String
    let date: String?
    let customMessage: String?
    let main: String
    let points: [String]
    let dmgUrl: String?

    var id: String { version }
}
