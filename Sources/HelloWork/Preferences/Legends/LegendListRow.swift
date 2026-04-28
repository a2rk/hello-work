import SwiftUI

/// Compact list-mode row. Avatar small + name + tags inline + intensity dots в углу.
struct LegendListRow: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    let legend: Legend
    let onTap: () -> Void

    @State private var hovered: Bool = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                LegendAvatar(legend: legend, size: 32, language: state.language)

                VStack(alignment: .leading, spacing: 2) {
                    Text(localizedName)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    HStack(spacing: 6) {
                        Text(legend.yearsOfLife)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                        if let primary = legend.tags.first {
                            Text("·").foregroundColor(Theme.textTertiary).font(.system(size: 10))
                            Text(primary.replacingOccurrences(of: "_", with: " "))
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                }

                Spacer(minLength: 8)
                intensityDots
                favoriteButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(hovered ? 0.06 : 0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
    }

    private var intensityDots: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= legend.intensity ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: 4, height: 4)
            }
        }
    }

    private var favoriteButton: some View {
        LegendFavoriteStar(state: state, legendId: legend.id, size: 12, background: nil)
    }

    private var localizedName: String {
        switch state.language {
        case .ru:                  return legend.name.ru
        case .en, .zh, .system:    return legend.name.en
        }
    }
}
