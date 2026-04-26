import SwiftUI

struct StatsMethodGrid: View {
    @Environment(\.t) var t
    let stat: DailyStat

    private var cells: [(label: String, value: Int)] {
        [
            (t.statsClicks, stat.taps + stat.secondaryTaps),
            (t.statsScrolls, stat.scrollSwipes),
            (t.statsKeys, stat.keystrokes),
            (t.statsPeeks, stat.peeks)
        ]
    }

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<cells.count, id: \.self) { i in
                cell(label: cells[i].label, value: cells[i].value)
            }
        }
    }

    private func cell(label: String, value: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(value)")
                .font(.system(size: 28, weight: .semibold))
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
