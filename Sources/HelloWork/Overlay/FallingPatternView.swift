import SwiftUI

/// Падающие streak'и + точки, анимированные в Canvas. Порт CSS radial-gradient
/// паттерна на SwiftUI. 12 «полос» с разными размерами тайла и скоростями —
/// дают эффект параллакса.
struct FallingPatternView: View {
    let elementColor: Color

    private struct Tile {
        let width: Double
        let height: Double
        let xOffset: Double   // фазовое смещение по X
        let speed: Double     // px/s
        let phase: Double     // фазовое смещение по Y
    }

    private static let tiles: [Tile] = [
        Tile(width: 300, height: 235, xOffset:   0, speed:  62, phase:   0),
        Tile(width: 300, height: 252, xOffset:  25, speed:  30, phase:  50),
        Tile(width: 300, height: 150, xOffset:  50, speed: 110, phase:  30),
        Tile(width: 300, height: 253, xOffset:  75, speed:  32, phase: 100),
        Tile(width: 300, height: 204, xOffset: 100, speed:  76, phase:  60),
        Tile(width: 300, height: 134, xOffset: 125, speed:  90, phase:  80),
        Tile(width: 300, height: 179, xOffset: 150, speed:  68, phase: 110),
        Tile(width: 300, height: 299, xOffset: 175, speed:  26, phase: 130),
        Tile(width: 300, height: 215, xOffset: 200, speed:  72, phase: 150),
        Tile(width: 300, height: 281, xOffset: 225, speed:  34, phase: 170),
        Tile(width: 300, height: 158, xOffset: 250, speed: 100, phase: 190),
        Tile(width: 300, height: 210, xOffset: 275, speed:  56, phase: 210),
    ]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            Canvas(rendersAsynchronously: true) { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for tile in Self.tiles {
                    drawTile(tile, ctx: &ctx, size: size, time: t)
                }
            }
        }
    }

    private func drawTile(_ tile: Tile, ctx: inout GraphicsContext, size: CGSize, time: Double) {
        // Вертикальный сдвиг с зацикливанием по высоте тайла
        let yShift = (time * tile.speed + tile.phase).truncatingRemainder(dividingBy: tile.height)

        // Тайл повторяется и по X, и по Y. Начинаем с -height чтобы не было
        // «дыры» сверху на сдвиге.
        var y = yShift - tile.height
        while y < size.height {
            // Горизонтальное смещение фазой xOffset
            var x = (tile.xOffset).truncatingRemainder(dividingBy: tile.width) - tile.width
            while x < size.width {
                // Левый streak (4×100 эллипс), частично уходящий за край тайла
                let leftRect = CGRect(
                    x: x - 2,
                    y: y + tile.height - 100,
                    width: 4,
                    height: 100
                )
                ctx.fill(
                    Path(ellipseIn: leftRect),
                    with: .color(elementColor.opacity(0.55))
                )

                // Правый streak
                let rightRect = CGRect(
                    x: x + tile.width - 2,
                    y: y + tile.height - 100,
                    width: 4,
                    height: 100
                )
                ctx.fill(
                    Path(ellipseIn: rightRect),
                    with: .color(elementColor.opacity(0.55))
                )

                // Центральная точка-вспышка
                let dotRect = CGRect(
                    x: x + tile.width / 2 - 1.5,
                    y: y + tile.height / 2 - 1.5,
                    width: 3,
                    height: 3
                )
                ctx.fill(
                    Path(ellipseIn: dotRect),
                    with: .color(elementColor.opacity(0.85))
                )

                x += tile.width
            }
            y += tile.height
        }
    }
}
