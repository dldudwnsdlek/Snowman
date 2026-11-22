import AppKit
import SnowCore
import SpriteKit
import WinterArt

enum DragTarget {
    case ball(Int)
    case snowman(Int, offset: CGVector)
}

/// Snowballs, snowmen and the plow living in a scene.
struct SceneObjects {
    var balls: [SnowballNode] = []
    var snowmen: [SnowmanNode] = []
    var nextID = 1
    var styleBag = StyleBag()
    var drag: DragTarget?
    var press: (p: CGPoint, t: TimeInterval)?
    var samples: [(t: TimeInterval, p: CGPoint)] = []
    var mitten: SKSpriteNode?
    var plow: SnowplowNode?
    /// Styles requested from the menu, keyed by the falling head ball.
    var pendingStyles: [Int: SnowmanStyle] = [:]
}

extension SnowScene {
    static let maxSnowmen = 12

    func setUpObjects() {
        let m = SKSpriteNode(texture: Textures.mitten, size: CGSize(width: 28, height: 28))
        m.zPosition = 50
        m.isHidden = true
        addChild(m)
        objects.mitten = m
    }

    func makeID() -> Int {
        defer { objects.nextID += 1 }
        return objects.nextID
    }

    func ball(_ id: Int) -> SnowballNode? { objects.balls.first { $0.id == id } }
    func snowman(_ id: Int) -> SnowmanNode? { objects.snowmen.first { $0.id == id } }

    private var bounds: CGRect { CGRect(origin: .zero, size: size) }

    // MARK: - Hover

    func hoverTarget(_ p: CGPoint) -> HitTarget? {
        let men = objects.snowmen.filter { $0.state != .building && !$0.isHidden }.map { (id: $0.id, frame: $0.hitFrame) }
        let balls = objects.balls.filter { !$0.isHidden }.map { (id: $0.id, center: $0.position, radius: $0.radius) }
        let piles = frameLedges.compactMap { l -> (spec: LedgeSpec, pile: SnowPile, vis: Visibility)? in
            guard let pile = store.piles[l.kind] else { return nil }
            return (l.spec, pile, l.vis)
        }
        return hitTest(point: p, snowmen: men, balls: balls, piles: piles)
    }

    func updateObjects(dt: CGFloat, now: TimeInterval) {
        let mouse = geometry.sceneMouse(NSEvent.mouseLocation)
        var hover: HitTarget?
        if objects.drag == nil, let m = mouse { hover = hoverTarget(m) }
        wantsMouse = objects.drag != nil || hover != nil
        if let mitten = objects.mitten {
            var draggingBall = false
            if case .ball = objects.drag { draggingBall = true }
            let show = mouse != nil && (hover != nil || draggingBall)
            mitten.isHidden = !show
            if show, let m = mouse { mitten.position = CGPoint(x: m.x + 16, y: m.y - 14) }
        }
        updateBalls(dt: dt)
        updateSnowmen(dt: dt, mouse: mouse)
        updatePlow(dt: dt)
    }

    // MARK: - Mouse

    private func clamp(_ p: CGPoint) -> CGPoint {
        CGPoint(x: min(max(p.x, 2), size.width - 2), y: min(max(p.y, 2), size.height - 2))
    }

    private func record(_ t: TimeInterval, _ p: CGPoint) {
        objects.samples.append((t, p))
        objects.samples.removeAll { t - $0.t > 0.12 }
    }

    private func releaseVelocity() -> CGVector {
        guard let first = objects.samples.first, let last = objects.samples.last, last.t - first.t > 0.008 else { return .zero }
        let dt = CGFloat(last.t - first.t)
        return CGVector(dx: (last.p.x - first.p.x) / dt, dy: (last.p.y - first.p.y) / dt)
    }

