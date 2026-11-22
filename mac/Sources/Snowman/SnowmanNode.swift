import SnowCore
import SpriteKit
import WinterArt

/// A living snowman built from the WinterArt parts. Its position is the ground contact point.
final class SnowmanNode: SKNode {
    enum State { case building, idle, dragged, flying }

    let id: Int
    let style: SnowmanStyle
    /// Body radius / 30 (reference body radius).
    let s: CGFloat
    let rig = SKNode()
    let upper = SKNode()
    private(set) var sprites: [SnowmanPart: SKSpriteNode] = [:]

    var state: State = .building
    var velocity = CGVector.zero
    var spin: CGFloat = 0
    var support: Support?
    /// Rotation of the whole figure around its middle (tilt while dragged, spin while flying, wobble).
    var angle: CGFloat = 0
    var angleVelocity: CGFloat = 0
    /// Where the mouse wants the feet to be while dragged.
    var dragTarget = CGPoint.zero
    var danceAfterLanding = false

    private static let neck = CGPoint(x: 0, y: 50)
    private static let pivot = CGPoint(x: 0, y: 45)
    private static let upperParts: Set<SnowmanPart> = [.head, .eyes, .eyesClosed, .nose, .mouth, .cheeks, .hat]

    private let phase = CGFloat.random(in: 0...10)
    private var nextBlink: CGFloat = 0
    private var blinkUntil: CGFloat = 0
    private var waveStart: CGFloat = -10
    private var waveUntil: CGFloat = 0
    private var nextWave: CGFloat = 0
    private var danceStart: CGFloat = -10
    private var danceUntil: CGFloat = 0
    private var nextDance: CGFloat = 0
    private var started = false

