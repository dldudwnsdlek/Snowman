import AppKit
import SpriteKit

/// Short-lived visual effects.
enum Effects {
    static func puff(in parent: SKNode, at p: CGPoint, size: CGFloat = 36) {
        let n = SKSpriteNode(texture: Textures.puff, size: CGSize(width: size, height: size))
        n.position = p
        n.zPosition = 40
        n.setScale(0.4)
        n.alpha = 0.95
        n.zRotation = CGFloat.random(in: 0...(2 * .pi))
        parent.addChild(n)
        n.run(SKAction.sequence([
            SKAction.group([SKAction.scale(to: 1.5, duration: 0.45), SKAction.fadeOut(withDuration: 0.45)]),
            SKAction.removeFromParent(),
        ]))
    }

    static func sparkles(in parent: SKNode, around c: CGPoint, radius: CGFloat, count: Int) {
        for i in 0..<count {
            let a = CGFloat(i) / CGFloat(count) * 2 * .pi + CGFloat.random(in: 0...0.6)
            let d = radius * CGFloat.random(in: 0.6...1.15)
            let size = 15 * CGFloat.random(in: 0.7...1.3)
            let n = SKSpriteNode(texture: Textures.sparkle, size: CGSize(width: size, height: size))
            n.position = CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d)
            n.zPosition = 41
            n.setScale(0)
            n.zRotation = CGFloat.random(in: 0...1)
            parent.addChild(n)
            n.run(SKAction.sequence([
                SKAction.wait(forDuration: Double(i) * 0.04),
                SKAction.group([SKAction.scale(to: 1, duration: 0.16), SKAction.rotate(byAngle: 1.2, duration: 0.6)]),
                SKAction.group([SKAction.scale(to: 0, duration: 0.3), SKAction.fadeOut(withDuration: 0.3)]),
                SKAction.removeFromParent(),
            ]))
        }
    }

    static func crashText(in parent: SKNode, at p: CGPoint, text: String = "와장창!", size: CGFloat = 30) {
        let label = SKLabelNode()
        let font = NSFont(name: "AppleSDGothicNeo-Heavy", size: size) ?? NSFont.systemFont(ofSize: size, weight: .black)
        label.attributedText = NSAttributedString(string: text, attributes: [
            .font: font,
            .foregroundColor: NSColor.white,
            .strokeColor: NSColor(calibratedRed: 0.17, green: 0.32, blue: 0.72, alpha: 1),
            .strokeWidth: -4.5,
        ])
        label.verticalAlignmentMode = .center
        label.horizontalAlignmentMode = .center
        if let scene = parent.scene {
            let w = scene.size.width, h = scene.size.height
            label.position = CGPoint(x: min(max(p.x, 80), w - 80), y: min(max(p.y, 40), h - 70))
        } else {
            label.position = p
        }
        label.zPosition = 45
        label.setScale(0.3)
        label.zRotation = CGFloat.random(in: -0.18...0.18)
        parent.addChild(label)
        label.run(SKAction.sequence([
            SKAction.scale(to: 1.25, duration: 0.12),
            SKAction.scale(to: 1.0, duration: 0.08),
            SKAction.group([
                SKAction.moveBy(x: 0, y: 34, duration: 0.8),
                SKAction.sequence([SKAction.wait(forDuration: 0.45), SKAction.fadeOut(withDuration: 0.35)]),
            ]),
            SKAction.removeFromParent(),
        ]))
    }

    /// A piece of a broken snowman flying away and fading.
    static func debris(in parent: SKNode, texture: SKTexture?, size: CGSize, at p: CGPoint,
                       velocity: CGVector, spin: CGFloat, scale: CGFloat, rotation: CGFloat) {
        guard let texture else { return }
        let n = SKSpriteNode(texture: texture, size: size)
        n.setScale(scale)
        n.position = p
        n.zRotation = rotation
        n.zPosition = 39
        let body = SKPhysicsBody(circleOfRadius: max(2, min(size.width, size.height) * scale * 0.3))
        body.velocity = velocity
        body.angularVelocity = spin
        body.collisionBitMask = 0
        body.contactTestBitMask = 0
        body.categoryBitMask = 0
        body.linearDamping = 0.15
        n.physicsBody = body
        parent.addChild(n)
        n.run(SKAction.sequence([
            SKAction.wait(forDuration: 0.9),
            SKAction.fadeOut(withDuration: 0.5),
            SKAction.removeFromParent(),
        ]))
    }
}

extension SKAction {
    /// Sets the timing curve and returns the action, for inline use.
    func withTiming(_ mode: SKActionTimingMode) -> SKAction {
        timingMode = mode
        return self
    }
}
