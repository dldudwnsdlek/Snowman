import SnowCore
import SpriteKit
import WinterArt

extension SnowScene {
    /// 제설차 부르기: drives along the Dock (or the ground when the Dock is hidden) and pushes the snow off.
    func callPlow() {
        guard objects.plow == nil else { return }
        store.clearStash(.dock)
        let target = ledge(.dock) ?? ledge(.ground)
        guard let l = target else { return }
        let onDock = l.kind == .dock
        let plow = SnowplowNode(ledgeKind: l.kind, scale: onDock ? 0.72 : 0.8)
        if onDock {
            plow.position = CGPoint(x: l.spec.x0 - SpriteArt.plowBladeFront * plow.s + 6, y: l.spec.y + 70)
            plow.falling = true
        } else {
            plow.position = CGPoint(x: -plow.width - 10, y: l.spec.y)
        }
        addChild(plow)
        objects.plow = plow
        Sound.play(.horn, volume: 0.3)
    }

    func updatePlow(dt: CGFloat) {
        guard let plow = objects.plow else { return }
        guard let l = ledge(plow.ledgeKind) else {
            spillMound(plow, at: plow.bladeX, y: plow.position.y)
            finishPlow(plow)
            return
        }
        if plow.falling && !plow.finished {
            // dropping onto the Dock at the start
            plow.fallVelocity += ThrowTuning.gravity * dt
            plow.position.y += plow.fallVelocity * dt
            if plow.position.y <= l.spec.y {
                plow.position.y = l.spec.y
                plow.falling = false
                plow.fallVelocity = 0
                Effects.puff(in: self, at: CGPoint(x: plow.position.x + plow.width / 2, y: l.spec.y), size: 40)
            }
            plow.animate(t: simTime, distance: 0)
            return
        }
        if plow.finished {
            plow.position.x += plow.driveSpeed * dt
            plow.fallVelocity += ThrowTuning.gravity * 0.5 * dt
            plow.position.y += plow.fallVelocity * dt
            plow.animate(t: simTime, distance: plow.driveSpeed * dt)
            if plow.alpha <= 0.01 || plow.position.x > size.width + 20 {
                plow.removeFromParent()
                objects.plow = nil
            }
            return
        }
        let oldBlade = plow.bladeX
        let step = plow.driveSpeed * dt
        plow.position.x += step
        plow.position.y = l.spec.y
        let newBlade = plow.bladeX
        if let _ = store.piles[l.kind] {
            let lo = max(0, oldBlade - 1 - l.spec.x0)
            let hi = min(l.spec.width, newBlade - l.spec.x0)
            if hi > lo {
                let got = store.piles[l.kind]?.takeAll(localRange: lo...hi) ?? 0
                if got > 0 {
                    plow.collected += got
                    markDirty(l.kind)
                }
            }
            // clean up anything left behind the blade
            let behind = max(0, plow.position.x - l.spec.x0)
            if behind > 0 {
                let left = store.piles[l.kind]?.takeAll(localRange: 0...min(l.spec.width, behind)) ?? 0
                if left > 0 { plow.collected += left; markDirty(l.kind) }
            }
        }
        if plow.collected > 60, Int(simTime * 20) % 3 == 0 {
            particles.spawnClump(x: newBlade + 4, y: l.spec.y + min(20, CGFloat(plow.collected).squareRoot() * 0.6),
                                 vx: CGFloat.random(in: 20...80), vy: CGFloat.random(in: 30...90), area: 0.5)
        }
        pushObjects(ahead: plow, on: l)
        plow.animate(t: simTime, distance: step)
        if newBlade >= l.spec.x1 {
            spillMound(plow, at: l.spec.x1, y: l.spec.y)
            plow.finished = true
            plow.fallVelocity = l.kind == .dock ? 60 : 0
            plow.run(SKAction.sequence([SKAction.wait(forDuration: 0.25), SKAction.fadeOut(withDuration: 0.5)]))
            Sound.play(.horn, volume: 0.25)
        }
    }

    private func pushObjects(ahead plow: SnowplowNode, on l: FrameLedge) {
        let blade = plow.bladeX
        let moundWidth = min(34, 3 + CGFloat(plow.collected).squareRoot() * 0.55) * 2
        for b in objects.balls where b.state == .resting && b.support?.kind == l.kind {
            let x = b.position.x
            if x - b.radius < blade + moundWidth * 0.6 && x > plow.position.x {
                let newX = blade + moundWidth * 0.6 + b.radius
                if newX >= l.spec.x1 {
                    b.state = .falling
                    b.support = nil
                    b.velocity = CGVector(dx: plow.driveSpeed, dy: 60)
                } else {
                    b.support?.localX = newX - l.spec.x0
                    b.roll(by: newX - x)
                }
            }
        }
        for man in objects.snowmen where man.state == .idle && man.support?.kind == l.kind && !plow.hopped.contains(man.id) {
            if man.position.x - man.halfWidth < blade + 40 && man.position.x > plow.position.x {
                plow.hopped.insert(man.id)
                man.state = .flying
                man.support = nil
                man.velocity = CGVector(dx: -plow.driveSpeed * 0.9, dy: 760)
                man.spin = 0
                man.danceAfterLanding = true
            }
        }
    }

    private func spillMound(_ plow: SnowplowNode, at x: CGFloat, y: CGFloat) {
        guard plow.collected > 1 else { return }
        let count = min(220, max(8, Int(plow.collected / 5)))
        let each = plow.collected / Float(count)
        for i in 0..<count {
            let h = CGFloat(i % 12) * 1.6
            particles.spawnClump(x: x + CGFloat.random(in: -6...4), y: y + 2 + h,
                                 vx: CGFloat.random(in: 40...170), vy: CGFloat.random(in: -10...120), area: each)
        }
        plow.collected = 0
        Sound.play(.whoosh, volume: 0.35)
    }

    private func finishPlow(_ plow: SnowplowNode) {
        plow.finished = true
        plow.run(SKAction.fadeOut(withDuration: 0.4))
    }
}
