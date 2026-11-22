import SnowCore
import SpriteKit

/// A ledge as seen during one frame.
struct FrameLedge {
    let kind: LedgeKind
    let spec: LedgeSpec
    let vis: Visibility
    let columns: Int
}

/// Everything that happens on one screen: snowfall, piles, snowballs, snowmen, the plow.
final class SnowScene: SKScene {
    let geometry: ScreenGeometry
    let store = PileStore()

    var amount: SnowAmount = .normal
    var snowing = true
    var accumulateOnWindows = true
    var graceUntil: TimeInterval = 0
    /// True while the overlay must receive mouse events (hovering or dragging something).
    var wantsMouse = false

    private(set) var frameLedges: [FrameLedge] = []
    private var pileNodes: [LedgeKind: PileNode] = [:]
    private var visibilities: [LedgeKind: Visibility] = [:]
    private(set) var particles: ParticleLayer!
    private var lastTime: TimeInterval = 0
    private(set) var simTime: CGFloat = 0
    private var spawnCarry: Double = 0
    private var spill: [LedgeKind: (left: Float, right: Float)] = [:]
    private var touched = Set<LedgeKind>()
    private var meltUntil: TimeInterval = 0
    private var lastApply: TimeInterval = 0
    private var frameCount = 0

    // Interactive objects (filled in by SnowScene+Objects.swift).
    var objects = SceneObjects()

