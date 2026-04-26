import SwiftUI

struct StatsGraceCard: View {
    @Environment(\.t) var t
    let count: Int
    let totalSeconds: Int

    var body: some View {
        let mins = totalSeconds / 60
        let text = count == 0
            ? t.statsGraceNone
            : t.statsGraceLine(count, mins)

        Text(text)
            .font(.system(size: 13))
            .foregroundColor(Theme.textSecondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.03))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(Theme.surfaceStroke, lineWidth: 1)
            )
    }
}
