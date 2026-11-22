import SnowCore
import SpriteKit
import WinterArt

/// Every sprite texture, drawn once by WinterArt.
enum Textures {
    static let scale: CGFloat = max(2, NSScreen.screens.map(\.backingScaleFactor).max() ?? 2)

    static let flake = SKTexture(cgImage: SpriteArt.flake(diameter: 10, scale: scale))
    static let clump = SKTexture(cgImage: SpriteArt.clump(diameter: 12, scale: scale))
    static let mitten = SKTexture(cgImage: SpriteArt.mitten(size: 30, scale: scale))
    static let snowball = SKTexture(cgImage: SpriteArt.snowball(radius: 60, scale: scale))
    static let plow = SKTexture(cgImage: SpriteArt.plow(scale: scale))
    static let plowWheel = SKTexture(cgImage: SpriteArt.plowWheel(scale: scale))
    static let plowBeacon = SKTexture(cgImage: SpriteArt.plowBeacon(scale: scale))
    static let beaconGlow = SKTexture(cgImage: SpriteArt.glow(radius: 16, color: 0xFFB703, scale: scale))
    static let puff = SKTexture(cgImage: SpriteArt.puff(scale: scale))
    static let sparkle = SKTexture(cgImage: SpriteArt.sparkle(scale: scale))

    private static var partCache: [SnowmanStyle: [SnowmanPart: (SKTexture, PartImage)]] = [:]

    /// Parts drawn at 2.2× reference size so snowmen up to that scale stay crisp.
    static func parts(for style: SnowmanStyle) -> [SnowmanPart: (SKTexture, PartImage)] {
        if let cached = partCache[style] { return cached }
        var result: [SnowmanPart: (SKTexture, PartImage)] = [:]
        for part in SnowmanArt.parts(for: style) {
            if let p = SnowmanArt.part(part, style: style, scale: scale * 2.2) {
                result[part] = (SKTexture(cgImage: p.image), p)
            }
        }
        partCache[style] = result
        return result
    }
}
