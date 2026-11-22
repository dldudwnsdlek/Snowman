import SnowCore
import SpriteKit
import WinterArt

/// The orange snowplow: body, two spinning wheels, a blinking beacon and the snow mound it pushes.
final class SnowplowNode: SKNode {
    let ledgeKind: LedgeKind
    let s: CGFloat
    var driveSpeed: CGFloat = 230
    /// Snow collected in front of the blade (pt²).
    var collected: Float = 0
    var finished = false
    var falling = false
    var fallVelocity: CGFloat = 0
    var hopped = Set<Int>()

    private let wheels: [SKSpriteNode]
    private let glow: SKSpriteNode
    let mound: SKSpriteNode

    init(ledgeKind: LedgeKind, scale: CGFloat) {
        self.ledgeKind = ledgeKind
        self.s = scale
        let size = SpriteArt.plowSize
        wheels = SpriteArt.plowWheelCenters.map { c in
            let w = SKSpriteNode(texture: Textures.plowWheel, size: CGSize(width: 24, height: 24))
            w.position = c
            w.zPosition = 0.02
            return w
        }
        glow = SKSpriteNode(texture: Textures.beaconGlow, size: CGSize(width: 34, height: 34))
        mound = SKSpriteNode(texture: Textures.snowball, size: CGSize(width: 2, height: 2))
        super.init()
        setScale(scale)
        zPosition = 25
        let body = SKSpriteNode(texture: Textures.plow, size: size)
        body.anchorPoint = .zero
        body.zPosition = 0.01
        addChild(body)
        wheels.forEach(addChild)
        let beacon = SKSpriteNode(texture: Textures.plowBeacon, size: CGSize(width: 12, height: 10))
        beacon.anchorPoint = CGPoint(x: 0.5, y: 0)
        beacon.position = SpriteArt.plowBeaconPosition
        beacon.zPosition = 0.03
        addChild(beacon)
        glow.position = CGPoint(x: SpriteArt.plowBeaconPosition.x, y: SpriteArt.plowBeaconPosition.y + 5)
        glow.zPosition = 0.04
        glow.blendMode = .add
        addChild(glow)
        mound.anchorPoint = CGPoint(x: 0, y: 0.08)
        mound.position = CGPoint(x: SpriteArt.plowBladeFront - 6, y: 0)
        mound.zPosition = 0.05
        mound.isHidden = true
        addChild(mound)
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Scene x of the blade's front edge.
    var bladeX: CGFloat { position.x + SpriteArt.plowBladeFront * s }
    var width: CGFloat { SpriteArt.plowSize.width * s }

    func animate(t: CGFloat, distance: CGFloat) {
        for w in wheels { w.zRotation -= distance / (11 * s) }
        glow.alpha = 0.35 + 0.65 * max(0, sin(t * 9))
        let r = min(34, 3 + CGFloat(collected).squareRoot() * 0.55)
        mound.isHidden = collected < 4
        mound.size = CGSize(width: r * 2.1 / s, height: r * 1.25 / s)
    }
}
