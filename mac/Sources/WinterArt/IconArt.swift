import CoreGraphics
import Foundation
import SnowCore

public enum IconArt {
    /// macOS app icon: night-sky squircle, falling snow, a hill and a beanie snowman.
    public static func appIcon(pixels n: Int) -> CGImage {
        let ctx = Canvas.context(width: n, height: n)
        let u = CGFloat(n) / 1024
        let tile = CGRect(x: 100 * u, y: 100 * u, width: 824 * u, height: 824 * u)
        let shape = CGPath(roundedRect: tile, cornerWidth: 185 * u, cornerHeight: 185 * u, transform: nil)

        ctx.saveGState()
        ctx.setShadow(offset: CGSize(width: 0, height: -10 * u), blur: 28 * u, color: hex(0x000000, 0.35))
        ctx.fill(shape, hex(0x0E2357))
        ctx.restoreGState()

        ctx.clipped(to: shape) {
            ctx.fillLinear([hex(0x081536), hex(0x15306B), hex(0x3F6DB3), hex(0x86A9DC)], [0, 0.45, 0.8, 1],
                           from: CGPoint(x: 0, y: tile.maxY), to: CGPoint(x: 0, y: tile.minY))
            // moon
            let moon = CGPoint(x: tile.minX + 640 * u, y: tile.minY + 660 * u)
            ctx.fillRadial([hex(0xFFF4C8, 0.5), hex(0xFFF4C8, 0)], center: moon, radius: 150 * u, extend: false)
            ctx.fill(circlePath(moon, 62 * u), hex(0xFFF6D6))
            // snow
            var rng = SeededGenerator(seed: 2026)
            for _ in 0..<70 {
                let p = CGPoint(x: tile.minX + rng.unit() * tile.width, y: tile.minY + rng.range(0.25...1) * tile.height)
                let r = rng.range(2.5...8) * u
                ctx.fillRadial([hex(0xFFFFFF, rng.range(0.6...1)), hex(0xFFFFFF, 0)], [0.45, 1], center: p, radius: r, extend: false)
            }
            // hills
            let back = CGMutablePath()
            back.move(to: CGPoint(x: tile.minX, y: tile.minY + 250 * u))
            back.addCurve(to: CGPoint(x: tile.maxX, y: tile.minY + 300 * u),
                          control1: CGPoint(x: tile.minX + 260 * u, y: tile.minY + 360 * u),
                          control2: CGPoint(x: tile.minX + 560 * u, y: tile.minY + 200 * u))
            back.addLine(to: CGPoint(x: tile.maxX, y: tile.minY))
            back.addLine(to: CGPoint(x: tile.minX, y: tile.minY))
            back.closeSubpath()
            ctx.fill(back, hex(0xC2D4EE))
            let front = CGMutablePath()
            front.move(to: CGPoint(x: tile.minX, y: tile.minY + 170 * u))
            front.addCurve(to: CGPoint(x: tile.maxX, y: tile.minY + 200 * u),
                           control1: CGPoint(x: tile.minX + 300 * u, y: tile.minY + 260 * u),
                           control2: CGPoint(x: tile.minX + 600 * u, y: tile.minY + 140 * u))
            front.addLine(to: CGPoint(x: tile.maxX, y: tile.minY))
            front.addLine(to: CGPoint(x: tile.minX, y: tile.minY))
            front.closeSubpath()
            ctx.clipped(to: front) {
                ctx.fillLinear([hex(0xFFFFFF), hex(0xDCE7F7)], from: CGPoint(x: 0, y: tile.minY + 240 * u), to: CGPoint(x: 0, y: tile.minY))
            }
            // snowman
            let man = SnowmanArt.composite(style: .beanie, height: 560 * u, scale: 1)
            let w = CGFloat(man.width), h = CGFloat(man.height)
            ctx.saveGState()
            ctx.setShadow(offset: CGSize(width: 0, height: -6 * u), blur: 18 * u, color: hex(0x0B1B45, 0.35))
            ctx.draw(man, in: CGRect(x: tile.midX - w / 2 + 10 * u, y: tile.minY + 150 * u, width: w, height: h))
            ctx.restoreGState()
        }
        ctx.stroke(shape, hex(0xFFFFFF, 0.08), width: 2 * u)
        return ctx.makeImage()!
    }
}
