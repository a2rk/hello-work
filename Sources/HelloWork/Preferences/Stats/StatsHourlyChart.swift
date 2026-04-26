import SwiftUI

struct StatsHourlyChart: View {
    @Environment(\.t) var t
    /// 24 значения попыток по часам.
    let attemptsHours: [Int]
    /// 24 значения секунд фокуса по часам.
    let focusHours: [Double]
    /// Текущий час, чтобы подсветить (0..23). nil — не подсвечиваем.
    let currentHour: Int?

    private var maxAttempts: Int { max(attemptsHours.max() ?? 0, 1) }
    private var maxFocus: Double { max(focusHours.max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Двойной chart: попытки слева красным (вверх), фокус справа зелёным (вверх).
            // Apple-way: симметричное разделение по горизонтали в пределах одного бакета.
            HStack(alignment: .bottom, spacing: 3) {
                ForEach(0..<24, id: \.self) { h in
                    let attempts = attemptsHours.indices.contains(h) ? attemptsHours[h] : 0
                    let focus = focusHours.indices.contains(h) ? focusHours[h] : 0
                    let isCurrent = (h == currentHour)

                    GeometryReader { geo in
                        ZStack(alignment: .bottom) {
                            // Бар фокуса — основной (зелёный), за бар попыток (красный) — наложение.
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                if focus > 0 {
                                    let height = geo.size.height * CGFloat(focus / maxFocus)
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .fill(focusColor(isCurrent: isCurrent))
                                        .frame(height: max(2, height))
                                }
                            }
                            VStack(spacing: 0) {
                                Spacer(minLength: 0)
                                if attempts > 0 {
                                    let height = geo.size.height * CGFloat(Double(attempts) / Double(maxAttempts)) * 0.6
                                    // Бар попыток в правой половине внутри бакета — узкий поверх.
                                    HStack(spacing: 0) {
                                        Spacer(minLength: 0)
                                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                                            .fill(attemptsColor(isCurrent: isCurrent))
                                            .frame(width: max(2, geo.size.width * 0.45),
                                                   height: max(2, height))
                                    }
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 80)

            // Hour labels
            HStack(spacing: 0) {
                ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                    Text("\(h % 24)")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                        .monospacedDigit()
                        .frame(maxWidth: .infinity, alignment: h == 0 ? .leading : (h == 24 ? .trailing : .center))
                }
            }

            // Legend
            HStack(spacing: 14) {
                legendItem(color: Theme.accent, label: t.statsLegendFocus)
                legendItem(color: Theme.danger.opacity(0.7), label: t.statsLegendAttempts)
                Spacer()
            }
            .padding(.top, 2)
        }
    }

    private func focusColor(isCurrent: Bool) -> Color {
        isCurrent ? Theme.accent : Theme.accent.opacity(0.55)
    }

    private func attemptsColor(isCurrent: Bool) -> Color {
        isCurrent ? Theme.danger : Theme.danger.opacity(0.55)
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(color)
                .frame(width: 10, height: 10)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(Theme.textSecondary)
        }
    }
}