    override func mouseDown(with event: NSEvent) {
        let p = event.location(in: self)
        objects.samples = [(event.timestamp, p)]
        objects.press = (p, event.timestamp)
        guard let target = hoverTarget(p) else { return }
        switch target {
        case .snowman(let id):
            guard let man = snowman(id) else { return }
            man.state = .dragged
            man.support = nil
            man.dragTarget = man.position
            objects.drag = .snowman(id, offset: CGVector(dx: man.position.x - p.x, dy: man.position.y - p.y))
            Sound.play(.pop, volume: 0.2)
        case .snowball(let id):
            guard let b = ball(id) else { return }
            b.state = .rolling
            objects.drag = .ball(id)
        case .pile(let kind, let localX):
            scoop(kind: kind, localX: localX)
        }
    }

    override func mouseDragged(with event: NSEvent) {
        let p = clamp(event.location(in: self))
        record(event.timestamp, p)
        guard let drag = objects.drag else { return }
        switch drag {
        case .ball(let id): dragBall(id, to: p)
        case .snowman(let id, let offset): snowman(id)?.dragTarget = CGPoint(x: p.x + offset.dx, y: p.y + offset.dy)
        }
    }

    override func mouseUp(with event: NSEvent) {
        let p = event.location(in: self)
        record(event.timestamp, p)
        guard let drag = objects.drag else { return }
        objects.drag = nil
        let v = releaseVelocity()
        switch drag {
        case .ball(let id):
            guard let b = ball(id) else { return }
            if b.state == .carried {
                b.state = .falling
                b.support = nil
                b.velocity = limit(v, 1800)
            } else {
                b.state = .resting
            }
        case .snowman(let id, _):
            guard let man = snowman(id) else { return }
            let isClick = objects.press.map { hypot(p.x - $0.p.x, p.y - $0.p.y) < 4 && event.timestamp - $0.t < 0.35 } ?? false
            man.state = .flying
            man.velocity = isClick ? .zero : limit(v, 3200)
            man.spin = isClick ? 0 : -man.velocity.dx * 0.004
            man.danceAfterLanding = isClick
        }
    }

    private func limit(_ v: CGVector, _ maxSpeed: CGFloat) -> CGVector {
        let speed = hypot(v.dx, v.dy)
        guard speed > maxSpeed else { return v }
        return CGVector(dx: v.dx / speed * maxSpeed, dy: v.dy / speed * maxSpeed)
    }

    // MARK: - Snowballs

    /// Presses into the snow and lifts a handful as a small snowball.
    func scoop(kind: LedgeKind, localX: CGFloat) {
        guard let l = ledge(kind) else { return }
        let taken = store.piles[kind]?.take(localRange: (localX - 7)...(localX + 7), maxArea: 60) ?? 0
        markDirty(kind)
        let r = grownRadius(SnowballTuning.startRadius, addingArea: CGFloat(taken) * 0.4)
        let b = SnowballNode(id: makeID(), radius: r)
        let x = l.spec.x0 + localX
        let surface = surfaceY(on: l, x: x) ?? l.spec.y
        b.position = CGPoint(x: x, y: surface + r * 0.9)
        b.state = .rolling
        b.support = Support(kind: kind, localX: localX)
        addChild(b)
        objects.balls.append(b)
        objects.drag = .ball(b.id)
        Effects.puff(in: self, at: CGPoint(x: x, y: surface), size: 18)
        Sound.play(.pop, volume: 0.2)
    }

