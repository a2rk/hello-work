import SwiftUI
import AppKit

/// Концентрические кольца — по кольцу на приложение. Слот = arc-сектор цвета приложения,
/// в центре сектора — реальная иконка app (если sector ≥ 30 минут).
/// Внешнее кольцо — самое первое приложение, дальше радиально внутрь.
struct CombinedRingChart: View {
    @Environment(\.t) var t
    let apps: [ManagedApp]
    let now: Date
    let onAppTap: (String) -> Void

    private let totalDiameter: CGFloat = 380
    private let outerInset: CGFloat = 14
    private let ringWidth: CGFloat = 32
    private let ringGap: CGFloat = 4

    var body: some View {
        ZStack {
            // Часовые риски.
            HourTicks(diameter: totalDiameter, inset: outerInset - 4)

            ForEach(Array(apps.enumerated()), id: \.element.bundleID) { idx, app in
                ringForApp(app, ringIndex: idx)
            }

            // Центр — текущий час крупно.
            centerLabel

            // Стрелка-указатель «сейчас».
            ClockHand(angle: angleForNow(), length: totalDiameter / 2 - outerInset)
        }
        .frame(width: totalDiameter, height: totalDiameter)
    }

    // MARK: - Ring per app

    @ViewBuilder
    private func ringForApp(_ app: ManagedApp, ringIndex: Int) -> some View {
        let color = AppPalette.color(for: app.bundleID)
        let outer = totalDiameter / 2 - outerInset - CGFloat(ringIndex) * (ringWidth + ringGap)
        let inner = outer - ringWidth

        ZStack {
            // Тёмный track ring (фон) — annulus через eoFill.
            RingTrack(outer: outer, inner: inner)
                .fill(Color.white.opacity(0.04), style: FillStyle(eoFill: true))

            // Сектор'ы по слотам.
            ForEach(app.slots) { slot in
                SlotSector(slot: slot, outer: outer, inner: inner)
                    .fill(color.opacity(0.85))
            }

            // Иконки в центрах секторов.
            ForEach(app.slots) { slot in
                if slot.lengthMinutes >= 30 {
                    iconOverlay(for: app, slot: slot, outer: outer, inner: inner)
                }
            }
        }
        .onTapGesture { onAppTap(app.bundleID) }
    }

    private func iconOverlay(for app: ManagedApp, slot: Slot, outer: CGFloat, inner: CGFloat) -> some View {
        let midMinute = (slot.startMinutes + slot.endMinutes) / 2
        let angle = angleForMinute(midMinute)
        let radius = (outer + inner) / 2
        let x = cos(angle) * radius
        let y = sin(angle) * radius

        return Image(nsImage: app.icon)
            .resizable()
            .interpolation(.high)
            .frame(width: 18, height: 18)
            .background(
                Circle().fill(Color.white.opacity(0.9))
            )
            .overlay(
                Circle().stroke(Color.black.opacity(0.10), lineWidth: 0.5)
            )
            .frame(width: 22, height: 22)
            .offset(x: x, y: y)
    }

    // MARK: - Center

    private var centerLabel: some View {
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)

        return VStack(spacing: 2) {
            Text(String(format: "%02d:%02d", h, m))
                .font(.system(size: 28, weight: .semibold))
                .foregroundColor(.white)
                .monospacedDigit()
            Text(t.combinedAppCount(apps.count).uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(1.4)
                .foregroundColor(Theme.textTertiary)
        }
    }

    // MARK: - Geometry helpers

    /// 0 минут наверху (12 часов), идём по часовой. SwiftUI angles: 0 = right, π/2 = down.
    /// Чтобы 0 был сверху и шло по часовой → angle = -π/2 + minute/1440 * 2π.
    private func angleForMinute(_ minutes: Int) -> CGFloat {
        let m = CGFloat(minutes % minutesInDay)
        return -.pi / 2 + (m / CGFloat(minutesInDay)) * (2 * .pi)
    }

