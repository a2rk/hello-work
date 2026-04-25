import SwiftUI

struct SidebarItem: View {
    @Environment(\.t) var t
    let section: PrefSection
    let isSelected: Bool
    var showsBadge: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: section.icon)
                    .font(.system(size: 12, weight: .regular))
                    .frame(width: 16)
                    .foregroundColor(iconColor)
                Text(section.title(t))
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(textColor)
                Spacer()
                if showsBadge {
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 6, height: 6)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var iconColor: Color {
        if showsBadge { return Theme.accent }
        return isSelected ? .white : Theme.textTertiary
    }

    private var textColor: Color {
        if showsBadge && !isSelected { return .white }
        return isSelected ? .white : Theme.textSecondary
    }
}
