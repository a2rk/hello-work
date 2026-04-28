import SwiftUI

/// Зелёная точка с soft glow и breathing ring вокруг.
///
/// Breathing cycle (9 секунд, повторяется):
///   - Вдох (4s): ring диаметр 0 → 180pt (ease-in-out), opacity 0 → ~0.5
///   - Hold (3s): ring статичен на 180pt
///   - Выдох (2s): ring диаметр 180 → 0pt (ease-in), opacity → 0
///
/// Border ring толщина — 0.5pt (фиксирована); меняется только диаметр.
/// Это даёт интуитивное «вдох» (расширение) и «выдох» (сжатие) — как в
/// дыхательных упражнениях Apple Watch.
struct MeditationDotView: View {
    static let dotSize: CGFloat = 16
    static let glowRadius: CGFloat = 12
    static let ringMaxDiameter: CGFloat = 180
    static let ringLineWidth: CGFloat = 0.5
    static let ringPeakOpacity: Double = 0.55

    static let inhaleDuration: TimeInterval = 4.0
    static let holdDuration: TimeInterval = 3.0
    static let exhaleDuration: TimeInterval = 2.0
    static var cycleDuration: TimeInterval {
        inhaleDuration + holdDuration + exhaleDuration
    }

    @State private var ringDiameter: CGFloat = 0
    @State private var ringOpacity: Double = 0
    @State private var dotPulse: CGFloat = 1.0

    var body: some View {
        ZStack {
            // Breathing ring — снаружи точки.
            Circle()
                .strokeBorder(Theme.accent.opacity(ringOpacity), lineWidth: Self.ringLineWidth)
                .frame(width: ringDiameter, height: ringDiameter)

            // Сама точка с glow и лёгким pulse.
            Circle()
                .fill(Theme.accent)
                .frame(width: Self.dotSize, height: Self.dotSize)
                .shadow(color: Theme.accent.opacity(0.55), radius: Self.glowRadius)
                .scaleEffect(dotPulse)
        }
        .onAppear {
            startBreathing()
            startDotPulse()
        }
    }

    /// Запускает первый цикл и сам перевызывает себя через cycleDuration —
    /// бесконечный loop пока view жив.
    private func startBreathing() {
        // Вдох: 0 → 180, opacity 0 → 0.55, easeInOut натуральное «вдыхание».
        withAnimation(.easeInOut(duration: Self.inhaleDuration)) {
            ringDiameter = Self.ringMaxDiameter
            ringOpacity = Self.ringPeakOpacity
        }
        // Hold: ring статичен 3 секунды на peak.
        // Выдох: 180 → 0, opacity → 0, easeIn (быстрее в начале, медленнее в конце —
        // имитирует «отпускание»).
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.inhaleDuration + Self.holdDuration) {
            withAnimation(.easeIn(duration: Self.exhaleDuration)) {
                ringDiameter = 0
                ringOpacity = 0
            }
        }
        // Запускаем следующий цикл.
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.cycleDuration) {
            startBreathing()
        }
    }

    /// Лёгкий subtle pulse самой точки — чтобы она не выглядела статично
    /// между breathing-циклами. Независимый от ring loop.
    private func startDotPulse() {
        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
            dotPulse = 1.08
        }
    }
}
