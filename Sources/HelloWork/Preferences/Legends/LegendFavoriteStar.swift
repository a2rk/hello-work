import SwiftUI

/// Унифицированная кнопка-звёздочка для добавления легенды в избранное.
/// Используется в LegendCard / LegendListRow / LegendDetailView — sync через
/// AppState.isFavoriteLegend(id). Scale-pop animation на toggle.
struct LegendFavoriteStar: View {
    @ObservedObject var state: AppState
    let legendId: String
    /// Размер system image. Контейнер немного больше для hit-area.
    var size: CGFloat = 13
    /// Диаметр круглой подложки (если nil — без подложки).
    var background: CGFloat? = 24

    @State private var bumped: Bool = false

    private var isFav: Bool { state.isFavoriteLegend(legendId) }

    var body: some View {
        Button(action: handleTap) {
            content
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var content: some View {
        let icon = Image(systemName: isFav ? "star.fill" : "star")
            .font(.system(size: size))
            .foregroundColor(isFav ? Theme.accent : Theme.textTertiary)
            .scaleEffect(bumped ? 1.30 : 1.0)
            .animation(.spring(response: 0.22, dampingFraction: 0.55), value: bumped)

        if let bg = background {
            icon
                .frame(width: bg, height: bg)
                .background(Circle().fill(Color.white.opacity(0.04)))
        } else {
            icon.frame(width: size + 8, height: size + 8)
        }
    }

    private func handleTap() {
        state.toggleFavoriteLegend(legendId)
        bumped = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            bumped = false
        }
    }
}
