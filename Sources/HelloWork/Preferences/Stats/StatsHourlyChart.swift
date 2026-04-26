import SwiftUI

struct StatsHourlyChart: View {
    /// 24 значения, по часам.
    let hours: [Int]
    /// Текущий час, чтобы подсветить (0..23). nil — не подсвечиваем.
    let currentHour: Int?

    private var maxValue: Int { max(hours.max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { h in
                    let v = hours.indices.contains(h) ? hours[h] : 0
                    let isCurrent = (h == currentHour)
                    let height = CGFloat(v) / CGFloat(maxValue)
                    GeometryReader { geo in
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(barColor(value: v, isCurrent: isCurrent))
                                .frame(height: max(2, geo.size.height * height))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)

            HStack(spacing: 0) {
                ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                    Text("\(h % 24)")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: h == 0 ? .leading : (h == 24 ? .trailing : .center))
                }
            }
        }
    }

    private func barColor(value: Int, isCurrent: Bool) -> Color {
        if value == 0 {
            return Theme.surface
        }
        if isCurrent {
            return Theme.accent
        }
        return Theme.accent.opacity(0.55)
    }
}
