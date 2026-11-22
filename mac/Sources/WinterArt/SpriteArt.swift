import CoreGraphics
import Foundation
import SnowCore

/// Small sprites used by the overlay.
public enum SpriteArt {
    /// Soft round snowflake.
    public static func flake(diameter d: CGFloat, scale: CGFloat) -> CGImage {
        Canvas.image(size: CGSize(width: d, height: d), scale: scale) { ctx in
            let c = CGPoint(x: d / 2, y: d / 2)
            ctx.fillRadial([hex(0xFFFFFF, 1), hex(0xFFFFFF, 0.9), hex(0xF0F6FF, 0.35), hex(0xFFFFFF, 0)], [0, 0.35, 0.7, 1],
                           center: c, radius: d / 2, extend: false)
        }
    }

    /// A lump of fallen snow (window snow shaken off, plow spill).
    public static func clump(diameter d: CGFloat, scale: CGFloat) -> CGImage {
        Canvas.image(size: CGSize(width: d, height: d), scale: scale) { ctx in
            let blobs: [(CGFloat, CGFloat, CGFloat)] = [(0.42, 0.45, 0.30), (0.62, 0.52, 0.26), (0.5, 0.66, 0.22), (0.34, 0.6, 0.18)]
            for (x, y, r) in blobs {
                let c = CGPoint(x: x * d, y: y * d)
                ctx.fill(circlePath(c, r * d), hex(0xFFFFFF))
                ctx.clipped(to: circlePath(c, r * d)) {
                    ctx.fillRadial([hex(0xFFFFFF, 0), hex(0xB8C9E3, 0.7)], [0.4, 1], center: c, radius: r * d,
                                   startCenter: CGPoint(x: c.x - r * d * 0.35, y: c.y + r * d * 0.35))
                }
            }
        }
    }

    /// Green knitted mitten shown next to the cursor over snow.
    public static func mitten(size s: CGFloat, scale: CGFloat) -> CGImage {
        Canvas.image(size: CGSize(width: s, height: s), scale: scale) { ctx in
            ctx.scaleBy(x: s / 28, y: s / 28)
            ctx.translateBy(x: 14, y: 14)
            ctx.rotate(by: -0.35)
            ctx.translateBy(x: -14, y: -14)
            let green = hex(0x2FB36A)
            let edge = hex(0x1C7444)
            let thumb = ellipsePath(CGPoint(x: 7.4, y: 13.5), rx: 3.4, ry: 5.6)
            ctx.saveGState()
            ctx.translateBy(x: 7.4, y: 13.5); ctx.rotate(by: 0.55); ctx.translateBy(x: -7.4, y: -13.5)
            ctx.fill(thumb, green)
            ctx.stroke(thumb, edge, width: 0.9)
            ctx.restoreGState()
            let palm = CGMutablePath()
            palm.addRoundedRect(in: CGRect(x: 8.5, y: 7, width: 12.5, height: 18.5), cornerWidth: 6.2, cornerHeight: 6.2)
            ctx.fill(palm, green)
            ctx.clipped(to: palm) {
                for row in 0..<5 {
                    let y = 10 + CGFloat(row) * 3.2
                    for col in 0..<3 {
                        let x = 11 + CGFloat(col) * 3.4
                        let v = CGMutablePath()
                        v.move(to: CGPoint(x: x - 1.1, y: y + 1.2)); v.addLine(to: CGPoint(x: x, y: y)); v.addLine(to: CGPoint(x: x + 1.1, y: y + 1.2))
                        ctx.stroke(v, hex(0xFFFFFF, 0.25), width: 0.6)
                    }
                }
                ctx.fillRadial([hex(0xFFFFFF, 0.3), hex(0xFFFFFF, 0)], center: CGPoint(x: 12, y: 21), radius: 7)
            }
            ctx.stroke(palm, edge, width: 0.9)
            let cuff = CGPath(roundedRect: CGRect(x: 7.8, y: 2.5, width: 14, height: 6), cornerWidth: 2, cornerHeight: 2, transform: nil)
            ctx.fill(cuff, hex(0xF7F9FC))
            ctx.clipped(to: cuff) {
                for x in stride(from: CGFloat(9), to: 22, by: 2) {
                    ctx.setFillColor(hex(0xC9D3E3)); ctx.fill(CGRect(x: x, y: 2.5, width: 0.7, height: 6))
                }
            }
            ctx.stroke(cuff, hex(0x9AA7BC), width: 0.7)
        }
    }

