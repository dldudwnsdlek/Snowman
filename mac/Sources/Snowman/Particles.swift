import SnowCore
import SpriteKit

/// A falling snowflake or clump of snow.
struct Particle {
    var x: CGFloat
    var y: CGFloat
    var prevY: CGFloat
    var vx: CGFloat
    var vy: CGFloat
    var size: CGFloat
    var swayAmp: CGFloat
    var swayFreq: CGFloat
    var phase: CGFloat
    var area: Float
    var isClump: Bool
    var spin: CGFloat
    var age: CGFloat
}

/// Pools sprite nodes for thousands of particles.
final class ParticleLayer {
    private(set) var particles: [Particle] = []
    private var nodes: [SKSpriteNode] = []
    private var free: [SKSpriteNode] = []
    private unowned let parent: SKNode

    /// Snow area each landed flake adds, relative to its disc area.
    static let accumulation: Float = 0.65

    init(parent: SKNode) { self.parent = parent }

    var count: Int { particles.count }

    private func takeNode(texture: SKTexture) -> SKSpriteNode {
        let node = free.popLast() ?? {
            let n = SKSpriteNode(texture: texture)
            parent.addChild(n)
            return n
        }()
        if node.texture !== texture { node.texture = texture }
        node.isHidden = false
        node.zRotation = 0
        return node
    }

    func spawnFlake(x: CGFloat, y: CGFloat, amount: SnowAmount) {
        let range = amount.sizeRange
        let size = CGFloat.random(in: range)
        let t = (size - range.lowerBound) / max(0.01, range.upperBound - range.lowerBound)
        let p = Particle(x: x, y: y, prevY: y, vx: 0,
                         vy: -(26 + size * 8.5 + CGFloat.random(in: 0...14)),
                         size: size,
                         swayAmp: CGFloat.random(in: 4...16), swayFreq: CGFloat.random(in: 0.5...1.5),
                         phase: CGFloat.random(in: 0...(2 * .pi)),
                         area: Float(.pi * (size / 2) * (size / 2)) * ParticleLayer.accumulation,
                         isClump: false, spin: 0, age: 0)
        let node = takeNode(texture: Textures.flake)
        node.size = CGSize(width: size * 1.5, height: size * 1.5)
        node.alpha = 0.55 + 0.45 * t
        node.zPosition = size < 3 ? 8 : 30
        node.position = CGPoint(x: x, y: y)
        particles.append(p)
        nodes.append(node)
    }

    func spawnClump(x: CGFloat, y: CGFloat, vx: CGFloat, vy: CGFloat, area: Float) {
        let size = min(9, max(2.6, CGFloat(area).squareRoot() * 1.1))
        let p = Particle(x: x, y: y, prevY: y, vx: vx, vy: vy, size: size,
                         swayAmp: 0, swayFreq: 0, phase: 0, area: area, isClump: true,
                         spin: CGFloat.random(in: -6...6), age: 0)
        let node = takeNode(texture: Textures.clump)
        node.size = CGSize(width: size * 1.3, height: size * 1.3)
        node.alpha = 1
        node.zPosition = 31
        node.position = CGPoint(x: x, y: y)
        particles.append(p)
        nodes.append(node)
    }

    /// Moves everything one step. `collide` returns true when the particle landed (it is then removed).
    func update(dt: CGFloat, wind: CGFloat, width: CGFloat, collide: (inout Particle) -> Bool) {
        var i = particles.count - 1
        while i >= 0 {
            var p = particles[i]
            p.prevY = p.y
            p.age += dt
            if p.isClump {
                p.vy = max(p.vy - 900 * dt, -560)
                p.vx -= p.vx * min(1, 0.9 * dt)
                p.x += p.vx * dt
                p.y += p.vy * dt
            } else {
                let sway = p.swayAmp * p.swayFreq * cos(p.swayFreq * p.age + p.phase)
                p.x += (wind * (0.5 + p.size / 8) + sway) * dt
                p.y += p.vy * dt
            }
            if collide(&p) || p.y < -30 || p.x < -120 || p.x > width + 120 {
                remove(at: i)
            } else {
                particles[i] = p
                let node = nodes[i]
                node.position = CGPoint(x: p.x, y: p.y)
                if p.isClump { node.zRotation += p.spin * dt }
            }
            i -= 1
        }
    }

    private func remove(at i: Int) {
        let node = nodes[i]
        node.isHidden = true
        free.append(node)
        particles.swapAt(i, particles.count - 1)
        nodes.swapAt(i, nodes.count - 1)
        particles.removeLast()
        nodes.removeLast()
    }

    func removeAll() {
        while !particles.isEmpty { remove(at: particles.count - 1) }
    }
}
