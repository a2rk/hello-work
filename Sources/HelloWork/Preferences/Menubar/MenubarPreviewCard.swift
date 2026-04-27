import SwiftUI
import AppKit

/// Светлая карточка-«дубль» menubar.
struct MenubarPreviewCard: View {
    let items: [MenubarItemsScanner.Item]
    /// Когда true — рисуем "после скрытия" (только Hello work + chevron).
    let isCollapsed: Bool

    /// SF symbol главной нашей иконки.
    private let mainSymbol = "h.square.fill"

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.92))
                .frame(height: 36)

            HStack(spacing: 0) {
                // Слева — наша иконка + chevron-разделитель.
                HStack(spacing: 6) {
                    Image(systemName: mainSymbol)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black.opacity(0.85))
                    Image(systemName: isCollapsed ? "chevron.left.2" : "chevron.right.2")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black.opacity(0.55))
                }
                .padding(.leading, 14)

                if isCollapsed {
                    // Иконки "за пределами экрана" — не показываем.
                    Spacer()
                } else {
                    HStack(spacing: 9) {
                        ForEach(items) { item in
                            iconView(for: item)
                        }
                    }
                    .padding(.leading, 14)
                    Spacer()
                }
            }
            .padding(.vertical, 6)
        }
    }

    @ViewBuilder
    private func iconView(for item: MenubarItemsScanner.Item) -> some View {
        if let icon = item.icon {
            Image(nsImage: icon)
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
                .help(item.name)
        } else {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.black.opacity(0.10))
                .frame(width: 18, height: 18)
                .help(item.name)
        }
    }
}