    /// Shaded snowball (drawn big, scaled down by the node).
    public static func snowball(radius r: CGFloat, scale: CGFloat) -> CGImage {
        Canvas.image(size: CGSize(width: 2 * r + 4, height: 2 * r + 4), scale: scale) { ctx in
            SnowmanArt.drawSnowBall(ctx, center: CGPoint(x: r + 2, y: r + 2), radius: r)
        }
    }

    public static let plowSize = CGSize(width: 124, height: 66)
    public static let plowWheelCenters = [CGPoint(x: 24, y: 11), CGPoint(x: 78, y: 11)]
    public static let plowBeaconPosition = CGPoint(x: 78, y: 56)
    /// Left edge of the blade's bottom, in plow image points.
    public static let plowBladeFront: CGFloat = 122

    /// Orange snowplow truck facing right, without wheels and beacon.
    public static func plow(scale: CGFloat) -> CGImage {
        Canvas.image(size: plowSize, scale: scale) { ctx in
            let orangeTop = hex(0xFFA23A)
            let orange = hex(0xF28C28)
            let orangeDark = hex(0xC96513)
            let outline = hex(0x7A3E0E, 0.55)
            // chassis
            ctx.setFillColor(hex(0x3A3F4A)); ctx.fill(CGRect(x: 8, y: 9, width: 92, height: 7))
            // dump body
            let dump = CGPath(roundedRect: CGRect(x: 4, y: 14, width: 58, height: 28), cornerWidth: 5, cornerHeight: 5, transform: nil)
            ctx.clipped(to: dump) {
                ctx.fillLinear([orangeTop, orange, orangeDark], [0, 0.55, 1], from: CGPoint(x: 0, y: 42), to: CGPoint(x: 0, y: 14))
                ctx.setFillColor(hex(0xFFFFFF, 0.9)); ctx.fill(CGRect(x: 4, y: 22, width: 58, height: 3.2))
                ctx.setFillColor(hex(0xD62839)); ctx.fill(CGRect(x: 4, y: 25.2, width: 58, height: 1.6))
                for x in stride(from: CGFloat(14), to: 60, by: 12) {
                    ctx.setFillColor(hex(0x000000, 0.12)); ctx.fill(CGRect(x: x, y: 27, width: 1.2, height: 15))
                }
            }
            ctx.stroke(dump, outline, width: 0.9)
            // snow heaped on the dump body
            let heap = CGMutablePath()
            heap.move(to: CGPoint(x: 5, y: 40))
            heap.addCurve(to: CGPoint(x: 26, y: 52), control1: CGPoint(x: 7, y: 50), control2: CGPoint(x: 16, y: 54))
            heap.addCurve(to: CGPoint(x: 46, y: 50), control1: CGPoint(x: 33, y: 56), control2: CGPoint(x: 40, y: 55))
            heap.addCurve(to: CGPoint(x: 61, y: 40), control1: CGPoint(x: 54, y: 52), control2: CGPoint(x: 61, y: 47))
            heap.closeSubpath()
            ctx.fill(heap, hex(0xFFFFFF))
            ctx.clipped(to: heap) {
                ctx.fillLinear([hex(0xFFFFFF, 0), hex(0xB8C9E3, 0.75)], from: CGPoint(x: 0, y: 52), to: CGPoint(x: 0, y: 40))
            }
            ctx.stroke(heap, hex(0xA9BCD8, 0.8), width: 0.7)
            // cab
            let cab = CGMutablePath()
            cab.move(to: CGPoint(x: 60, y: 14))
            cab.addLine(to: CGPoint(x: 60, y: 52))
            cab.addQuadCurve(to: CGPoint(x: 66, y: 57), control: CGPoint(x: 60, y: 57))
            cab.addLine(to: CGPoint(x: 86, y: 57))
            cab.addQuadCurve(to: CGPoint(x: 97, y: 40), control: CGPoint(x: 95, y: 56))
            cab.addLine(to: CGPoint(x: 98, y: 14))
            cab.closeSubpath()
            ctx.clipped(to: cab) {
                ctx.fillLinear([orangeTop, orange, orangeDark], [0, 0.5, 1], from: CGPoint(x: 0, y: 57), to: CGPoint(x: 0, y: 14))
                ctx.setFillColor(hex(0xFFFFFF, 0.9)); ctx.fill(CGRect(x: 60, y: 22, width: 40, height: 3.2))
                ctx.setFillColor(hex(0xD62839)); ctx.fill(CGRect(x: 60, y: 25.2, width: 40, height: 1.6))
            }
            ctx.stroke(cab, outline, width: 0.9)
            let window = CGMutablePath()
            window.move(to: CGPoint(x: 67, y: 35))
            window.addLine(to: CGPoint(x: 67, y: 51))
            window.addQuadCurve(to: CGPoint(x: 69, y: 53), control: CGPoint(x: 67, y: 53))
            window.addLine(to: CGPoint(x: 84, y: 53))
            window.addQuadCurve(to: CGPoint(x: 92, y: 38), control: CGPoint(x: 91, y: 52))
            window.addLine(to: CGPoint(x: 92, y: 35))
            window.closeSubpath()
            ctx.clipped(to: window) {
                ctx.fillLinear([hex(0xCDEFFF), hex(0x7CC6EE), hex(0x4A9BD6)], [0, 0.5, 1], from: CGPoint(x: 0, y: 53), to: CGPoint(x: 0, y: 35))
                let glare = CGMutablePath()
                glare.move(to: CGPoint(x: 72, y: 35)); glare.addLine(to: CGPoint(x: 80, y: 53))
                ctx.stroke(glare, hex(0xFFFFFF, 0.55), width: 3)
            }
            ctx.stroke(window, hex(0x2C5E8A, 0.7), width: 0.9)
            // door, handle, headlight, bumper
            let door = CGPath(roundedRect: CGRect(x: 66, y: 16, width: 24, height: 17), cornerWidth: 2, cornerHeight: 2, transform: nil)
            ctx.stroke(door, hex(0x7A3E0E, 0.35), width: 0.7)
            ctx.setFillColor(hex(0x5A2E0A, 0.7)); ctx.fill(CGRect(x: 84, y: 29, width: 4, height: 1.4))
            ctx.fill(circlePath(CGPoint(x: 95.5, y: 30), 2.3), hex(0xFFF3B0))
            ctx.fillRadial([hex(0xFFF3B0, 0.7), hex(0xFFF3B0, 0)], center: CGPoint(x: 96, y: 30), radius: 6, extend: false)
            ctx.setFillColor(hex(0x2E323B)); ctx.fill(CGRect(x: 94, y: 13, width: 7, height: 6))
            // blade arm
            ctx.setFillColor(hex(0x2E323B)); ctx.fill(CGRect(x: 98, y: 17, width: 8, height: 4))
            // blade
            let blade = CGMutablePath()
            blade.move(to: CGPoint(x: 103, y: 3))
            blade.addLine(to: CGPoint(x: 122, y: 5))
            blade.addQuadCurve(to: CGPoint(x: 120, y: 41), control: CGPoint(x: 114, y: 22))
            blade.addLine(to: CGPoint(x: 104, y: 37))
            blade.addQuadCurve(to: CGPoint(x: 103, y: 3), control: CGPoint(x: 109, y: 20))
            blade.closeSubpath()
            ctx.clipped(to: blade) {
                ctx.fillLinear([hex(0xFFFFFF), hex(0xE3E8F0)], from: CGPoint(x: 104, y: 0), to: CGPoint(x: 122, y: 0))
                for k in stride(from: CGFloat(-30), to: 40, by: 9) {
                    let s = CGMutablePath()
                    s.move(to: CGPoint(x: 100, y: k)); s.addLine(to: CGPoint(x: 124, y: k + 22))
                    ctx.stroke(s, hex(0xE63946), width: 3.6, cap: .butt)
                }
                ctx.fillLinear([hex(0x000000, 0.18), hex(0x000000, 0)], from: CGPoint(x: 104, y: 0), to: CGPoint(x: 112, y: 0))
            }
            ctx.stroke(blade, hex(0x6B7280), width: 0.9)
            ctx.setFillColor(hex(0x4B5563)); ctx.fill(CGRect(x: 103, y: 2, width: 19.5, height: 2.4))
        }
    }

