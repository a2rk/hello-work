import SwiftUI

/// Grid-mode карточка легенды. Поддерживает два размера: .small (1×1 в сетке)
/// и .large (2×2 — featured). Click → opens detail. Hover scale 1.02 + spring.
struct LegendCard: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    let legend: Legend
    /// Index в ленте — используется для stagger-задержки fade-in при appear.
    var index: Int = 0
    var size: Size = .small
    let onTap: () -> Void

    enum Size {
        case small, large

        var avatarSize: CGFloat {
            switch self {
            case .small: return 44
            case .large: return 80
            }
        }
        var nameFontSize: CGFloat {
            switch self {
            case .small: return 14
            case .large: return 22
            }
        }
        var yearsFontSize: CGFloat {
            switch self {
            case .small: return 11
            case .large: return 13
            }
        }
        var padding: CGFloat {
            switch self {
            case .small: return 14
            case .large: return 22
            }
        }
        var minHeight: CGFloat {
            switch self {
            case .small: return 170
            case .large: return 352
            }
        }
        var bioLines: Int? {
            switch self {
            case .small: return nil   // не показываем bio
            case .large: return 4
            }
        }
        var dotSize: CGFloat {
            switch self {
            case .small: return 5
            case .large: return 7
            }
        }
    }

    @State private var hovered: Bool = false
    @State private var appeared: Bool = false

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: size == .large ? 14 : 10) {
                topRow
                nameBlock
                if size == .large, let lines = size.bioLines {
                    Text(localizedBio)
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                        .lineLimit(lines)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                bottomRow
            }
            .padding(size.padding)
            .frame(maxWidth: .infinity, minHeight: size.minHeight, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: size == .large ? 16 : 12, style: .continuous)
                    .fill(size == .large ? Color.white.opacity(0.06) : Color.white.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: size == .large ? 16 : 12, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
            .scaleEffect(hovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 6)
        .onAppear {
            let delay = index < 25 ? Double(index) * 0.02 : 0.0
            withAnimation(.easeOut(duration: 0.30).delay(delay)) {
                appeared = true
            }
        }
    }

    private var topRow: some View {
        HStack(alignment: .top) {
            LegendAvatar(legend: legend, size: size.avatarSize, language: state.language)
            Spacer()
            favoriteButton
        }
    }

    private var favoriteButton: some View {
        LegendFavoriteStar(state: state, legendId: legend.id,
                            size: size == .large ? 15 : 13,
                            background: size == .large ? 28 : 24)
    }

    private var nameBlock: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(localizedName)
                .font(.system(size: size.nameFontSize, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(size == .large ? 2 : 1)
            Text(legend.yearsOfLife)
                .font(.system(size: size.yearsFontSize))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private var bottomRow: some View {
        HStack(spacing: 8) {
            intensityDots
            if let primary = legend.tags.first {
                Text(primary.replacingOccurrences(of: "_", with: " "))
                    .font(.system(size: size == .large ? 11 : 10))
                    .foregroundColor(Theme.textTertiary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            Spacer()
        }
    }

    private var intensityDots: some View {
        HStack(spacing: size == .large ? 3 : 2) {
            ForEach(1...5, id: \.self) { i in
                Circle()
                    .fill(i <= legend.intensity ? Theme.accent : Theme.textTertiary.opacity(0.3))
                    .frame(width: size.dotSize, height: size.dotSize)
            }
        }
    }

    private var localizedName: String {
        LegendLocalized.text(legend.name, in: state.language)
    }

    private var localizedBio: String {
        LegendLocalized.text(legend.bio, in: state.language)
    }
}
