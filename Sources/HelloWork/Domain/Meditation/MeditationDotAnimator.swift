import Foundation
import CoreGraphics

/// Pure animation logic для зелёной точки. Catmull-rom spline через waypoints
/// (4 точки одновременно): даёт smooth curves без угловых поворотов в targets.
/// На каждом «сегменте» движение идёт от waypoints[1] к waypoints[2], tangents
/// определены waypoints[0] и waypoints[3]. Когда сегмент закончен — окно
/// сдвигается, новая точка генерится в waypoints[3].
///
/// Continuous motion, без dwell-пауз — точка плывёт непрерывно.
/// transitionDuration 8-12 секунд per segment — медитативный ритм.
struct MeditationDotAnimator {
    let bounds: CGRect
    let edgeMargin: CGFloat
    let minTargetDistance: CGFloat
    let segmentDurationRange: ClosedRange<TimeInterval>

    /// 4 последовательные waypoints. Текущая позиция интерполируется между
    /// waypoints[1] (start segment) и waypoints[2] (end segment); waypoints[0]
    /// и waypoints[3] — neighbours для tangent calculation.
    private var waypoints: [CGPoint]
    private var segmentStart: Date
    private var segmentDuration: TimeInterval

    init(
        bounds: CGRect,
        edgeMargin: CGFloat = 120,
        minTargetDistance: CGFloat = 200,
        segmentDurationRange: ClosedRange<TimeInterval> = 8.0...12.0,
        startDate: Date = .now,
        rng: inout some RandomNumberGenerator
    ) {
        self.bounds = bounds
        self.edgeMargin = edgeMargin
        self.minTargetDistance = minTargetDistance
        self.segmentDurationRange = segmentDurationRange

        // Стартовые 4 waypoints. Первый — где появится точка (центр screen);
        // остальные генерятся random с constraints.
        let p1 = CGPoint(x: bounds.midX, y: bounds.midY)
        let p0 = Self.randomPoint(in: bounds, margin: edgeMargin, avoidingPoint: p1, minDistance: minTargetDistance, rng: &rng)
        let p2 = Self.randomPoint(in: bounds, margin: edgeMargin, avoidingPoint: p1, minDistance: minTargetDistance, rng: &rng)
        let p3 = Self.randomPoint(in: bounds, margin: edgeMargin, avoidingPoint: p2, minDistance: minTargetDistance, rng: &rng)
        self.waypoints = [p0, p1, p2, p3]
        self.segmentStart = startDate
        self.segmentDuration = Double.random(in: segmentDurationRange, using: &rng)
    }

    /// Возвращает current position для timestamp. Mutating — сдвигает waypoints
    /// окно когда сегмент закончен.
    mutating func tick(at date: Date, rng: inout some RandomNumberGenerator) -> CGPoint {
        let elapsed = date.timeIntervalSince(segmentStart)
        var progress = elapsed / segmentDuration

        if progress >= 1.0 {
            // Закончили segment. Сдвигаем окно: drop waypoints[0], add new
            // waypoint в конец. Новая точка должна быть «дальше» от текущей
            // (waypoints[2] становится новым waypoints[1]).
            waypoints.removeFirst()
            let newTail = Self.randomPoint(
                in: bounds, margin: edgeMargin,
                avoidingPoint: waypoints.last,
                minDistance: minTargetDistance,
                rng: &rng
            )
            waypoints.append(newTail)
            segmentStart = date
            segmentDuration = Double.random(in: segmentDurationRange, using: &rng)
            progress = 0
        }

        // Easing on top of catmull-rom — даёт «дыхание» в темпе движения.
        let eased = Self.easeInOutCubic(progress)
        return Self.catmullRom(
            p0: waypoints[0], p1: waypoints[1],
            p2: waypoints[2], p3: waypoints[3],
            t: eased
        )
    }

    // MARK: - Catmull-rom interpolation

    /// Catmull-rom spline через 4 control points. t in [0,1] идёт от p1 к p2.
    /// p0 и p3 определяют tangents в концах (smooth pass-through).
    /// Tension = 0.5 (стандартный «centripetal» feel).
    private static func catmullRom(p0: CGPoint, p1: CGPoint, p2: CGPoint, p3: CGPoint, t: Double) -> CGPoint {
        let t2 = t * t
        let t3 = t2 * t
        let x = 0.5 * (
            (2 * p1.x) +
            (-p0.x + p2.x) * t +
            (2 * p0.x - 5 * p1.x + 4 * p2.x - p3.x) * t2 +
            (-p0.x + 3 * p1.x - 3 * p2.x + p3.x) * t3
        )
        let y = 0.5 * (
            (2 * p1.y) +
            (-p0.y + p2.y) * t +
            (2 * p0.y - 5 * p1.y + 4 * p2.y - p3.y) * t2 +
            (-p0.y + 3 * p1.y - 3 * p2.y + p3.y) * t3
        )
        return CGPoint(x: x, y: y)
    }

    // MARK: - Helpers

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
        let x = CGFloat.random(in: inset.minX...inset.maxX, using: &rng)
        let y = CGFloat.random(in: inset.minY...inset.maxY, using: &rng)
        return CGPoint(x: x, y: y)
    }

    private static func easeInOutCubic(_ t: Double) -> Double {
        if t < 0.5 {
            return 4 * t * t * t
        } else {
            let p = -2 * t + 2
            return 1 - (p * p * p) / 2
        }
    }
}
