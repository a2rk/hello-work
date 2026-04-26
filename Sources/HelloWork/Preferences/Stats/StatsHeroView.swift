import SwiftUI

struct StatsHeroView: View {
    @Environment(\.t) var t
    let attempts: Int
    let blockedSeconds: Double
    let comparisonText: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(attempts)")
                .font(.system(size: 64, weight: .semibold, design: .default))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(t.statsAttempts(attempts))
                .font(.system(size: 14, weight: .regular))
                .foregroundColor(Theme.textSecondary)

            if blockedSeconds > 0 {
                Text(t.statsLostFocus(StatsFormatters.duration(seconds: blockedSeconds, t: t)))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }

            if let cmp = comparisonText {
                Text(cmp)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
