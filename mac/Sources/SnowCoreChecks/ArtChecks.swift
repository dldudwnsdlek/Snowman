import CoreGraphics
import SnowCore
import WinterArt

func opaqueFraction(_ img: CGImage) -> Double {
    let w = img.width, h = img.height
    var data = [UInt8](repeating: 0, count: w * h * 4)
    let ok: Bool = data.withUnsafeMutableBytes { buf in
        guard let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return false }
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
        return true
    }
    guard ok else { return 0 }
    var count = 0
    for i in stride(from: 3, to: data.count, by: 4) where data[i] > 10 { count += 1 }
    return Double(count) / Double(w * h)
}

func runArtChecks() {
    let required: Set<SnowmanPart> = [.body, .head, .leftArm, .rightArm, .eyes, .eyesClosed, .nose, .mouth, .scarf, .scarfTail, .hat]
    for style in SnowmanStyle.allCases {
        let parts = SnowmanArt.parts(for: style)
        check("spritesRender.\(style).hasCoreParts", required.isSubset(of: Set(parts)), "parts \(parts)")
        for part in parts {
            guard let img = SnowmanArt.part(part, style: style, scale: 2) else {
                check("spritesRender.\(style).\(part).exists", false); continue
            }
            check("spritesRender.\(style).\(part).opaque", opaqueFraction(img.image) > 0.01)
        }
        let whole = SnowmanArt.composite(style: style, height: 120, scale: 2)
        check("spritesRender.\(style).composite", opaqueFraction(whole) > 0.15)
    }
    let sprites: [(String, CGImage)] = [
        ("flake", SpriteArt.flake(diameter: 8, scale: 2)),
        ("clump", SpriteArt.clump(diameter: 10, scale: 2)),
        ("mitten", SpriteArt.mitten(size: 28, scale: 2)),
        ("snowball", SpriteArt.snowball(radius: 30, scale: 2)),
        ("plow", SpriteArt.plow(scale: 2)),
        ("plowWheel", SpriteArt.plowWheel(scale: 2)),
        ("plowBeacon", SpriteArt.plowBeacon(scale: 2)),
        ("puff", SpriteArt.puff(scale: 2)),
        ("sparkle", SpriteArt.sparkle(scale: 2)),
    ]
    for (name, img) in sprites { check("spritesRender.\(name)", opaqueFraction(img) > 0.02) }
    let icon = IconArt.appIcon(pixels: 1024)
    check("appIconSize", icon.width == 1024 && icon.height == 1024)
}
