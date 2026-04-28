import SwiftUI

/// Горизонтальный ряд под RingChart — для каждого встретившегося блок-типа:
/// цветной dot + локализованное название + total часов в сутках легенды.
struct LegendBlockTypeLegend: View {
    @Environment(\.t) var t
    let legend: Legend

    var body: some View {
        // ScrollView нужен на узких экранах — items могут не поместиться в одну строку.
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 14) {
                ForEach(items, id: \.key) { item in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(item.color)
                            .frame(width: 8, height: 8)
                        Text(item.title)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.white.opacity(0.85))
                        Text(item.totalLabel)
                            .font(.system(size: 10))
                            .foregroundColor(Theme.textTertiary)
                    }
                }
            }
            .padding(.vertical, 2)
        }
    }

    // MARK: - Items

    private struct Item {
        let key: String
        let title: String
        let color: Color
        let totalLabel: String
    }

    private var items: [Item] {
        // Группируем по rawKey — стабильно для unknown(_) тоже.
        var totals: [String: Int] = [:]
        var firstType: [String: LegendBlockType] = [:]
        for b in legend.lifeSchedule.blocks {
            guard let s = LegendRingChart.minutes(b.start),
                  let e = LegendRingChart.minutes(b.end),
                  e > s else { continue }
            let k = b.type.rawKey
            totals[k, default: 0] += (e - s)
            if firstType[k] == nil { firstType[k] = b.type }
        }
        // Стабильный порядок: known order по LegendBlockType.known + unknown в конце.
        var ordered: [Item] = []
        for kt in LegendBlockType.known {
            if let mins = totals[kt.rawKey] {
                ordered.append(Item(
                    key: kt.rawKey,
                    title: blockTypeTitle(kt),
                    color: kt.color,
                    totalLabel: formatTotal(mins)
                ))
            }
        }
        // Unknown'ы — алфавит.
        let unknownKeys = totals.keys
            .filter { k in !LegendBlockType.known.contains(where: { $0.rawKey == k }) }
            .sorted()
        for k in unknownKeys {
            let type = firstType[k] ?? .unknown(k)
            ordered.append(Item(
                key: k,
                title: blockTypeTitle(type),
                color: type.color,
                totalLabel: formatTotal(totals[k]!)
            ))
        }
        return ordered
    }

    private func formatTotal(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private func blockTypeTitle(_ type: LegendBlockType) -> String {
        switch type {
        case .sleep:                 return t.legendsBlockTypeSleep
        case .morningRoutine:        return t.legendsBlockTypeMorning
        case .deepWork:              return t.legendsBlockTypeDeep
        case .comms:                 return t.legendsBlockTypeComms
        case .mealAndRead:           return t.legendsBlockTypeMeal
        case .leisureAndReflection:  return t.legendsBlockTypeLeisure
        case .unknown(let raw):      return raw.replacingOccurrences(of: "_", with: " ")
        }
    }
}
