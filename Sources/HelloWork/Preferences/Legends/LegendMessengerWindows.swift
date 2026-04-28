import SwiftUI

/// Секция «Messenger windows» в detail view: общая описалка по подходу легенды
/// + список допустимых окон (time-range + work/personal pill + rationale).
/// Скрывается если allowedSlots пуст.
struct LegendMessengerWindows: View {
    @Environment(\.t) var t
    @ObservedObject var state: AppState
    let legend: Legend

    var body: some View {
        if !legend.blockSchedule.allowedSlots.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                header
                description
                slotsList
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Text(t.legendsDetailMessengerWindows)
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.2)
                .foregroundColor(Theme.textTertiary)
            Spacer()
            Text(totalLabel)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(Theme.textSecondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Capsule().fill(Color.white.opacity(0.04)))
                .overlay(Capsule().stroke(Theme.surfaceStroke, lineWidth: 1))
        }
    }

    private var description: some View {
        Text(localizedDescription)
            .font(.system(size: 12))
            .foregroundColor(.white.opacity(0.85))
            .lineSpacing(3)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var slotsList: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(sortedSlots) { slot in
                slotRow(slot)
            }
        }
    }

    /// JSON-данные не гарантируют хронологический порядок (см. stephenson-neal).
    /// Сортируем по start, чтобы порядок UI был предсказуемым.
    private var sortedSlots: [LegendAllowedSlot] {
        legend.blockSchedule.allowedSlots.sorted { a, b in
            let am = LegendRingChart.minutes(a.start) ?? Int.max
            let bm = LegendRingChart.minutes(b.start) ?? Int.max
            return am < bm
        }
    }

    private func slotRow(_ slot: LegendAllowedSlot) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text("\(slot.start) – \(slot.end)")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundColor(.white)
                ForEach(slot.appliesTo, id: \.self) { applies in
                    appliesPill(applies)
                }
                Spacer()
                Text(durationLabel(slot))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textTertiary)
            }
            Text(localizedRationale(slot))
                .font(.system(size: 11))
                .foregroundColor(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.white.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Theme.surfaceStroke, lineWidth: 1)
        )
    }

    private func appliesPill(_ applies: String) -> some View {
        let title: String
        let color: Color
        switch applies {
        case "work_messengers":
            title = t.legendsApplyAppCategoryWork
            color = Theme.accent
        case "personal_messengers":
            title = t.legendsApplyAppCategoryPersonal
            color = Color(red: 0.70, green: 0.55, blue: 0.95)
        default:
            title = applies.replacingOccurrences(of: "_", with: " ")
            color = Theme.textSecondary
        }
        return Text(title)
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.12)))
            .overlay(Capsule().stroke(color.opacity(0.40), lineWidth: 1))
    }

    private func durationLabel(_ slot: LegendAllowedSlot) -> String {
        guard let s = LegendRingChart.minutes(slot.start),
              let e = LegendRingChart.minutes(slot.end),
              e > s else { return "" }
        let mins = e - s
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private var totalLabel: String {
        let mins = legend.blockSchedule.totalAllowedMinutes
        let h = mins / 60
        let m = mins % 60
        if h == 0 { return "\(m)m" }
        if m == 0 { return "\(h)h" }
        return "\(h)h \(m)m"
    }

    private var localizedDescription: String {
        LegendLocalized.text(legend.blockSchedule.description, in: state.language)
    }

    private func localizedRationale(_ slot: LegendAllowedSlot) -> String {
        LegendLocalized.text(slot.rationale, in: state.language)
    }
}
