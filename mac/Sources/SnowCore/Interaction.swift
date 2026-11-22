import CoreGraphics

/// What the mouse is over.
public enum HitTarget: Equatable, Sendable {
    case snowman(Int)
    case snowball(Int)
    case pile(LedgeKind, localX: CGFloat)
}

/// Finds the interactive thing under `point` (scene coordinates).
/// Snowmen win over snowballs, snowballs over snow; snow needs at least 3pt visible.
public func hitTest(point: CGPoint,
                    snowmen: [(id: Int, frame: CGRect)],
                    balls: [(id: Int, center: CGPoint, radius: CGFloat)],
                    piles: [(spec: LedgeSpec, pile: SnowPile, vis: Visibility)]) -> HitTarget? {
    if let man = snowmen.first(where: { $0.frame.contains(point) }) {
        return .snowman(man.id)
    }
    if let ball = balls.first(where: { hypot($0.center.x - point.x, $0.center.y - point.y) <= $0.radius + 2 }) {
        return .snowball(ball.id)
    }
    for entry in piles {
        let spec = entry.spec
        guard point.x >= spec.x0, point.x < spec.x1 else { continue }
        let localX = point.x - spec.x0
        guard let c = entry.pile.column(atLocalX: localX) else { continue }
        let visible = entry.vis.visibleHeight(column: c, height: entry.pile.heights[c])
        guard visible >= SnowballTuning.scoopMinimumHeight else { continue }
        if point.y >= spec.y + 1.5 && point.y <= spec.y + CGFloat(visible) + 3 {
            return .pile(spec.kind, localX: localX)
        }
    }
    return nil
}