    init(id: Int, style: SnowmanStyle, bodyRadius: CGFloat) {
        self.id = id
        self.style = style
        self.s = max(0.3, bodyRadius / SnowmanArt.bodyRadius)
        super.init()
        setScale(s)
        zPosition = 20 + CGFloat(id % 40) * 0.1
        addChild(rig)
        rig.addChild(upper)
        upper.position = SnowmanNode.neck
        for (part, entry) in Textures.parts(for: style) {
            let (texture, img) = entry
            let sprite = SKSpriteNode(texture: texture, size: img.size)
            sprite.anchorPoint = img.anchor
            sprite.zPosition = img.z * 0.01
            if SnowmanNode.upperParts.contains(part) {
                sprite.position = CGPoint(x: img.position.x - SnowmanNode.neck.x, y: img.position.y - SnowmanNode.neck.y)
                upper.addChild(sprite)
            } else {
                sprite.position = img.position
                rig.addChild(sprite)
            }
            sprites[part] = sprite
        }
        sprites[.eyesClosed]?.isHidden = true
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    /// Hit box in scene coordinates.
    var hitFrame: CGRect {
        CGRect(x: position.x - 34 * s, y: position.y, width: 68 * s, height: 112 * s)
    }

    var center: CGPoint { CGPoint(x: position.x, y: position.y + 50 * s) }
    var halfWidth: CGFloat { 30 * s }
    var halfHeight: CGFloat { 55 * s }

    // MARK: - Building

    /// Hides everything except the two balls, then adds the pieces one by one.
    func playBuildSequence(in scene: SKScene, completion: @escaping () -> Void) {
        state = .building
        let order: [[SnowmanPart]] = [[.leftArm, .rightArm], [.eyes], [.nose], [.mouth, .cheeks], [.buttons, .scarf, .scarfTail], [.hat]]
        for group in order { for p in group { sprites[p]?.isHidden = true } }
        var actions: [SKAction] = [SKAction.run { [weak self, weak scene] in
            guard let self, let scene else { return }
            Effects.sparkles(in: scene, around: self.center, radius: 50 * self.s, count: 7)
            Sound.play(.tink)
        }, SKAction.wait(forDuration: 0.3)]
        for group in order {
            actions.append(SKAction.run { [weak self] in
                guard let self else { return }
                for part in group { self.pop(part) }
                Sound.play(.pop, volume: 0.25)
            })
            actions.append(SKAction.wait(forDuration: 0.3))
        }
        actions.append(SKAction.run { [weak self, weak scene] in
            guard let self, let scene else { return }
            self.state = .idle
            Effects.sparkles(in: scene, around: CGPoint(x: self.position.x, y: self.position.y + 100 * self.s),
                             radius: 30 * self.s, count: 5)
            Sound.play(.done, volume: 0.3)
            self.danceSoon = true
            completion()
        })
        run(SKAction.sequence(actions), withKey: "build")
    }

    private func pop(_ part: SnowmanPart) {
        if part == .eyes { eyesShown = true }
        guard let sprite = sprites[part] else { return }
        sprite.removeAllActions()
        if part == .hat {
            let rest = sprite.position
            sprite.position = CGPoint(x: rest.x, y: rest.y + 46)
            sprite.alpha = 0
            sprite.isHidden = false
            sprite.run(SKAction.group([
                SKAction.fadeIn(withDuration: 0.12),
                SKAction.sequence([
                    SKAction.move(to: rest, duration: 0.22).withTiming(.easeIn),
                    SKAction.moveBy(x: 0, y: 4, duration: 0.07),
                    SKAction.moveBy(x: 0, y: -4, duration: 0.07),
                ]),
            ]))
        } else {
            sprite.setScale(0)
            sprite.isHidden = false
            sprite.run(SKAction.sequence([
                SKAction.scale(to: 1.25, duration: 0.12).withTiming(.easeOut),
                SKAction.scale(to: 1.0, duration: 0.09),
            ]))
        }
    }

    /// Shows every part immediately (used when restoring or skipping the build).
    func finishInstantly() {
        removeAction(forKey: "build")
        for (part, sprite) in sprites where part != .eyesClosed { sprite.isHidden = false; sprite.setScale(1); sprite.alpha = 1 }
        eyesShown = true
        state = .idle
    }

    // MARK: - Life

    func wave(at t: CGFloat) {
        guard t > waveUntil + 1.5 else { return }
        waveStart = t
        waveUntil = t + 1.6
    }

    func dance(at t: CGFloat) {
        danceStart = t
        danceUntil = t + 3.0
    }

    private var danceSoon = false
    private var eyesShown = false

    /// Breathing, blinking, waving, dancing and wobble. `mouse` is in scene coordinates.
    func animate(t: CGFloat, dt: CGFloat, mouse: CGPoint?) {
        if !started {
            started = true
            nextBlink = t + CGFloat.random(in: 1...4)
            nextWave = t + CGFloat.random(in: 4...10)
            nextDance = t + CGFloat.random(in: 14...28)
        }
        if danceSoon { danceStart = t; danceUntil = t + 2.4; danceSoon = false }
        let breath = sin((t + phase) * 2 * .pi / 2.8)
        rig.yScale = 1 + 0.024 * breath
        rig.xScale = 1 - 0.01 * breath
        upper.position.y = SnowmanNode.neck.y + 0.9 * breath

        if t > nextBlink {
            blinkUntil = t + 0.13
            nextBlink = t + CGFloat.random(in: 2...6)
        }
        let closed = t < blinkUntil && style != .elf
        sprites[.eyes]?.isHidden = !eyesShown || closed
        sprites[.eyesClosed]?.isHidden = !eyesShown || !closed

        guard state == .idle else {
            sprites[.leftArm]?.zRotation = state == .flying ? 0.5 * sin(t * 18) : 0.25
            sprites[.rightArm]?.zRotation = state == .flying ? -0.5 * sin(t * 18) : -0.25
            applyAngle(hop: 0)
            return
        }
        if let m = mouse, hypot(m.x - center.x, m.y - center.y) < 150 * max(1, s) { wave(at: t) }
        if t > nextWave { wave(at: t); nextWave = t + CGFloat.random(in: 7...14) }
        if t > nextDance { dance(at: t); nextDance = t + CGFloat.random(in: 16...32) }

        var left = 0.05 * sin(t * 1.3 + phase)
        var right = -0.05 * sin(t * 1.3 + phase)
        var hop: CGFloat = 0
        if t < danceUntil {
            let k = t - danceStart
            let beat = sin(k * 8)
            angle = beat * 0.15
            angleVelocity = 0
            hop = abs(sin(k * 8)) * 7
            left = -0.45 + beat * 0.55
            right = 0.45 + beat * 0.55
        } else {
            // damped spring back to upright
            angleVelocity += (-60 * angle - 9 * angleVelocity) * dt
            angle += angleVelocity * dt
        }
        if t < waveUntil {
            let k = t - waveStart
            right = 0.6 + sin(k * 13) * 0.4
        }
        sprites[.leftArm]?.zRotation = left
        sprites[.rightArm]?.zRotation = right
        if let tail = sprites[.scarfTail] { tail.zRotation = 0.08 * sin(t * 2.1 + phase) - angle * 0.5 }
        applyAngle(hop: hop)
    }

    /// Rotates around the body's middle instead of the feet.
    func applyAngle(hop: CGFloat) {
        rig.zRotation = angle
        let p = SnowmanNode.pivot
        rig.position = CGPoint(x: p.x - (p.x * cos(angle) - p.y * sin(angle)),
                               y: p.y - (p.x * sin(angle) + p.y * cos(angle)) + hop)
    }

    /// Normalises the angle after a spin so the wobble settles the short way round.
    func settleUpright() {
        var a = angle.truncatingRemainder(dividingBy: 2 * .pi)
        if a > .pi { a -= 2 * .pi }
        if a < -.pi { a += 2 * .pi }
        angle = a
        angleVelocity = 0
    }
}
