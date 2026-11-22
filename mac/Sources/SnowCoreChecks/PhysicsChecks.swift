import CoreGraphics
import SnowCore

private func groundPile(height: Float, around x: CGFloat, dock: CGRect? = nil) -> (spec: LedgeSpec, pile: SnowPile, vis: Visibility) {
    let specs = buildLedgeSpecs(windowFrames: [], dockFrame: dock, sceneSize: CGSize(width: 1512, height: 982),
                                menuBarHeight: 33, includeWindows: true)
    let g = specs.first { $0.kind == .ground }!
    var p = SnowPile(width: g.width, maxHeight: g.maxHeight)
    for px in stride(from: x - 40, through: x + 40, by: SnowPile.columnWidth) {
        p.add(atLocalX: px, area: height * Float(SnowPile.columnWidth))
    }
    return (g, p, visibility(for: g, columnCount: p.columnCount))
}

func runPhysicsChecks() {
    do { // snowAmountRates
        check("snowAmountRates", SnowAmount.light.flakesPerSecond == 15 && SnowAmount.normal.flakesPerSecond == 45 && SnowAmount.heavy.flakesPerSecond == 130)
        check("snowAmountTitles", SnowAmount.allCases.map(\.title) == ["조금", "보통", "펑펑"])
    }
    do { // crossingDetected
        check("crossingDetected.cross", crossed(prevY: 10, newY: 8, surfaceY: 9))
        check("crossingDetected.above", !crossed(prevY: 10, newY: 9.5, surfaceY: 9))
        check("crossingDetected.fromSurface", crossed(prevY: 9, newY: 8, surfaceY: 9))
        check("crossingDetected.below", !crossed(prevY: 8, newY: 7, surfaceY: 9))
    }
    do { // radiusGrowsAndCaps
        checkClose("radiusGrows", Double(grownRadius(6, addingArea: 100)), (36 + 150 / Double.pi).squareRoot(), tol: 0.001)
        check("radiusCaps", grownRadius(6, addingArea: 1_000_000) == 56)
    }
    do { // impactThresholds
        check("impact.soft", impactLevel(speed: 699) == .soft)
        check("impact.crash", impactLevel(speed: 700) == .crash && impactLevel(speed: 2199) == .crash)
        check("impact.shatter", impactLevel(speed: 2200) == .shatter)
    }
    let bounds = CGRect(x: 0, y: 0, width: 1512, height: 982)
    do { // bounceFlipsVelocity
        var p = CGPoint(x: 5, y: 500), v = CGVector(dx: -1000, dy: 0)
        let hit = bounceOffWalls(position: &p, velocity: &v, halfWidth: 20, halfHeight: 30, bounds: bounds, restitution: 0.55)
        check("bounce.left.side", hit?.side == .left && hit?.speed == 1000)
        checkClose("bounce.left.vx", Double(v.dx), 550, tol: 0.001)
        check("bounce.left.clamped", p.x == 20)
    }
    do {
        var p = CGPoint(x: 1500, y: 500), v = CGVector(dx: 800, dy: 0)
        let hit = bounceOffWalls(position: &p, velocity: &v, halfWidth: 20, halfHeight: 30, bounds: bounds, restitution: 0.55)
        check("bounce.right", hit?.side == .right && abs(v.dx + 440) < 0.001 && p.x == 1492)
    }
    do {
        var p = CGPoint(x: 700, y: 975), v = CGVector(dx: 0, dy: 600)
        let hit = bounceOffWalls(position: &p, velocity: &v, halfWidth: 20, halfHeight: 30, bounds: bounds, restitution: 0.55)
        check("bounce.top", hit?.side == .top && abs(v.dy + 330) < 0.001 && p.y == 952)
    }
    do {
        var p = CGPoint(x: 700, y: 500), v = CGVector(dx: 300, dy: 300)
        let hit = bounceOffWalls(position: &p, velocity: &v, halfWidth: 20, halfHeight: 30, bounds: bounds, restitution: 0.55)
        check("bounce.none", hit == nil && v.dx == 300)
    }
    do { // stackDetection
        let resting = [(id: 3, center: CGPoint(x: 500, y: 40), radius: CGFloat(30))]
        check("stack.aligned", stackCandidate(dropped: (CGPoint(x: 510, y: 90), 20), resting: resting) == 3)
        check("stack.offside", stackCandidate(dropped: (CGPoint(x: 540, y: 90), 20), resting: resting) == nil)
        check("stack.tooHigh", stackCandidate(dropped: (CGPoint(x: 500, y: 120), 20), resting: resting) == nil)
    }
    do { // styleBagCoversAllFive
        var bag = StyleBag(seed: 7)
        let first = (0..<5).map { _ in bag.next() }
        check("styleBag.firstCycle", Set(first) == Set(SnowmanStyle.allCases))
        let second = (0..<5).map { _ in bag.next() }
        check("styleBag.secondCycle", Set(second) == Set(SnowmanStyle.allCases))
        check("styleTitles", SnowmanStyle.allCases.map(\.title) == ["산타", "비니", "신사", "귀마개", "요정"])
    }
    do { // hitTestIgnoresThinAndHiddenSnow
        let thin = groundPile(height: 2, around: 100)
        check("hit.thinSnow", hitTest(point: CGPoint(x: 100, y: 1), snowmen: [], balls: [], piles: [thin]) == nil)
        let deep = groundPile(height: 6, around: 100)
        check("hit.deepSnow", hitTest(point: CGPoint(x: 100, y: 3), snowmen: [], balls: [], piles: [deep]) == .pile(.ground, localX: 100))
        check("hit.aboveSnow", hitTest(point: CGPoint(x: 100, y: 20), snowmen: [], balls: [], piles: [deep]) == nil)
        // the window's own top edge (resize zone) stays clickable
        check("hit.edgeStripFree", hitTest(point: CGPoint(x: 100, y: 0.5), snowmen: [], balls: [], piles: [deep]) == nil)
        let hidden = groundPile(height: 6, around: 800, dock: CGRect(x: 300, y: 0, width: 900, height: 64))
        check("hit.hiddenSnow", hitTest(point: CGPoint(x: 800, y: 3), snowmen: [], balls: [], piles: [hidden]) == nil)
    }
    do { // hitPriority
        let deep = groundPile(height: 6, around: 100)
        let snowmen = [(id: 9, frame: CGRect(x: 80, y: 0, width: 40, height: 80))]
        let balls = [(id: 4, center: CGPoint(x: 100, y: 10), radius: CGFloat(8))]
        check("hit.snowmanFirst", hitTest(point: CGPoint(x: 100, y: 3), snowmen: snowmen, balls: balls, piles: [deep]) == .snowman(9))
        check("hit.ballBeforePile", hitTest(point: CGPoint(x: 100, y: 3), snowmen: [], balls: balls, piles: [deep]) == .snowball(4))
    }
}