    /// Rolls the ball along the snow under the cursor (growing it), or carries it when lifted.
    func dragBall(_ id: Int, to p: CGPoint) {
        guard let b = ball(id) else { return }
        let r = b.radius
        guard let s = surfaceBelow(x: p.x, y: p.y + r * 0.5), p.y - (s.y + r) < r + 16 else {
            b.state = .carried
            b.support = nil
            b.position = p
            return
        }
        let oldX = b.position.x
        let newX = p.x
        let dx = newX - oldX
        if abs(dx) > 0.01, let pile = store.piles[s.ledge.kind] {
            let newLocal = newX - s.ledge.spec.x0
            let oldLocal = (b.support?.kind == s.ledge.kind) ? oldX - s.ledge.spec.x0 : newLocal
            let reach = min(r * 0.8, 10)
            let lo = min(oldLocal, newLocal) - reach
            let hi = max(oldLocal, newLocal) + reach
            let under = CGFloat(pile.height(atLocalX: newLocal))
            if under > 0.3 {
                let wanted = Float(abs(dx) * min(under, 9) * 0.9)
                let got = store.piles[s.ledge.kind]?.take(localRange: lo...hi, maxArea: wanted) ?? 0
                if got > 0 {
                    b.radius = grownRadius(b.radius, addingArea: CGFloat(got))
                    markDirty(s.ledge.kind)
                }
            }
        }
        let surfaceNow = surfaceY(on: s.ledge, x: newX) ?? s.y
        b.position = CGPoint(x: newX, y: surfaceNow + b.radius * 0.9)
        b.roll(by: dx)
        b.state = .rolling
        b.support = Support(kind: s.ledge.kind, localX: newX - s.ledge.spec.x0)
    }

    private func restingBalls(excluding id: Int) -> [(id: Int, center: CGPoint, radius: CGFloat)] {
        objects.balls.filter { $0.id != id && $0.state == .resting }.map { (id: $0.id, center: $0.position, radius: $0.radius) }
    }

    private func updateBalls(dt: CGFloat) {
        for b in objects.balls {
            switch b.state {
            case .rolling, .carried:
                continue
            case .resting:
                switch supportState(b.support) {
                case .visible(let x, let s):
                    b.isHidden = false
                    b.position = CGPoint(x: x, y: s + b.radius * 0.9)
                case .hidden:
                    b.isHidden = true
                case .gone:
                    b.isHidden = false
                    b.state = .falling
                    b.support = nil
                    b.velocity = .zero
                }
            case .falling:
                let r = b.radius
                let prevBottom = b.position.y - r * 0.9
                b.velocity.dy += ThrowTuning.gravity * dt
                var pos = CGPoint(x: b.position.x + b.velocity.dx * dt, y: b.position.y + b.velocity.dy * dt)
                var v = b.velocity
                if let hit = bounceOffWalls(position: &pos, velocity: &v, halfWidth: r, halfHeight: r,
                                            bounds: bounds, restitution: ThrowTuning.wallRestitution), hit.speed > 200 {
                    Effects.puff(in: self, at: pos, size: r * 2)
                }
                b.position = pos
                b.velocity = v
                b.roll(by: v.dx * dt)
                let bottom = pos.y - r * 0.9
                if v.dy < 0 {
                    for other in restingBalls(excluding: b.id) {
                        let top = other.center.y + other.radius
                        guard prevBottom >= top - 2, bottom <= top + 12 else { continue }
                        if stackCandidate(dropped: (CGPoint(x: pos.x, y: top + r), r), resting: [other]) != nil,
                           let target = ball(other.id) {
                            formSnowman(dropped: b, onto: target)
                            return
                        }
                    }
                }
                if v.dy <= 0, let s = surfaceBelow(x: pos.x, y: prevBottom + 1), bottom <= s.y {
                    b.position.y = s.y + r * 0.9
                    if v.dy < -520 {
                        b.velocity = CGVector(dx: v.dx * 0.7, dy: -v.dy * 0.25)
                    } else {
                        b.state = .resting
                        b.velocity = .zero
                        b.support = Support(kind: s.ledge.kind, localX: pos.x - s.ledge.spec.x0)
                    }
                    if v.dy < -300 {
                        Effects.puff(in: self, at: CGPoint(x: pos.x, y: s.y), size: r * 1.6)
                        Sound.play(.thud, volume: 0.2)
                    }
                }
                if pos.y < -200 { removeBall(b) }
            }
        }
    }

    private func removeBall(_ b: SnowballNode) {
        b.removeFromParent()
        objects.balls.removeAll { $0 === b }
    }

    // MARK: - Snowmen

