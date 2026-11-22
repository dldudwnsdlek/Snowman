import SnowCore
import SpriteKit

/// Synthetic interactions used by the debug command channel.
extension SnowScene {
    func debugFill(height: CGFloat) {
        for l in frameLedges {
            guard let pile = store.piles[l.kind] else { continue }
            for c in 0..<pile.columnCount {
                let x = pile.centerX(ofColumn: c)
                let need = max(0, Float(height) - (store.piles[l.kind]?.heights[c] ?? 0))
                if need > 0 { store.piles[l.kind]?.add(atLocalX: x, area: need * Float(SnowPile.columnWidth)) }
            }
            _ = store.piles[l.kind]?.relax(iterations: 20)
            markDirty(l.kind)
        }
    }

    func debugRoll(from x0: CGFloat, to x1: CGFloat, lift: CGPoint?) {
        guard let s = surfaceBelow(x: x0, y: 120) else { return }
        scoop(kind: s.ledge.kind, localX: x0 - s.ledge.spec.x0)
        guard case .ball(let id)? = objects.drag else { return }
        let steps = max(1, Int(abs(x1 - x0) / 5))
        for i in 1...steps {
            let x = x0 + (x1 - x0) * CGFloat(i) / CGFloat(steps)
            let y = (surfaceBelow(x: x, y: 120)?.y ?? 0) + 8
            dragBall(id, to: CGPoint(x: x, y: y))
        }
        if let lift {
            dragBall(id, to: lift)
            if let b = ball(id) {
                b.state = .falling
                b.velocity = .zero
                b.support = nil
            }
        } else {
            ball(id)?.state = .resting
        }
        objects.drag = nil
    }

    func debugThrow(vx: CGFloat, vy: CGFloat) {
        guard let man = objects.snowmen.last(where: { $0.state == .idle }) else { return }
        man.state = .flying
        man.support = nil
        man.velocity = CGVector(dx: vx, dy: vy)
        man.spin = -vx * 0.004
    }
}
