import SwiftUI

/// 24-часовое кольцо для detail view легенды. Каждый блок — арка в цвете
/// LegendBlockType. 0:00 наверху (12-clock), время идёт по часовой.
/// Hour markers (0/6/12/18) — лёгкие тики снаружи кольца.
/// Центр: текущий time-of-day и название блока «сейчас» (по локальному часу).
struct LegendRingChart: View {
    @Environment(\.t) var t
    let legend: Legend
    /// Сторона квадратной области (ring растянется по min(side)).
    var size: CGFloat = 220
    /// Толщина кольца.
    var lineWidth: CGFloat = 22

    var body: some View {
        ZStack {
            ringTrack
            ForEach(arcs) { arc in
                arcShape(arc)
            }
            hourMarkers
            centerLabel
        }
        .frame(width: size, height: size)
    }

    // MARK: - Track (фон-кольцо)

    private var ringTrack: some View {
        Circle()
            .stroke(Color.white.opacity(0.04), lineWidth: lineWidth)
            .padding(lineWidth / 2)
    }

    // MARK: - Arcs

    private struct ArcSpec: Identifiable {
        let id = UUID()
        let startMin: Int
        let endMin: Int
        let color: Color
    }

    private var arcs: [ArcSpec] {
        legend.lifeSchedule.blocks.compactMap { b in
            guard let s = Self.minutes(b.start), let e = Self.minutes(b.end) else { return nil }
            // non-wrap: end <= s означает либо нулевой, либо некорректный диапазон
            guard e > s else { return nil }
            return ArcSpec(startMin: s, endMin: e, color: b.type.color)
        }
    }

    private func arcShape(_ a: ArcSpec) -> some View {
        let startDeg = Self.degrees(forMinute: a.startMin)
        let endDeg = Self.degrees(forMinute: a.endMin)
        return Circle()
            .trim(from: CGFloat(a.startMin) / 1440.0, to: CGFloat(a.endMin) / 1440.0)
            .stroke(a.color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .butt))
            .rotationEffect(.degrees(-90))
            .padding(lineWidth / 2)
            .help(arcTooltip(a, startDeg: startDeg, endDeg: endDeg))
    }

    private func arcTooltip(_ a: ArcSpec, startDeg: Double, endDeg: Double) -> String {
        "\(Self.hhmm(a.startMin))–\(Self.hhmm(a.endMin))"
    }

    // MARK: - Hour markers

    private var hourMarkers: some View {
        // Modifier-порядок: pre-rotate glyph на -angle → offset на радиус → outer rotate на +angle.
        // Тогда позиция = угол, а ориентация глифа = 0 (upright).
        ForEach([0, 6, 12, 18], id: \.self) { h in
            let angle = Double(h) / 24.0 * 360.0
            Text(String(format: "%02d", h))
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(Theme.textTertiary)
                .rotationEffect(.degrees(-angle))
                .offset(y: -(size / 2 - lineWidth - 8))
                .rotationEffect(.degrees(angle))
        }
    }

    // MARK: - Center

    private var centerLabel: some View {
        // TimelineView обновляет body раз в минуту — иначе HH:mm и currentBlock залипают
        // на момент открытия detail view.
        TimelineView(.periodic(from: .now, by: 60)) { ctx in
            VStack(spacing: 4) {
                Text(timeText(ctx.date))
                    .font(.system(size: 18, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                if let block = currentBlock(at: ctx.date) {
                    Text(blockTypeTitle(block.type))
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.5)
                        .foregroundColor(block.type.color)
                        .lineLimit(1)
                } else {
                    Text("—")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                }
            }
        }
    }

    private func timeText(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: date)
    }

    private func currentBlock(at date: Date) -> LegendBlock? {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        let nowMin = (comps.hour ?? 0) * 60 + (comps.minute ?? 0)
        return legend.lifeSchedule.blocks.first { b in
            guard let s = Self.minutes(b.start), let e = Self.minutes(b.end) else { return false }
            return nowMin >= s && nowMin < e
        }
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

    // MARK: - Helpers

    /// "HH:mm" → минут от полуночи. Возвращает nil если parse не удался.
    static func minutes(_ s: String) -> Int? {
        let parts = s.split(separator: ":")
        guard parts.count == 2,
              let h = Int(parts[0]), let m = Int(parts[1]),
              (0...24).contains(h), (0..<60).contains(m) else { return nil }
        let total = h * 60 + m
        return min(total, 1440)
    }

    /// Минута → угол в градусах от 12-clock (top), по часовой.
    static func degrees(forMinute m: Int) -> Double {
        Double(m) / 1440.0 * 360.0
    }

    static func hhmm(_ m: Int) -> String {
        String(format: "%02d:%02d", m / 60, m % 60)
    }
}
