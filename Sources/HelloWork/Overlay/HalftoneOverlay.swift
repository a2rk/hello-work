import SwiftUI

/// «Halftone» сетка: почти сплошной тёмный фон с маленькими прозрачными
/// дырками каждые `dotSpacing` пикселей. Сквозь дырки видно слои ниже —
/// получается эффект «экрана» как в оригинальном CSS-паттерне.
struct HalftoneOverlay: View {
    let baseColor: Color
    var dotSpacing: Double = 8
    var dotRadius: Double = 1.4

    var body: some View {
        Canvas(rendersAsynchronously: true) { ctx, size in
            // Заливаем фон
            ctx.fill(
                Path(CGRect(origin: .zero, size: size)),
                with: .color(baseColor)
            )
            // Прорезаем «дырки» через destinationOut — фон становится прозрачным
            // в местах кружков.
            ctx.blendMode = .destinationOut
            for x in stride(from: dotSpacing / 2, through: size.width, by: dotSpacing) {
                for y in stride(from: dotSpacing / 2, through: size.height, by: dotSpacing) {
                    let r = dotRadius
                    ctx.fill(
                        Path(ellipseIn: CGRect(
                            x: x - r, y: y - r,
                            width: r * 2, height: r * 2
                        )),
                        with: .color(.black)
                    )
                }
            }
        }
    }
}
