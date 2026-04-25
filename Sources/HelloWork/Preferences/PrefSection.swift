import Foundation

enum PrefSection: String, CaseIterable, Identifiable {
    case updates, settings, contacts, about
    var id: String { rawValue }
    var title: String {
        switch self {
        case .updates:  return "Обновления"
        case .settings: return "Настройки"
        case .contacts: return "Контакты"
        case .about:    return "О программе"
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
