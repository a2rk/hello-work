import Foundation

enum SidebarSelection: Hashable {
    case app(String)
    case section(PrefSection)
    case onboarding
    case combined
    case permissions
}
