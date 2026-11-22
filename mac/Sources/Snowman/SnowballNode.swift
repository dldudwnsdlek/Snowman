import SnowCore
import SpriteKit

/// Where a resting object sits: a ledge and a position along it.
struct Support: Equatable {
    var kind: LedgeKind
    var localX: CGFloat
}

/// A snowball that can be rolled, carried, thrown and stacked.
final class SnowballNode: SKSpriteNode {
    enum State { case rolling, carried, falling, resting }

    let id: Int
    var state: State = .resting
    var velocity = CGVector.zero
    var support: Support?
    var radius: CGFloat {
        didSet { applyRadius() }
    }

    /// The texture is a 60pt-radius ball with a 2pt margin.
    private static let textureRatio: CGFloat = 124.0 / 60.0

    init(id: Int, radius: CGFloat) {
        self.id = id
        self.radius = radius
        super.init(texture: Textures.snowball, color: .white, size: .zero)
        zPosition = 19
        applyRadius()
    }

    required init?(coder: NSCoder) { fatalError("not used") }

    private func applyRadius() {
        let d = radius * SnowballNode.textureRatio
        size = CGSize(width: d, height: d)
    }

    /// Rolls the ball by `dx` points (visual spin only).
    func roll(by dx: CGFloat) {
        zRotation -= dx / max(radius, 1)
    }
}
