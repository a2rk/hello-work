import SwiftUI

/// Detail view легенды: hero + bio + sources + ring chart + quotes + messenger windows.
/// TASK-L37 закладывает hero + back-button + fav-star skeleton.
/// L39/L41/L43/L45/L47 наполняют секции ниже hero.
struct LegendDetailView: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    let legend: Legend
    let onBack: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            backButton
            hero
            Spacer(minLength: 0)
        }
    }

    private var backButton: some View {
        Button(action: onBack) {
            HStack(spacing: 6) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                Text(t.sectionLegends)
                    .font(.system(size: 12))
            }
            .foregroundColor(Theme.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 18) {
            LegendAvatar(legend: legend, size: 96, language: state.language)

            VStack(alignment: .leading, spacing: 6) {
                Text(localizedName)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                Text(localizedFullName)
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
                metaRow
                intensityDots
            }

            Spacer(minLength: 8)
            favoriteStar
        }
        .padding(.bottom, 4)
    }

    private var metaRow: some View {
        HStack(spacing: 10) {
            metaItem(legend.yearsOfLife)
            metaDivider
            metaItem(legend.nationality)
            metaDivider
            metaItem(legend.field.replacingOccurrences(of: "_", with: " "))
        }
        .padding(.top, 2)
    }

    private func metaItem(_ s: String) -> some View {
        Text(s)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Theme.textTertiary)
    }

    private var metaDivider: some View {
        Circle()
            .fill(Theme.textTertiary.opacity(0.5))
            .frame(width: 2, height: 2)
    }

    private var intensityDots: some View {
        HStack(spacing: 3) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= legend.intensity ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.top, 4)
    }

    private var favoriteStar: some View {
        Button {
            state.toggleFavoriteLegend(legend.id)
        } label: {
            Image(systemName: state.isFavoriteLegend(legend.id) ? "star.fill" : "star")
                .font(.system(size: 16))
                .foregroundColor(state.isFavoriteLegend(legend.id) ? Theme.accent : Theme.textTertiary)
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.white.opacity(0.04)))
                .overlay(Circle().stroke(Theme.surfaceStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var localizedName: String {
        switch state.language {
        case .ru:                  return legend.name.ru
        case .en, .zh, .system:    return legend.name.en
        }
    }

    private var localizedFullName: String {
        switch state.language {
        case .ru:                  return legend.fullName.ru
        case .en, .zh, .system:    return legend.fullName.en
        }
    }
}
