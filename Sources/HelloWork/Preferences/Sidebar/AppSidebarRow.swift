import SwiftUI

struct AppSidebarRow: View {
    let app: ManagedApp
    let isSelected: Bool
    let isAllowedNow: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
                    .opacity(app.isArchived ? 0.45 : 1)
                Text(app.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(textColor)
                    .strikethrough(app.isArchived, color: Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 4)
                if !app.isArchived {
                    Circle()
                        .fill(isAllowedNow ? Theme.accent : Theme.danger)
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(isSelected ? Color.white.opacity(0.06) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private var textColor: Color {
        if app.isArchived { return Theme.textTertiary }
        return isSelected ? .white : Color.white.opacity(0.78)
    }
}