    private func formSnowman(dropped: SnowballNode, onto bottom: SnowballNode) {
        let big = max(dropped.radius, bottom.radius)
        let base = CGPoint(x: bottom.position.x, y: bottom.position.y - bottom.radius * 0.9)
        let support = bottom.support
        removeBall(dropped)
        removeBall(bottom)
        let style = objects.pendingStyles.removeValue(forKey: dropped.id) ?? objects.styleBag.next()
        let man = addSnowman(style: style, bodyRadius: big, at: base, support: support)
        man.playBuildSequence(in: self) {}
    }

    @discardableResult
    private func addSnowman(style: SnowmanStyle, bodyRadius: CGFloat, at base: CGPoint, support: Support?) -> SnowmanNode {
        let man = SnowmanNode(id: makeID(), style: style, bodyRadius: bodyRadius)
        man.position = base
        man.support = support
        addChild(man)
        objects.snowmen.append(man)
        while objects.snowmen.count > SnowScene.maxSnowmen {
            let old = objects.snowmen.removeFirst()
            Effects.puff(in: self, at: old.center, size: 60 * old.s)
            old.removeFromParent()
        }
        return man
    }

    /// Menu: two balls appear on the Dock (or the ground) and stack themselves into a snowman.
    func spawnSnowman(style: SnowmanStyle?) {
        guard let target = ledge(.dock) ?? ledge(.ground) else { return }
        let r: CGFloat = 30
        let lo = target.spec.x0 + 50
        let hi = max(lo + 1, target.spec.x1 - 50)
        var x = CGFloat.random(in: lo...hi)
        for _ in 0..<12 {
            let candidate = CGFloat.random(in: lo...hi)
            let crowded = objects.snowmen.contains { abs($0.position.x - candidate) < 80 }
                || objects.balls.contains { abs($0.position.x - candidate) < 70 }
            x = candidate
            if !crowded { break }
        }
        let s = surfaceY(on: target, x: x) ?? target.spec.y
        let body = SnowballNode(id: makeID(), radius: r)
        body.position = CGPoint(x: x, y: s + r * 0.9)
        body.state = .resting
        body.support = Support(kind: target.kind, localX: x - target.spec.x0)
        body.setScale(0)
        body.run(SKAction.sequence([SKAction.scale(to: 1.15, duration: 0.18), SKAction.scale(to: 1, duration: 0.1)]))
        addChild(body)
        objects.balls.append(body)
        Effects.puff(in: self, at: CGPoint(x: x, y: s), size: 50)

        let head = SnowballNode(id: makeID(), radius: 21)
        head.position = CGPoint(x: x, y: min(size.height - 30, s + 2 * r + 160))
        head.state = .falling
        if let style { objects.pendingStyles[head.id] = style }
        head.alpha = 0
        head.run(SKAction.fadeIn(withDuration: 0.15))
        addChild(head)
        objects.balls.append(head)
    }

    private func updateSnowmen(dt: CGFloat, mouse: CGPoint?) {
        for man in objects.snowmen {
            switch man.state {
            case .building, .idle:
                switch supportState(man.support) {
                case .visible(let x, let s):
                    man.isHidden = false
                    man.position = CGPoint(x: x, y: s - 1)
                case .hidden:
                    man.isHidden = true
                case .gone:
                    man.isHidden = false
                    if man.state == .building { man.finishInstantly() }
                    man.state = .flying
                    man.support = nil
                    man.velocity = .zero
                }
            case .dragged:
                let k = 1 - exp(-dt * 22)
                let target = man.dragTarget
                let newPos = CGPoint(x: man.position.x + (target.x - man.position.x) * k,
                                     y: man.position.y + (target.y - man.position.y) * k)
                let vx = (newPos.x - man.position.x) / max(dt, 0.001)
                man.position = newPos
                let wanted = max(-0.7, min(0.7, -vx * 0.0007))
                man.angle += (wanted - man.angle) * min(1, dt * 10)
            case .flying:
                if flyStep(man, dt: dt) { return }
            }
            man.animate(t: simTime, dt: dt, mouse: mouse)
        }
    }