    public static func plowWheel(scale: CGFloat) -> CGImage {
        Canvas.image(size: CGSize(width: 24, height: 24), scale: scale) { ctx in
            let c = CGPoint(x: 12, y: 12)
            ctx.fill(circlePath(c, 11), hex(0x1F2228))
            for i in 0..<12 {
                let a = CGFloat(i) / 12 * 2 * .pi
                ctx.circle(CGPoint(x: c.x + cos(a) * 10.4, y: c.y + sin(a) * 10.4), 1.3, hex(0x2C3038))
            }
            ctx.fill(circlePath(c, 5.6), hex(0xB9C0CB))
            ctx.stroke(circlePath(c, 5.6), hex(0x6B7280), width: 0.7)
            for i in 0..<5 {
                let a = CGFloat(i) / 5 * 2 * .pi
                ctx.circle(CGPoint(x: c.x + cos(a) * 3.4, y: c.y + sin(a) * 3.4), 0.8, hex(0x4B5563))
            }
            ctx.circle(c, 1.6, hex(0x4B5563))
            ctx.circle(CGPoint(x: c.x - 1.8, y: c.y + 2.2), 1.2, hex(0xFFFFFF, 0.5))
        }
    }

    public static func plowBeacon(scale: CGFloat) -> CGImage {
        Canvas.image(size: CGSize(width: 12, height: 10), scale: scale) { ctx in
            ctx.setFillColor(hex(0x3A3F4A)); ctx.fill(CGRect(x: 1, y: 0, width: 10, height: 2.2))
            let dome = CGMutablePath()
            dome.move(to: CGPoint(x: 2, y: 2))
            dome.addCurve(to: CGPoint(x: 10, y: 2), control1: CGPoint(x: 2, y: 10.5), control2: CGPoint(x: 10, y: 10.5))
            dome.closeSubpath()
            ctx.clipped(to: dome) {
                ctx.fillLinear([hex(0xFFE066), hex(0xFFB703), hex(0xFB8500)], [0, 0.5, 1], from: CGPoint(x: 0, y: 9), to: CGPoint(x: 0, y: 2))
            }
            ctx.circle(CGPoint(x: 4.6, y: 5.6), 1.1, hex(0xFFFFFF, 0.8))
        }
    }

