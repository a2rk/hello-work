import SwiftUI

/// Зелёная точка с soft glow и медитативным pulse (breathing 0.92↔1.08, 2с).
/// Position управляется извне через .position(_:).
struct MeditationDotView: View {
    /// Внутренний state pulse — animated через .repeatForever.
    @State private var pulseScale: CGFloat = 0.92

    static let dotSize: CGFloat = 16
    static let glowRadius: CGFloat = 12

    var body: some View {
        Circle()
            .fill(Theme.accent)
            .frame(width: Self.dotSize, height: Self.dotSize)
            .shadow(color: Theme.accent.opacity(0.55), radius: Self.glowRadius)
            .scaleEffect(pulseScale)
            .onAppear {
                // Pulse breathing: непрерывный «вдох-выдох» 2с цикл.
                // Стартует с 0.92, за секунду растёт до 1.08, ещё за секунду
                // обратно. Делает точку «живой», не статичной.
                withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                    pulseScale = 1.08
                }
            }
    }
}
