import SwiftUI

/// Hero-карточка: пара "Попытки ↓" и "Фокус ↑" с разделителем посередине.
struct StatsHeroView: View {
    @Environment(\.t) var t
    let attempts: Int
    let blockedSeconds: Double
    let comparisonText: String?

    let focusSeconds: Double
    let focusSessions: Int

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            attemptsSide
                .frame(maxWidth: .infinity, alignment: .leading)

            Rectangle()
                .fill(Theme.surfaceStroke)
                .frame(width: 1)
                .padding(.vertical, 4)

            focusSide
                .padding(.leading, 24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Attempts side

    private var attemptsSide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t.statsHeroAttemptsLabel)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.danger.opacity(0.85))

            Text("\(attempts)")
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(t.statsAttempts(attempts))
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)

            if blockedSeconds > 0 {
                Text(t.statsLostFocus(StatsFormatters.duration(seconds: blockedSeconds, t: t)))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }

            if let cmp = comparisonText {
                Text(cmp)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - Focus side

    private var focusSide: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(t.statsHeroFocusLabel)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.accent.opacity(0.85))

            Text(focusBigValue)
                .font(.system(size: 56, weight: .semibold))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)

            Text(focusUnitLabel)
                .font(.system(size: 13))
                .foregroundColor(Theme.textSecondary)

            if focusSessions > 0 {
                Text(t.statsHeroFocusSessions(focusSessions))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
        }
    }

    /// Большой число — минуты или часы, в зависимости от длительности.
    private var focusBigValue: String {
        let total = max(0, Int(focusSeconds))
        if total >= 3600 {
            let h = Double(total) / 3600.0
            return String(format: "%.1f", h)
        }
        return "\(total / 60)"
    }

    private var focusUnitLabel: String {
        let total = max(0, Int(focusSeconds))
        if total >= 3600 { return t.statsHeroFocusHours }
        return t.statsHeroFocusMinutes
    }
}
