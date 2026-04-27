import SwiftUI
import AppKit

/// Горизонтальная 24-часовая лента: по строке на app, цветные прямоугольники где разрешено.
struct CombinedTimeline: View {
    let apps: [ManagedApp]
    let now: Date
    let onAppTap: (String) -> Void

    private let rowHeight: CGFloat = 22
    private let labelWidth: CGFloat = 130

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            hourGrid
            ForEach(apps) { app in
                row(for: app)
            }
        }
    }

    // MARK: - Hour grid (top)

    private var hourGrid: some View {
        HStack(spacing: 0) {
            Spacer().frame(width: labelWidth)
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    HStack(spacing: 0) {
                        ForEach([0, 6, 12, 18, 24], id: \.self) { h in
                            Text("\(h % 24)")
                                .font(.system(size: 9))
                                .foregroundColor(Theme.textTertiary)
                                .monospacedDigit()
                                .frame(maxWidth: .infinity, alignment: h == 0 ? .leading : (h == 24 ? .trailing : .center))
                        }
                    }
                    .frame(width: geo.size.width)
                }
            }
            .frame(height: 12)
        }
    }

    // MARK: - Row per app

    private func row(for app: ManagedApp) -> some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(nsImage: app.icon)
                    .resizable()
                    .interpolation(.high)
                    .frame(width: 16, height: 16)
                Text(app.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(width: labelWidth - 10, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .frame(height: rowHeight)

                    // Слоты
                    ForEach(app.slots) { slot in
                        slotRect(slot: slot, totalWidth: geo.size.width, app: app)
                    }

                    // Now-line
                    nowLine(totalWidth: geo.size.width)
                }
            }
            .frame(height: rowHeight)
        }
        .contentShape(Rectangle())
        .onTapGesture { onAppTap(app.bundleID) }
    }

    private func slotRect(slot: Slot, totalWidth: CGFloat, app: ManagedApp) -> some View {
        let color = AppPalette.color(for: app.bundleID)

        // Слот может wrapping через полночь — рисуем 1 или 2 прямоугольника.
        let segments: [(start: Int, end: Int)]
        if slot.endMinutes <= minutesInDay {
            segments = [(slot.startMinutes, slot.endMinutes)]
        } else {
            segments = [
                (slot.startMinutes, minutesInDay),
                (0, slot.endMinutes - minutesInDay)
            ]
        }

        return ForEach(0..<segments.count, id: \.self) { i in
            let s = segments[i]
            let xStart = CGFloat(s.start) / CGFloat(minutesInDay) * totalWidth
            let width = CGFloat(s.end - s.start) / CGFloat(minutesInDay) * totalWidth
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(color.opacity(0.85))
                .frame(width: max(2, width), height: rowHeight)
                .offset(x: xStart)
        }
    }

    private func nowLine(totalWidth: CGFloat) -> some View {
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        let cur = h * 60 + m
        let x = CGFloat(cur) / CGFloat(minutesInDay) * totalWidth

        return Rectangle()
            .fill(Theme.accent.opacity(0.95))
            .frame(width: 1.5, height: rowHeight + 4)
            .offset(x: x, y: -2)
    }
}
