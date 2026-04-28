import SwiftUI

/// Grid-mode карточка легенды. Click → opens detail. Hover scale 1.02 + spring.
struct LegendCard: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    let legend: Legend
    let onTap: () -> Void

    @State private var hovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                topRow
                nameBlock
                Spacer(minLength: 0)
                bottomRow
            }
            .padding(14)
            .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
            .scaleEffect(hovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            LegendAvatar(legend: legend, size: 44, language: state.language)
            Spacer()
            favoriteButton
        }
    }

    private var favoriteButton: some View {
        LegendFavoriteStar(state: state, legendId: legend.id, size: 13, background: 24)
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(localizedName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
            Text(legend.yearsOfLife)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 8) {
            intensityDots
            if let primary = legend.tags.first {
                Text(primary.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
    }

    private var intensityDots: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= legend.intensity ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 5, height: 5)
            }
        }
    }

    private var localizedName: String {
        switch state.language {
        case .ru:                  return legend.name.ru
        case .en, .zh, .system:    return legend.name.en
        }
    }
}
