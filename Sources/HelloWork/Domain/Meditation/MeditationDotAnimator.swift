import Foundation
import CoreGraphics

/// Pure animation logic для зелёной точки в meditation-сессии. Никакого UI.
/// На каждый tick (60Hz) выдаёт current dot position. Цели генерируются
/// random но с constraints: edge margin, min distance от предыдущей,
/// dwell time 2-5 сек на каждой. Easing — easeInOutCubic для естественного
/// «дыхания» движения.
struct MeditationDotAnimator {
    let bounds: CGRect
    let edgeMargin: CGFloat
    let minTargetDistance: CGFloat
    let dwellRange: ClosedRange<TimeInterval>

    private var currentTarget: CGPoint
    private var nextTarget: CGPoint
    private var transitionStart: Date
    private var transitionDuration: TimeInterval

    /// RNG — passed in для тестируемости (deterministic seed).
    /// В production passing `&SystemRandomNumberGenerator()`.
    init(
        bounds: CGRect,
        edgeMargin: CGFloat = 120,
        minTargetDistance: CGFloat = 200,
        dwellRange: ClosedRange<TimeInterval> = 2.0...5.0,
        startDate: Date = .now,
        rng: inout some RandomNumberGenerator
    ) {
        self.bounds = bounds
        self.edgeMargin = edgeMargin
        self.minTargetDistance = minTargetDistance
        self.dwellRange = dwellRange

        let initial = Self.randomPoint(
            in: bounds, margin: edgeMargin, avoidingPoint: nil,
            minDistance: minTargetDistance, rng: &rng
        )
        self.currentTarget = initial
        self.nextTarget = Self.randomPoint(
            in: bounds, margin: edgeMargin, avoidingPoint: initial,
            minDistance: minTargetDistance, rng: &rng
        )
        self.transitionStart = startDate
        self.transitionDuration = Double.random(in: dwellRange, using: &rng)
    }

    /// Вызывается на каждом tick. Возвращает current position.
    /// Mutating — внутри обновляет targets когда transition закончен.
    mutating func tick(at date: Date, rng: inout some RandomNumberGenerator) -> CGPoint {
        let elapsed = date.timeIntervalSince(transitionStart)
        let progress = min(max(elapsed / transitionDuration, 0), 1)

        if progress >= 1.0 {
            // Достигли nextTarget — генерим следующий и сбрасываем transition.
            currentTarget = nextTarget
            nextTarget = Self.randomPoint(
                in: bounds, margin: edgeMargin, avoidingPoint: currentTarget,
                minDistance: minTargetDistance, rng: &rng
            )
            transitionStart = date
            transitionDuration = Double.random(in: dwellRange, using: &rng)
            return currentTarget
        }

        let eased = Self.easeInOutCubic(progress)
        return CGPoint(
            x: currentTarget.x + (nextTarget.x - currentTarget.x) * eased,
            y: currentTarget.y + (nextTarget.y - currentTarget.y) * eased
        )
    }

    // MARK: - Helpers

    /// Random point внутри bounds.insetBy(margin), избегая близости к
    /// `avoidingPoint` (если задан) на minDistance. До 20 попыток —
    /// если все близки, возвращаем последнюю (graceful, не блокируем UI).
    private static func randomPoint(
        in bounds: CGRect,
        margin: CGFloat,
        avoidingPoint: CGPoint?,
        minDistance: CGFloat,
        rng: inout some RandomNumberGenerator
    ) -> CGPoint {
        let inset = bounds.insetBy(dx: margin, dy: margin)
        guard inset.width > 0, inset.height > 0 else {
            return CGPoint(x: bounds.midX, y: bounds.midY)
        }

        for _ in 0..<20 {
            let x = CGFloat.random(in: inset.minX...inset.maxX, using: &rng)
            let y = CGFloat.random(in: inset.minY...inset.maxY, using: &rng)
            let candidate = CGPoint(x: x, y: y)
            if let avoid = avoidingPoint {
                let dx = candidate.x - avoid.x
                let dy = candidate.y - avoid.y
                if (dx * dx + dy * dy).squareRoot() < minDistance { continue }
            }
            return candidate
        }
        // Fallback — random без constraint (не зависаем).
        let x = CGFloat.random(in: inset.minX...inset.maxX, using: &rng)
        let y = CGFloat.random(in: inset.minY...inset.maxY, using: &rng)
        return CGPoint(x: x, y: y)
    }

    /// Cubic ease-in-out: t < 0.5 → 4t³ ; t ≥ 0.5 → 1 - (-2t+2)³/2.
    /// Натуральное «вдох-выдох» движение, без рывков на старте/финише.
    private static func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let p = -2 * t + 2
            return 1 - (p * p * p) / 2
        }
    }
}