    init(geometry: ScreenGeometry) {
        self.geometry = geometry
        super.init(size: geometry.size)
        backgroundColor = .clear
        scaleMode = .resizeFill
        anchorPoint = .zero
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    override func didMove(to view: SKView) {
        if particles == nil {
            particles = ParticleLayer(parent: self)
            setUpObjects()
            prepopulate()
        }
    }

    private func prepopulate() {
        guard snowing else { return }
        let count = Int(amount.flakesPerSecond * Double(size.width / 1512) * 7)
        for _ in 0..<count {
            particles.spawnFlake(x: CGFloat.random(in: -20...(size.width + 20)),
                                 y: CGFloat.random(in: (size.height * 0.15)...(size.height + 10)), amount: amount)
        }
    }

    // MARK: - Ledges

    func apply(snapshot: TrackerSnapshot, now: TimeInterval) {
        let windowFrames = snapshot.windows.map { (id: $0.id, frame: geometry.toScene(cgRect: $0.boundsCG)) }
        let dock = snapshot.dockFrameCG.map { geometry.toScene(cgRect: $0) }
        let specs = buildLedgeSpecs(windowFrames: windowFrames, dockFrame: dock, sceneSize: size,
                                    menuBarHeight: geometry.menuBarHeight, includeWindows: accumulateOnWindows)
        let oldSpecs = store.specs
        let dt = max(1.0 / 120, now - lastApply)
        lastApply = now
        let result = store.sync(specs, now: now, graceUntil: graceUntil)
        for drop in result.dropped { dropPile(drop.spec, drop.pile, now: now) }

        var live = Set<LedgeKind>()
        for spec in specs {
            live.insert(spec.kind)
            let node = pileNodes[spec.kind] ?? makePileNode(spec.kind)
            if oldSpecs[spec.kind] != spec || visibilities[spec.kind] == nil {
                visibilities[spec.kind] = visibility(for: spec, columnCount: store.piles[spec.kind]?.columnCount ?? 1)
                node.dirty = true
            }
            node.place(spec)
        }
        for (kind, node) in pileNodes where !live.contains(kind) {
            node.removeFromParent()
            pileNodes[kind] = nil
            visibilities[kind] = nil
        }
        frameLedges = specs.compactMap { spec in
            guard let vis = visibilities[spec.kind], let pile = store.piles[spec.kind] else { return nil }
            return FrameLedge(kind: spec.kind, spec: spec, vis: vis, columns: pile.columnCount)
        }
        for move in result.moved {
            shakeOff(move, speed: hypot(move.dx, move.dy) / CGFloat(dt))
            objectsFollow(move)
        }
        objectsCheckSupport()
    }

    private func makePileNode(_ kind: LedgeKind) -> PileNode {
        let node = PileNode(kind: kind)
        addChild(node)
        pileNodes[kind] = node
        return node
    }

    func ledge(_ kind: LedgeKind) -> FrameLedge? { frameLedges.first { $0.kind == kind } }

    func markDirty(_ kind: LedgeKind) {
        pileNodes[kind]?.dirty = true
        touched.insert(kind)
    }

    /// Snow surface height (scene y) at `x` on a ledge, or nil when that spot is hidden.
    func surfaceY(on l: FrameLedge, x: CGFloat) -> CGFloat? {
        guard x >= l.spec.x0, x < l.spec.x1, let pile = store.piles[l.kind] else { return nil }
        let c = min(l.columns - 1, max(0, Int((x - l.spec.x0) / SnowPile.columnWidth)))
        guard !l.vis.hidden[c] else { return nil }
        return l.spec.y + CGFloat(min(pile.height(atLocalX: x - l.spec.x0), l.vis.ceiling[c]))
    }

    /// Highest visible surface at or below `y` for horizontal position `x`.
    func surfaceBelow(x: CGFloat, y: CGFloat) -> (ledge: FrameLedge, y: CGFloat)? {
        var best: (FrameLedge, CGFloat)?
        for l in frameLedges {
            guard let s = surfaceY(on: l, x: x), s <= y + 0.5 else { continue }
            if best == nil || s > best!.1 { best = (l, s) }
        }
        return best.map { (ledge: $0.0, y: $0.1) }
    }

    // MARK: - Falling snow

    private func dropPile(_ spec: LedgeSpec, _ pile: SnowPile, now: TimeInterval) {
        let total = pile.totalArea
        guard total > 1 else { return }
        let perClump = max(4, total / 520)
        for c in 0..<pile.columnCount {
            let h = pile.heights[c]
            guard h > 0.15 else { continue }
            var area = h * Float(SnowPile.columnWidth)
            while area > 0.5 {
                let take = min(area, perClump * Float.random(in: 0.6...1.4))
                area -= take
                particles.spawnClump(x: spec.x0 + pile.centerX(ofColumn: c) + CGFloat.random(in: -1...1),
                                     y: spec.y + CGFloat.random(in: 0...CGFloat(h)),
                                     vx: CGFloat.random(in: -28...28), vy: CGFloat.random(in: -20...40), area: take)
            }
        }
        Sound.play(.whoosh)
    }

    private func shakeOff(_ move: LedgeMove, speed: CGFloat) {
        guard case .window = move.kind, speed > 900, var pile = store.piles[move.kind], let l = ledge(move.kind) else { return }
        let fraction: Float = min(0.25, Float(speed / 900) * 0.06)
        for c in stride(from: 0, to: pile.columnCount, by: 3) {
            let h = pile.heights[c]
            guard h > 0.5 else { continue }
            let area = h * fraction * Float(SnowPile.columnWidth) * 3
            if area > 0.8 {
                particles.spawnClump(x: l.spec.x0 + pile.centerX(ofColumn: c), y: l.spec.y + CGFloat(h) * 0.6,
                                     vx: -move.dx * 3 + CGFloat.random(in: -20...20), vy: CGFloat.random(in: 0...40), area: area)
            }
        }
        pile.scale(by: 1 - fraction)
        store.piles[move.kind] = pile
        markDirty(move.kind)
    }

    private func land(_ p: inout Particle) -> Bool {
        for l in frameLedges {
            guard p.x >= l.spec.x0, p.x < l.spec.x1 else { continue }
            if p.prevY < l.spec.y || p.y > l.spec.y + CGFloat(l.spec.maxHeight) + 1 { continue }
            let local = p.x - l.spec.x0
            let c = min(l.columns - 1, max(0, Int(local / SnowPile.columnWidth)))
            if l.vis.hidden[c] { continue }
            guard let h = store.piles[l.kind]?.heights[c], h < l.vis.ceiling[c] else { continue }
            if crossed(prevY: p.prevY, newY: p.y, surfaceY: l.spec.y + CGFloat(h)) {
                let probability = p.isClump ? max(0.75, l.spec.landProbability) : l.spec.landProbability
                if Float.random(in: 0..<1) < probability {
                    store.piles[l.kind]?.add(atLocalX: local, area: p.area)
                    markDirty(l.kind)
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Frame

    override func update(_ currentTime: TimeInterval) {
        let dt = CGFloat(lastTime == 0 ? 1.0 / 60 : min(1.0 / 20, currentTime - lastTime))
        lastTime = currentTime
        simTime += dt
        frameCount += 1

        if snowing {
            spawnCarry += amount.flakesPerSecond * Double(size.width / 1512) * Double(dt)
            while spawnCarry >= 1 {
                spawnCarry -= 1
                particles.spawnFlake(x: CGFloat.random(in: -40...(size.width + 40)), y: size.height + 8, amount: amount)
            }
        }
        let wind = amount.windStrength * (0.6 * sin(simTime * 0.11) + 0.4 * sin(simTime * 0.37 + 1.3))
        particles.update(dt: dt, wind: wind, width: size.width) { land(&$0) }

        settlePiles(now: currentTime, dt: dt)
        updateObjects(dt: dt, now: currentTime)
    }

    private func settlePiles(now: TimeInterval, dt: CGFloat) {
        if meltUntil != 0 {
            if now < meltUntil {
                let factor = Float(pow(0.004, Double(dt) / 0.6))
                for kind in Array(store.piles.keys) { store.piles[kind]?.scale(by: factor) }
            } else {
                store.clearAll()
                meltUntil = 0
            }
            for kind in Array(store.piles.keys) { markDirty(kind) }
        }
        let relaxAll = frameCount % 20 == 0
        let kinds = relaxAll ? Set(store.piles.keys) : touched
        touched.removeAll(keepingCapacity: true)
        for kind in kinds {
            guard let result = store.piles[kind]?.relax(iterations: 3), let l = ledge(kind) else { continue }
            if result.left > 0 || result.right > 0 { pileNodes[kind]?.dirty = true }
            var s = spill[kind] ?? (0, 0)
            s.left += result.left
            s.right += result.right
            if s.left > 3 {
                particles.spawnClump(x: l.spec.x0 + 1, y: l.spec.y + 2, vx: -CGFloat.random(in: 10...30), vy: 0, area: s.left)
                s.left = 0
            }
            if s.right > 3 {
                particles.spawnClump(x: l.spec.x1 - 1, y: l.spec.y + 2, vx: CGFloat.random(in: 10...30), vy: 0, area: s.right)
                s.right = 0
            }
            spill[kind] = s
        }
        for (kind, node) in pileNodes {
            guard let pile = store.piles[kind], let vis = visibilities[kind] else { continue }
            node.refresh(pile: pile, vis: vis, now: now)
        }
    }

    // MARK: - Commands

    func setSnowing(_ on: Bool) { snowing = on }

    func setAmount(_ a: SnowAmount) { amount = a }

    func setAccumulateOnWindows(_ on: Bool) { accumulateOnWindows = on }

    func clearSnow() {
        meltUntil = CACurrentMediaTime() + 0.6
    }

    func noteSpaceChange(now: TimeInterval) { graceUntil = now + 0.8 }
}
