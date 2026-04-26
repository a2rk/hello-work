import SwiftUI

struct StatsHeatmap: View {
    @Environment(\.t) var t
    /// 53 недели × 7 дней. Каждая ячейка: дата + количество попыток.
    /// Самая правая колонка — текущая неделя.
    let cells: [[HeatmapCell]]
    /// Максимум по периоду — для нормализации цвета.
    let maxValue: Int

    @State private var hovered: HeatmapCell?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 3) {
                ForEach(0..<cells.count, id: \.self) { week in
                    VStack(spacing: 3) {
                        ForEach(0..<7, id: \.self) { day in
                            let cell = cells[week][day]
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(color(for: cell))
                                .frame(width: 11, height: 11)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                                        .stroke(Theme.surfaceStroke, lineWidth: 0.5)
                                )
                                .help(tooltip(for: cell))
                                .onHover { inside in
                                    hovered = inside ? cell : nil
                                }
                        }
                    }
                }
            }

            HStack(spacing: 6) {
                Text(t.statsHeatmapLegendLess)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                ForEach(0..<5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(legendColor(step: i))
                        .frame(width: 11, height: 11)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(Theme.surfaceStroke, lineWidth: 0.5)
                        )
                }
                Text(t.statsHeatmapLegendMore)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
                Spacer()
                if let h = hovered {
                    Text(tooltip(for: h))
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary)
                }
            }
        }
    }

    private func color(for cell: HeatmapCell) -> Color {
        // Будущее: пусто
        if cell.isFuture { return Color.clear }
        if cell.value == 0 || maxValue == 0 { return Theme.surface }
        // Логарифмическая шкала по 5 ступеням.
        let ratio = log(Double(cell.value) + 1) / log(Double(maxValue) + 1)
        let step = min(4, max(0, Int(ratio * 4.99)))
        return legendColor(step: step)
    }

    private func legendColor(step: Int) -> Color {
        switch step {
        case 0: return Theme.surface
        case 1: return Theme.accent.opacity(0.20)
        case 2: return Theme.accent.opacity(0.40)
        case 3: return Theme.accent.opacity(0.65)
        default: return Theme.accent.opacity(0.95)
        }
    }

    private func tooltip(for cell: HeatmapCell) -> String {
        guard !cell.isFuture else { return "" }
        return t.statsHeatmapDay(cell.dateLabel, cell.value)
    }
}

struct HeatmapCell: Identifiable, Equatable {
    let id = UUID()
    let date: Date
    let dateLabel: String
    let value: Int
    let isFuture: Bool

    static func == (lhs: HeatmapCell, rhs: HeatmapCell) -> Bool {
        lhs.id == rhs.id
    }
}
