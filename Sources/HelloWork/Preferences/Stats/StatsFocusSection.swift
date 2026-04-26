import SwiftUI
import AppKit

/// Карточка с focus-метриками: 4 числа + top-5 приложений, на которых фокусировался.
struct StatsFocusSection: View {
    @Environment(\.t) var t
    let total: DailyStat                              // под `__focus_total__`
    let perApp: [FocusAppRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                cell(value: "\(total.focusSessions)", label: t.statsFocusSessions)
                cell(value: StatsFormatters.duration(seconds: total.focusSeconds, t: t),
                     label: t.statsFocusTotal)
                cell(value: StatsFormatters.duration(seconds: total.focusLongestSeconds, t: t),
                     label: t.statsFocusLongest)
                cell(value: StatsFormatters.duration(seconds: averageSession, t: t),
                     label: t.statsFocusAverage)
            }

            if !perApp.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(t.statsFocusTopApps.uppercased())
                        .font(.system(size: 10, weight: .semibold))
                        .tracking(1.4)
                        .foregroundColor(Theme.textTertiary)
                        .padding(.top, 4)

                    VStack(spacing: 6) {
                        ForEach(perApp) { row in
                            FocusAppBar(row: row)
                        }
                    }
                }
            }
        }
    }

    private var averageSession: Double {
        guard total.focusSessions > 0 else { return 0 }
        return total.focusSeconds / Double(total.focusSessions)
    }

    private func cell(value: String, label: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value)
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(.white)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
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

/// Строка top-приложений по focus-времени: иконка → имя → bar → длительность → %.
struct FocusAppRow: Identifiable {
    let id: String          // bundleID
    let name: String
    let icon: NSImage?
    let seconds: Double
    let percent: Int
}

private struct FocusAppBar: View {
    @Environment(\.t) var t
    let row: FocusAppRow

    var body: some View {
        HStack(spacing: 10) {
            if let icon = row.icon {
                Image(nsImage: icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 18, height: 18)
            } else {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Theme.surface)
                    .frame(width: 18, height: 18)
            }

            Text(row.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(width: 160, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.surface)
                        .frame(height: 6)
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * CGFloat(row.percent) / 100.0, height: 6)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 18)

            Text(StatsFormatters.duration(seconds: row.seconds, t: t))
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .monospacedDigit()
                .frame(width: 80, alignment: .trailing)

            Text("\(row.percent)%")
                .font(.system(size: 12))
                .foregroundColor(Theme.textTertiary)
                .monospacedDigit()
                .frame(width: 44, alignment: .trailing)
        }
    }
}
