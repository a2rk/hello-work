import SwiftUI

/// Затемняющий canvas: чёрный фон 98% opacity на весь screen + (опционально)
/// зелёная точка + тонкая прогресс-линия снизу. Точка рисуется только на
/// primary screen (showDot=true для main window, false для secondaries).
struct MeditationCanvasView: View {
    let dotPosition: CGPoint?           // nil → точка не рисуется
    let progress: Double                 // 0..1, для нижней линии (если показ включён)
    let showProgressLine: Bool
    let dotOpacity: Double               // 0..1, для fade-in/out точки

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // 98% затемнение всего screen.
            Color.black.opacity(0.98)
                .ignoresSafeArea()

            // Точка — только если задана позиция (primary screen).
            if let pos = dotPosition {
                MeditationDotView()
                    .opacity(dotOpacity)
                    .position(pos)
                    .allowsHitTesting(false)
            }

            // Тонкая прогресс-линия по нижнему edge'у.
            if showProgressLine {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Theme.accent.opacity(0.40))
                        .frame(width: geo.size.width * CGFloat(progress), height: 2)
                }
                .frame(height: 2)
                .allowsHitTesting(false)
            }
        }
    }
}
