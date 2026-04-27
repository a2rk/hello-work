import SwiftUI

/// Отдельная строка «Доступы» в сайдбаре. Янтарная точка-индикатор когда
/// какое-то системное разрешение не выдано.
struct PermissionsSidebarRow: View {
    let title: String
    let isSelected: Bool
    let missing: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12, weight: .regular))
                    .frame(width: 16)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(textColor)
                Spacer()
                if missing {
                    Circle()
                        .fill(Theme.danger)
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
        if missing { return Theme.danger }
        return isSelected ? .white : Theme.textTertiary
    }

    private var textColor: Color {
        if missing && !isSelected { return .white }
        return isSelected ? .white : Theme.textSecondary
    }
}
