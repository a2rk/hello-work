import Foundation

enum PrefSection: String, CaseIterable, Identifiable {
    case legends, stats, menubar, updates, settings, contacts, about
    var id: String { rawValue }

    func title(_ t: Translation) -> String {
        switch self {
        case .legends:  return t.sectionLegends
        case .stats:    return t.sectionStats
        case .menubar:  return t.sectionMenubar
        case .updates:  return t.sectionUpdates
        case .settings: return t.sectionSettings
        case .contacts: return t.sectionContacts
        case .about:    return t.sectionAbout
        }
    }

    var icon: String {
        switch self {
        case .legends:  return "books.vertical.fill"
        case .stats:    return "chart.bar.fill"
        case .menubar:  return "menubar.rectangle"
        case .updates:  return "arrow.down.circle.fill"
        case .settings: return "gearshape.fill"
        case .contacts: return "person.crop.circle.fill"
        case .about:    return "info.circle.fill"
        }
    }
}
