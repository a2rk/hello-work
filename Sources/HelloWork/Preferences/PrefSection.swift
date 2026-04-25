import Foundation

enum PrefSection: String, CaseIterable, Identifiable {
    case updates, settings, contacts, about
    var id: String { rawValue }

    func title(_ t: Translation) -> String {
        switch self {
        case .updates:  return t.sectionUpdates
        case .settings: return t.sectionSettings
        case .contacts: return t.sectionContacts
        case .about:    return t.sectionAbout
        }
    }

    var icon: String {
        switch self {
        case .updates:  return "arrow.down.circle.fill"
        case .settings: return "gearshape.fill"
        case .contacts: return "person.crop.circle.fill"
        case .about:    return "info.circle.fill"
        }
    }
}