    /// Moves a thrown snowman. Returns true when the snowman list changed (shattered).
    private func flyStep(_ man: SnowmanNode, dt: CGFloat) -> Bool {
        let prevY = man.position.y
        man.velocity.dy += ThrowTuning.gravity * dt
        var center = CGPoint(x: man.center.x + man.velocity.dx * dt, y: man.center.y + man.velocity.dy * dt)
        var v = man.velocity
        if let hit = bounceOffWalls(position: &center, velocity: &v, halfWidth: man.halfWidth, halfHeight: man.halfHeight,
                                    bounds: bounds, restitution: ThrowTuning.wallRestitution) {
            let contact = CGPoint(x: hit.side == .left ? 4 : (hit.side == .right ? size.width - 4 : center.x),
                                  y: hit.side == .top ? size.height - 4 : center.y)
            Effects.puff(in: self, at: contact, size: 46 * man.s)
            switch impactLevel(speed: hit.speed) {
            case .soft:
                Sound.play(.thud, volume: 0.2)
            case .crash:
                let inward = CGPoint(x: contact.x + (hit.side == .left ? 60 : (hit.side == .right ? -60 : 0)),
                                     y: contact.y + (hit.side == .top ? -50 : 70 * man.s))
                Effects.crashText(in: self, at: inward)
                Sound.play(.crash, volume: 0.45)
                burst(at: contact, count: 10, area: 2)
            case .shatter:
                man.velocity = v
                man.position = CGPoint(x: center.x, y: center.y - 50 * man.s)
                shatter(man)
                return true
            }
            man.spin = -man.spin * 0.5 + (hit.side == .right ? 3 : (hit.side == .left ? -3 : 0))
        }
        man.velocity = v
        man.position = CGPoint(x: center.x, y: center.y - 50 * man.s)
        man.angle += man.spin * dt
        if v.dy <= 0, let s = surfaceBelow(x: man.position.x, y: prevY + 1), man.position.y <= s.y {
            let impact = -v.dy
            man.position.y = s.y
            if impactLevel(speed: impact) == .shatter {
                shatter(man)
                return true
            }
            if impact > 520 {
                man.velocity = CGVector(dx: v.dx * 0.6, dy: impact * 0.32)
                man.spin *= 0.5
                Effects.puff(in: self, at: CGPoint(x: man.position.x, y: s.y), size: 50 * man.s)
                Sound.play(.thud, volume: 0.3)
                if impactLevel(speed: impact) == .crash {
                    Effects.crashText(in: self, at: CGPoint(x: man.position.x, y: s.y + 130 * man.s))
                    Sound.play(.crash, volume: 0.4)
                }
            } else {
                man.state = .idle
                man.velocity = .zero
                man.support = Support(kind: s.ledge.kind, localX: man.position.x - s.ledge.spec.x0)
                man.settleUpright()
                man.angleVelocity = -v.dx * 0.002
                if impact > 150 { Effects.puff(in: self, at: CGPoint(x: man.position.x, y: s.y), size: 34 * man.s) }
                if man.danceAfterLanding {
                    man.danceAfterLanding = false
                    man.dance(at: simTime)
                }
            }
        }
        if man.position.y < -400 {
            man.removeFromParent()
            objects.snowmen.removeAll { $0 === man }
            return true
        }
        return false
    }

    private func burst(at p: CGPoint, count: Int, area: Float) {
        for _ in 0..<count {
            particles.spawnClump(x: p.x + CGFloat.random(in: -8...8), y: p.y + CGFloat.random(in: -8...8),
                                 vx: CGFloat.random(in: -220...220), vy: CGFloat.random(in: -40...300), area: area)
        }
    }

