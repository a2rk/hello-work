import Foundation

enum SettingsTab: String, CaseIterable, Identifiable {
    case schedule, focus, tray, app, data
    var id: String { rawValue }

    func title(_ t: Translation) -> String {
        switch self {
        case .schedule: return t.settingsTabSchedule
        case .focus:    return t.settingsTabFocus
        case .tray:     return t.settingsTabTray
        case .app:      return t.settingsTabApp
        case .data:     return t.settingsTabData
        }
    }
}
