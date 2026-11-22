import CoreGraphics
import Foundation

/// 눈 양: 조금 / 보통 / 펑펑
public enum SnowAmount: String, CaseIterable, Sendable {
    case light, normal, heavy

    public var flakesPerSecond: Double {
        switch self {
        case .light: return 15
        case .normal: return 45
        case .heavy: return 130
        }
    }

    /// Flake diameter range in points.
    public var sizeRange: ClosedRange<CGFloat> {
        switch self {
        case .light: return 1.6...3.4
        case .normal: return 1.6...4.4
        case .heavy: return 2.0...6.0
        }
    }

    /// Typical sideways drift in pt/s.
    public var windStrength: CGFloat {
        switch self {
        case .light: return 4
        case .normal: return 8
        case .heavy: return 22
        }
    }

    public var title: String {
        switch self {
        case .light: return "조금"
        case .normal: return "보통"
        case .heavy: return "펑펑"
        }
    }
}

/// True when something moving down passes through `surfaceY` during this step.
public func crossed(prevY: CGFloat, newY: CGFloat, surfaceY: CGFloat) -> Bool {
    prevY >= surfaceY && newY < surfaceY
}

public enum SnowballTuning {
    public static let scoopMinimumHeight: Float = 3
    public static let startRadius: CGFloat = 6
    public static let maxRadius: CGFloat = 56
    public static let growthGain: CGFloat = 1.5
}

/// Radius after rolling up `a` pt² of snow.
public func grownRadius(_ r: CGFloat, addingArea a: CGFloat) -> CGFloat {
    let grown = (r * r + SnowballTuning.growthGain * max(0, a) / .pi).squareRoot()
    return min(SnowballTuning.maxRadius, grown)
}

public enum ImpactLevel: Sendable {
    case soft, crash, shatter
}

public enum ThrowTuning {
    public static let crashSpeed: CGFloat = 700
    public static let shatterSpeed: CGFloat = 2200
    public static let wallRestitution: CGFloat = 0.55
    public static let gravity: CGFloat = -1800
}

public func impactLevel(speed: CGFloat) -> ImpactLevel {
    if speed >= ThrowTuning.shatterSpeed { return .shatter }
    if speed >= ThrowTuning.crashSpeed { return .crash }
    return .soft
}

public enum WallSide: Sendable {
    case left, right, top
}

/// Reflects a body off the left, right and top edges of `bounds`.
/// Returns the wall hit and the speed into it, or nil.
public func bounceOffWalls(position: inout CGPoint, velocity: inout CGVector,
                           halfWidth: CGFloat, halfHeight: CGFloat,
                           bounds: CGRect, restitution: CGFloat) -> (side: WallSide, speed: CGFloat)? {
    if position.x - halfWidth < bounds.minX && velocity.dx < 0 {
        let speed = -velocity.dx
        position.x = bounds.minX + halfWidth
        velocity.dx = speed * restitution
        return (.left, speed)
    }
    if position.x + halfWidth > bounds.maxX && velocity.dx > 0 {
        let speed = velocity.dx
        position.x = bounds.maxX - halfWidth
        velocity.dx = -speed * restitution
        return (.right, speed)
    }
    if position.y + halfHeight > bounds.maxY && velocity.dy > 0 {
        let speed = velocity.dy
        position.y = bounds.maxY - halfHeight
        velocity.dy = -speed * restitution
        return (.top, speed)
    }
    return nil
}

/// The resting snowball a dropped ball should stack on, if any.
public func stackCandidate(dropped: (center: CGPoint, radius: CGFloat),
                           resting: [(id: Int, center: CGPoint, radius: CGFloat)]) -> Int? {
    let bottom = dropped.center.y - dropped.radius
    return resting.first { r in
        abs(dropped.center.x - r.center.x) <= 0.75 * r.radius
            && abs(bottom - (r.center.y + r.radius)) <= 12
    }?.id
}

/// The five snowman looks.
public enum SnowmanStyle: Int, CaseIterable, Sendable {
    case santa, beanie, gentleman, earmuffs, elf

    public var title: String {
        switch self {
        case .santa: return "산타"
        case .beanie: return "비니"
        case .gentleman: return "신사"
        case .earmuffs: return "귀마개"
        case .elf: return "요정"
        }
    }
}

/// Deals the five styles in shuffled rounds so every look shows up evenly.
public struct StyleBag {
    private var rng: SeededGenerator
    private var queue: [SnowmanStyle] = []
    private var last: SnowmanStyle?

    public init(seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        rng = SeededGenerator(seed: seed)
    }

    public mutating func next() -> SnowmanStyle {
        if queue.isEmpty {
            var round = SnowmanStyle.allCases.shuffled(using: &rng)
            if round.first == last, round.count > 1 { round.swapAt(0, round.count - 1) }
            queue = round
        }
        let style = queue.removeFirst()
        last = style
        return style
    }
}

/// Small deterministic RNG (SplitMix64) for reproducible art and tests.
public struct SeededGenerator: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed &+ 0x9E37_79B9_7F4A_7C15 }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    public mutating func unit() -> CGFloat { CGFloat(Double(next() >> 11) / Double(1 << 53)) }
    public mutating func range(_ r: ClosedRange<CGFloat>) -> CGFloat { r.lowerBound + (r.upperBound - r.lowerBound) * unit() }
}