    /// 와장창: the snowman breaks; its two balls survive and can be stacked again.
    private func shatter(_ man: SnowmanNode) {
        let s = man.s
        for part: SnowmanPart in [.hat, .nose, .leftArm, .rightArm, .scarf, .scarfTail, .buttons] {
            guard let sprite = man.sprites[part], !sprite.isHidden, let parent = sprite.parent else { continue }
            let p = parent.convert(sprite.position, to: self)
            Effects.debris(in: self, texture: sprite.texture, size: sprite.size, at: p,
                           velocity: CGVector(dx: CGFloat.random(in: -380...380) + man.velocity.dx * 0.2,
                                              dy: CGFloat.random(in: 120...520)),
                           spin: CGFloat.random(in: -14...14), scale: s, rotation: man.angle)
        }
        let body = SnowballNode(id: makeID(), radius: 30 * s * 0.9)
        body.position = CGPoint(x: man.position.x, y: man.position.y + 30 * s)
        body.state = .falling
        body.velocity = CGVector(dx: -man.velocity.dx * 0.15 + CGFloat.random(in: -150...150), dy: CGFloat.random(in: 150...350))
        let head = SnowballNode(id: makeID(), radius: 21 * s * 0.9)
        head.position = CGPoint(x: man.position.x, y: man.position.y + 71 * s)
        head.state = .falling
        head.velocity = CGVector(dx: CGFloat.random(in: -260...260), dy: CGFloat.random(in: 250...480))
        for b in [body, head] {
            b.position = clamp(b.position)
            addChild(b)
            objects.balls.append(b)
        }
        burst(at: man.center, count: 26, area: Float(3 * s))
        Effects.puff(in: self, at: man.center, size: 90 * s)
        Effects.crashText(in: self, at: CGPoint(x: man.center.x, y: man.center.y + 40 * s), size: 34)
        Sound.play(.crash, volume: 0.6)
        man.removeFromParent()
        objects.snowmen.removeAll { $0 === man }
    }

    func clearSnowmen() {
        for man in objects.snowmen {
            Effects.puff(in: self, at: man.center, size: 70 * man.s)
            man.removeFromParent()
        }
        for b in objects.balls {
            Effects.puff(in: self, at: b.position, size: b.radius * 2.2)
            b.removeFromParent()
        }
        objects.snowmen.removeAll()
        objects.balls.removeAll()
        objects.drag = nil
        Sound.play(.whoosh, volume: 0.3)
    }

    // MARK: - Window motion

    func objectsFollow(_ move: LedgeMove) {
        guard abs(move.dx) > 6 else { return }
        for man in objects.snowmen where man.state == .idle && man.support?.kind == move.kind {
            man.angleVelocity += max(-6, min(6, -move.dx * 0.08))
        }
    }

    func objectsCheckSupport() {}

    enum SupportState {
        case visible(x: CGFloat, surface: CGFloat)
        /// Behind a window in front, or the ledge is away for a moment (Space switch, Dock hidden).
        case hidden
        /// The window closed: the object should fall.
        case gone
    }

    func supportState(_ support: Support?) -> SupportState {
        guard let sup = support else { return .gone }
        if let l = ledge(sup.kind) {
            let x = l.spec.x0 + sup.localX
            guard x >= l.spec.x0, x < l.spec.x1 else { return .gone }
            if let s = surfaceY(on: l, x: x) { return .visible(x: x, surface: s) }
            return .hidden
        }
        return store.stash[sup.kind] != nil ? .hidden : .gone
    }

    func debugObjectsReport() -> String {
        var out = "  balls \(objects.balls.count): " + objects.balls.map { "#\($0.id) r\(Int($0.radius)) \($0.state) at \(Int($0.position.x)),\(Int($0.position.y))\($0.isHidden ? " HIDDEN" : "")" }.joined(separator: ", ") + "\n"
        out += "  snowmen \(objects.snowmen.count): " + objects.snowmen.map { "#\($0.id) \($0.style) s\(String(format: "%.2f", $0.s)) \($0.state) at \(Int($0.position.x)),\(Int($0.position.y))" }.joined(separator: ", ") + "\n"
        return out
    }
}
