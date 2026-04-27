import Foundation

/// Стиль главной menubar-иконки Hello work.
enum StatusIconStyle: String, CaseIterable, Codable, Identifiable {
    case solid, outline
    var id: String { rawValue }
}
