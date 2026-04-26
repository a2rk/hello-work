import SwiftUI

/// Падающие капли «дождя». Каждая капля — независимая частица со своей
/// скоростью, длиной, начальной фазой и прозрачностью. Это даёт настоящий
/// rain-эффект (в отличие от тайлов, которые синхронно двигаются и читаются
/// как статичная сетка).
struct FallingPatternView: View {
    let elementColor: Color

    private struct Drop {
        let xPercent: Double  // [0..1] — позиция по ширине
        let length: Double    // высота streak'а в px
        let speed: Double     // px/s — у каждой своя
        let phase: Double     // начальный сдвиг по Y — десинхронизирует капли
        let opacity: Double
    }

    /// Линейный конгруэнтный генератор. Детерминированный → одинаковая «карта
    /// дождя» на каждом запуске (без визуальных скачков).
    private struct DeterministicRNG {
        var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
        mutating func unit() -> Double {
            Double(next() >> 11) / Double(1 << 53)
        }
        mutating func range(_ r: ClosedRange<Double>) -> Double {
            r.lowerBound + unit() * (r.upperBound - r.lowerBound)
        }
    }

    private static let drops: [Drop] = {
        var rng = DeterministicRNG(seed: 0xDEAD_BEEF)
        return (0..<180).map { _ in
            Drop(
                xPercent: rng.range(0...1),
                length:   rng.range(45...140),
                speed:    rng.range(80...320),
                phase:    rng.range(0...3000),
                opacity:  rng.range(0.30...0.85)
            )
        }
    }()

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { context in
            Canvas(rendersAsynchronously: true) { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                for drop in Self.drops {
                    drawDrop(drop, ctx: &ctx, size: size, time: t)
                }
            }
        }
    }

    private func drawDrop(_ drop: Drop, ctx: inout GraphicsContext, size: CGSize, time: Double) {
        // Полный цикл: капля от верха за пределами экрана до низа за пределами,
        // потом повторно сверху. Без видимых «скачков».
        let cycle = size.height + drop.length + 40
        let raw = (time * drop.speed + drop.phase).truncatingRemainder(dividingBy: cycle)
        let y = raw - drop.length
        let x = drop.xPercent * size.width

        let rect = CGRect(x: x - 0.75, y: y, width: 1.5, height: drop.length)
        ctx.fill(
            Path(ellipseIn: rect),
            with: .color(elementColor.opacity(drop.opacity))
        )
    }
}
