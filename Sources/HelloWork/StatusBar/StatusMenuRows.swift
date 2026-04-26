import SwiftUI
import AppKit

/// Глобальный тумблер сверху menubar — нативный SwiftUI Toggle вместо
/// плоской attributedTitle с цветной точкой.
struct ToggleMenuRow: View {
    @ObservedObject var state: AppState

    var body: some View {
        HStack(spacing: 0) {
            Text("Hello work")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            Spacer(minLength: 12)
            Toggle("", isOn: $state.enabled)
                .toggleStyle(.switch)
                .controlSize(.mini)
                .labelsHidden()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .frame(width: 240, height: 28)
    }
}

/// Строка приложения в menubar: иконка → имя → spacer → маленькая статус-точка.
/// Хайлайт по hover, клик прокидывается наружу.
struct AppMenuRow: View {
    let app: ManagedApp
    let isAllowed: Bool
    let onTap: () -> Void

    @State private var hovered = false

    var body: some View {
        HStack(spacing: 9) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 16, height: 16)
            Text(app.name)
                .font(.system(size: 13))
                .foregroundColor(hovered ? .white : .primary)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Circle()
                .fill(isAllowed ? Color.green : Color.red)
                .frame(width: 5, height: 5)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 4)
        .frame(width: 240, height: 26)
        .background(hovered ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovered = $0 }
        .onTapGesture { onTap() }
    }
}