    private func angleForNow() -> CGFloat {
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        return angleForMinute(h * 60 + m)
    }
}

// MARK: - Shapes

/// Полное кольцо (annulus).
private struct RingTrack: Shape {
    let outer: CGFloat
    let inner: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        p.addEllipse(in: CGRect(x: center.x - outer, y: center.y - outer,
                                width: outer * 2, height: outer * 2))
        p.addEllipse(in: CGRect(x: center.x - inner, y: center.y - inner,
                                width: inner * 2, height: inner * 2))
        return p.normalized(eoFill: true)
    }
}

private extension Path {
    /// Helper: возвращает path "as is" — Shape API использует .evenOdd через .fill(_, style:).
    func normalized(eoFill: Bool) -> Path { self }
}

/// Arc-сектор для слота — дуга с заданными outer/inner радиусами.
private struct SlotSector: Shape {
    let slot: Slot
    let outer: CGFloat
    let inner: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Угол: 0 минут = -π/2 (top), идём по часовой (+ к углу).
        let startAngle = Angle.radians(Double(-Double.pi / 2 + Double(slot.startMinutes) / Double(minutesInDay) * 2 * .pi))
        let endAngle = Angle.radians(Double(-Double.pi / 2 + Double(slot.endMinutes) / Double(minutesInDay) * 2 * .pi))

        // Внешняя дуга — по часовой (clockwise = false в SwiftUI = по часовой в стандартной координатной системе с Y-вниз).
        p.addArc(center: center, radius: outer, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        // Линия к внутренней дуге.
        let endInner = CGPoint(
            x: center.x + cos(endAngle.radians) * inner,
            y: center.y + sin(endAngle.radians) * inner
        )
        p.addLine(to: endInner)
        // Внутренняя дуга — обратно.
        p.addArc(center: center, radius: inner, startAngle: endAngle, endAngle: startAngle, clockwise: true)
        p.closeSubpath()
        return p
    }
}

// MARK: - Hour ticks

private struct HourTicks: View {
    let diameter: CGFloat
    let inset: CGFloat

    var body: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { hour in
                tick(at: hour)
            }
        }
        .frame(width: diameter, height: diameter)
    }

    private func tick(at hour: Int) -> some View {
        let isMajor = hour % 6 == 0
        let length: CGFloat = isMajor ? 8 : 4
        let radius = diameter / 2 - inset
        let angle = -.pi / 2 + CGFloat(hour) / 24 * 2 * .pi

        return Path { p in
            let inner = CGPoint(
                x: cos(angle) * (radius - length),
                y: sin(angle) * (radius - length)
            )
            let outer = CGPoint(
                x: cos(angle) * radius,
                y: sin(angle) * radius
            )
            p.move(to: inner)
            p.addLine(to: outer)
        }
        .stroke(
            isMajor ? Theme.textSecondary : Theme.textTertiary.opacity(0.5),
            lineWidth: isMajor ? 1.2 : 0.6
        )
        .overlay(
            isMajor ? hourLabel(hour: hour, angle: angle, radius: radius) : nil
        )
    }

    @ViewBuilder
    private func hourLabel(hour: Int, angle: CGFloat, radius: CGFloat) -> some View {
        let labelRadius = radius - 18
        let x = cos(angle) * labelRadius
        let y = sin(angle) * labelRadius
        Text("\(hour)")
            .font(.system(size: 9, weight: .medium))
            .foregroundColor(Theme.textTertiary)
            .monospacedDigit()
            .offset(x: x, y: y)
    }
}

// MARK: - Clock hand

private struct ClockHand: View {
    let angle: CGFloat
    let length: CGFloat

    var body: some View {
        Path { p in
            p.move(to: .zero)
            p.addLine(to: CGPoint(
                x: cos(angle) * length,
                y: sin(angle) * length
            ))
        }
        .stroke(Theme.accent.opacity(0.85), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
    }
}