    /// Soft radial glow (beacon light, window glow).
    public static func glow(radius r: CGFloat, color: UInt32, scale: CGFloat) -> CGImage {
        Canvas.image(size: CGSize(width: 2 * r, height: 2 * r), scale: scale) { ctx in
            ctx.fillRadial([hex(color, 0.85), hex(color, 0.3), hex(color, 0)], [0, 0.4, 1],
                           center: CGPoint(x: r, y: r), radius: r, extend: false)
        }
    }

    /// Burst of snow dust for impacts.
    public static func puff(scale: CGFloat) -> CGImage {
        Canvas.image(size: CGSize(width: 40, height: 40), scale: scale) { ctx in
            var rng = SeededGenerator(seed: 42)
            for _ in 0..<9 {
                let a = rng.range(0...(2 * .pi))
                let d = rng.range(2...10)
                let c = CGPoint(x: 20 + cos(a) * d, y: 20 + sin(a) * d)
                let r = rng.range(6...10)
                ctx.fillRadial([hex(0xFFFFFF, 0.95), hex(0xF2F6FD, 0.6), hex(0xFFFFFF, 0)], [0, 0.55, 1],
                               center: c, radius: r, extend: false)
            }
        }
    }

    /// Four-point sparkle for the snowman build moment.
    public static func sparkle(scale: CGFloat) -> CGImage {
        Canvas.image(size: CGSize(width: 18, height: 18), scale: scale) { ctx in
            let c = CGPoint(x: 9, y: 9)
            ctx.fillRadial([hex(0xFFF6C2, 0.75), hex(0xFFF6C2, 0)], center: c, radius: 9, extend: false)
            let star = CGMutablePath()
            star.move(to: CGPoint(x: 9, y: 17.5))
            star.addQuadCurve(to: CGPoint(x: 17.5, y: 9), control: CGPoint(x: 10.2, y: 10.2))
            star.addQuadCurve(to: CGPoint(x: 9, y: 0.5), control: CGPoint(x: 10.2, y: 7.8))
            star.addQuadCurve(to: CGPoint(x: 0.5, y: 9), control: CGPoint(x: 7.8, y: 7.8))
            star.addQuadCurve(to: CGPoint(x: 9, y: 17.5), control: CGPoint(x: 7.8, y: 10.2))
            star.closeSubpath()
            ctx.fill(star, hex(0xFFFFFF))
        }
    }
}
