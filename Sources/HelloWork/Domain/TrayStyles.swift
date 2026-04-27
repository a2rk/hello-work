import Foundation

/// Стиль главной menubar-иконки Hello work.
enum StatusIconStyle: String, CaseIterable, Codable, Identifiable {
    case solid, outline
    var id: String { rawValue }
}

/// Стиль chevron-разделителя menubar-hider'а.
enum HiderChevronStyle: String, CaseIterable, Codable, Identifiable {
    case chevron      // chevron.left.2
    case circle       // circle.fill (компактная точка)
    case minus        // minus (тонкая линия)
    var id: String { rawValue }

    var collapsedSymbol: String {
        switch self {
        case .chevron: return "chevron.left.2"
        case .circle:  return "circle.fill"
        case .minus:   return "minus"
        }
    }

    var expandedSymbol: String {
        switch self {
        case .chevron: return "chevron.right.2"
        case .circle:  return "circle"
        case .minus:   return "minus"
        }
    }
}
