import CoreGraphics
import Foundation
import SnowCore

public enum SnowmanPart: String, CaseIterable, Sendable {
    case body, head, leftArm, rightArm, eyes, eyesClosed, nose, mouth, cheeks, buttons, scarf, scarfTail, hat
}

/// One drawn piece of a snowman plus where it goes.
/// Reference snowman: ground point at (0,0), body radius 30, head radius 21.
public struct PartImage {
    public let image: CGImage
    /// Size in reference points.
    public let size: CGSize
    /// Normalised anchor inside the image (SpriteKit convention, origin bottom-left).
    public let anchor: CGPoint
    /// Where the anchor sits relative to the snowman's ground point, in reference points.
    public let position: CGPoint
    public let z: CGFloat
}

private struct StylePalette {
    let scarf: UInt32
    let scarfDark: UInt32
    let accent: UInt32
    let pattern: ScarfPattern
    let mittens: UInt32?
    let buttons: UInt32?
    let cheeks: CGFloat

    enum ScarfPattern { case endStripes, stripes, knit, dots }

    static func of(_ style: SnowmanStyle) -> StylePalette {
        switch style {
        case .santa:
            return StylePalette(scarf: 0x2E9E5B, scarfDark: 0x1D6E3E, accent: 0xFFFFFF, pattern: .endStripes,
                                mittens: 0x34A853, buttons: 0x1F1F24, cheeks: 0.45)
        case .beanie:
            return StylePalette(scarf: 0xE23B3B, scarfDark: 0xA92424, accent: 0xFFFFFF, pattern: .stripes,
                                mittens: nil, buttons: 0x3B6FD8, cheeks: 0.5)
        case .gentleman:
            return StylePalette(scarf: 0xC8102E, scarfDark: 0x850A1E, accent: 0x5E0715, pattern: .knit,
                                mittens: nil, buttons: 0x1F1F24, cheeks: 0)
        case .earmuffs:
            return StylePalette(scarf: 0x4FCDB7, scarfDark: 0x2E9C88, accent: 0xFFFFFF, pattern: .dots,
                                mittens: 0xFF8FB1, buttons: nil, cheeks: 0.65)
        case .elf:
            return StylePalette(scarf: 0x8E5CD9, scarfDark: 0x6438B0, accent: 0xF5C84C, pattern: .stripes,
                                mittens: 0xD7263D, buttons: 0xF2C14E, cheeks: 0.45)
        }
    }
}

public enum SnowmanArt {
    public static let bodyRadius: CGFloat = 30
    public static let headRadius: CGFloat = 21
    public static let bodyCenter = CGPoint(x: 0, y: 30)
    public static let headCenter = CGPoint(x: 0, y: 71)
    /// Ground to head top, without hat.
    public static let referenceHeight: CGFloat = 92

    private static let coal = hex(0x1F1F24)
    private static let mouthDark = hex(0x3A1D1D)
    private static let tongue = hex(0xF27B8A)

    public static func parts(for style: SnowmanStyle) -> [SnowmanPart] {
        let palette = StylePalette.of(style)
        return SnowmanPart.allCases.filter { part in
            switch part {
            case .cheeks: return palette.cheeks > 0
            case .buttons: return palette.buttons != nil
            default: return true
            }
        }
    }

    public static func part(_ part: SnowmanPart, style: SnowmanStyle, scale: CGFloat) -> PartImage? {
        guard parts(for: style).contains(part) else { return nil }
        let pal = StylePalette.of(style)
        switch part {
        case .body:
            return make(CGSize(width: 64, height: 64), CGPoint(x: 0.5, y: 0.5), bodyCenter, z: 1, scale) { ctx in
                drawSnowBall(ctx, center: CGPoint(x: 32, y: 32), radius: bodyRadius)
            }
        case .head:
            return make(CGSize(width: 46, height: 46), CGPoint(x: 0.5, y: 0.5), headCenter, z: 3, scale) { ctx in
                drawSnowBall(ctx, center: CGPoint(x: 23, y: 23), radius: headRadius)
            }
        case .leftArm:
            return make(CGSize(width: 42, height: 30), CGPoint(x: 40.0 / 42, y: 6.0 / 30), CGPoint(x: -23, y: 47), z: 0, scale) { ctx in
                drawArm(ctx, mitten: pal.mittens)
            }
        case .rightArm:
            return make(CGSize(width: 42, height: 30), CGPoint(x: 2.0 / 42, y: 6.0 / 30), CGPoint(x: 23, y: 47), z: 0, scale) { ctx in
                ctx.translateBy(x: 42, y: 0)
                ctx.scaleBy(x: -1, y: 1)
                drawArm(ctx, mitten: pal.mittens)
            }
        case .eyes:
            return make(CGSize(width: 28, height: 12), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0, y: 76), z: 5, scale) { ctx in
                drawEyes(ctx, style: style, closed: false)
            }
        case .eyesClosed:
            return make(CGSize(width: 28, height: 12), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0, y: 76), z: 5, scale) { ctx in
                drawEyes(ctx, style: style, closed: true)
            }
        case .nose:
            return make(CGSize(width: 18, height: 8), CGPoint(x: 0.05, y: 0.5), CGPoint(x: -0.5, y: 70), z: 6, scale) { ctx in
                drawCarrot(ctx)
            }
        case .mouth:
            return make(CGSize(width: 26, height: 12), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0, y: 62), z: 5, scale) { ctx in
                drawMouth(ctx, style: style)
            }
        case .cheeks:
            return make(CGSize(width: 36, height: 10), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0, y: 66), z: 4.5, scale) { ctx in
                for x in [CGFloat(6), 30] {
                    ctx.fill(ellipsePath(CGPoint(x: x, y: 5), rx: 5, ry: 3.4), hex(0xFF7FA0, pal.cheeks * 0.35))
                    ctx.fill(ellipsePath(CGPoint(x: x, y: 5), rx: 3.6, ry: 2.3), hex(0xFF6F96, pal.cheeks))
                }
            }
        case .buttons:
            let color = pal.buttons ?? 0x1F1F24
            let isCoal = color == 0x1F1F24
            let ys: [CGFloat] = style == .gentleman ? [27, 17, 7] : [24, 11]
            return make(CGSize(width: 10, height: 34), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0, y: 30), z: 2, scale) { ctx in
                for y in ys {
                    let c = CGPoint(x: 5, y: y)
                    if isCoal {
                        ctx.circle(c, 2.4, coal)
                        ctx.circle(CGPoint(x: c.x + 0.7, y: c.y + 0.8), 0.7, hex(0xFFFFFF, 0.7))
                    } else {
                        ctx.circle(c, 2.7, hex(color))
                        ctx.stroke(circlePath(c, 2.7), mix(hex(color), hex(0x000000), 0.35), width: 0.5)
                        ctx.circle(CGPoint(x: c.x - 0.8, y: c.y), 0.45, mix(hex(color), hex(0x000000), 0.5))
                        ctx.circle(CGPoint(x: c.x + 0.8, y: c.y), 0.45, mix(hex(color), hex(0x000000), 0.5))
                    }
                }
            }
        case .scarf:
            return make(CGSize(width: 56, height: 18), CGPoint(x: 0.5, y: 0.5), CGPoint(x: 0, y: 53), z: 4, scale) { ctx in
                drawScarfBand(ctx, pal)
            }
        case .scarfTail:
            return make(CGSize(width: 14, height: 30), CGPoint(x: 0.5, y: 0.96), CGPoint(x: 12, y: 51), z: 3.8, scale) { ctx in
                drawScarfTail(ctx, pal)
            }
        case .hat:
            return hat(style: style, scale: scale)
        }
    }

    /// Whole snowman drawn into one image `height` points tall (used by icon, previews, help).
    public static func composite(style: SnowmanStyle, height: CGFloat, scale: CGFloat) -> CGImage {
        let probe = parts(for: style).filter { $0 != .eyesClosed }.compactMap { part($0, style: style, scale: 1) }
        let union = probe.map(rect(of:)).reduce(CGRect.null) { $0.union($1) }.insetBy(dx: -2, dy: -2)
        let s = height / union.height
        let pieces = parts(for: style).filter { $0 != .eyesClosed }
            .compactMap { part($0, style: style, scale: scale * s) }
            .sorted { $0.z < $1.z }
        return Canvas.image(size: CGSize(width: union.width * s, height: height), scale: scale) { ctx in
            ctx.scaleBy(x: s, y: s)
            ctx.translateBy(x: -union.minX, y: -union.minY)
            for p in pieces { ctx.draw(p.image, in: rect(of: p)) }
        }
    }

    /// Where a part lands in reference coordinates.
    public static func rect(of p: PartImage) -> CGRect {
        CGRect(x: p.position.x - p.anchor.x * p.size.width,
               y: p.position.y - p.anchor.y * p.size.height,
               width: p.size.width, height: p.size.height)
    }

    // MARK: - Pieces

    private static func make(_ size: CGSize, _ anchor: CGPoint, _ position: CGPoint, z: CGFloat, _ scale: CGFloat,
                             _ draw: (CGContext) -> Void) -> PartImage {
        PartImage(image: Canvas.image(size: size, scale: scale, draw), size: size, anchor: anchor, position: position, z: z)
    }

    public static func drawSnowBall(_ ctx: CGContext, center c: CGPoint, radius r: CGFloat) {
        let path = circlePath(c, r)
        ctx.clipped(to: path) {
            ctx.fillRadial([hex(0xFFFFFF), hex(0xF6F9FF), hex(0xDDE7F5), hex(0xBACBE3)], [0, 0.42, 0.8, 1],
                           center: CGPoint(x: c.x - r * 0.3, y: c.y + r * 0.35), radius: r * 1.6)
            ctx.fillLinear([hex(0x8FA6C9, 0), hex(0x8FA6C9, 0.28)],
                           from: CGPoint(x: c.x, y: c.y - r * 0.15), to: CGPoint(x: c.x, y: c.y - r))
            var rng = SeededGenerator(seed: UInt64(r * 977))
            for _ in 0..<Int(r * 0.9) {
                let a = rng.range(0...(2 * .pi))
                let d = rng.unit().squareRoot() * r * 0.92
                ctx.circle(CGPoint(x: c.x + cos(a) * d, y: c.y + sin(a) * d), rng.range(0.25...0.6), hex(0xB9CAE2, 0.55))
            }
            // rim light
            ctx.stroke(circlePath(CGPoint(x: c.x + r * 0.04, y: c.y - r * 0.04), r * 0.96), hex(0xFFFFFF, 0.35), width: r * 0.05)
        }
        ctx.stroke(path, hex(0x9DB2D2, 0.6), width: max(0.6, r * 0.028))
    }

    private static func drawArm(_ ctx: CGContext, mitten: UInt32?) {
        let brown = hex(0x7A4E2A)
        let dark = hex(0x4A2E17)
        let main = CGMutablePath()
        main.move(to: CGPoint(x: 40, y: 6))
        main.addQuadCurve(to: CGPoint(x: 9, y: 21), control: CGPoint(x: 24, y: 9))
        ctx.stroke(main, dark, width: 3.4)
        ctx.stroke(main, brown, width: 2.2)
        if let m = mitten {
            let color = hex(m)
            let edge = mix(color, hex(0x000000), 0.35)
            let palm = ellipsePath(CGPoint(x: 7, y: 22), rx: 5.4, ry: 5.0)
            ctx.fill(palm, color)
            ctx.stroke(palm, edge, width: 0.7)
            let thumb = ellipsePath(CGPoint(x: 10.5, y: 27), rx: 2.1, ry: 2.6)
            ctx.fill(thumb, color)
            ctx.stroke(thumb, edge, width: 0.6)
            ctx.circle(CGPoint(x: 5.5, y: 23.5), 1.4, mix(color, hex(0xFFFFFF), 0.45))
            let cuff = CGPath(roundedRect: CGRect(x: 10.5, y: 16.5, width: 4.2, height: 6), cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)
            ctx.fill(cuff, hex(0xFFFFFF))
            ctx.stroke(cuff, hex(0xC9D3E3), width: 0.5)
        } else {
            let twig1 = CGMutablePath()
            twig1.move(to: CGPoint(x: 15, y: 18))
            twig1.addLine(to: CGPoint(x: 8, y: 27.5))
            let twig2 = CGMutablePath()
            twig2.move(to: CGPoint(x: 12, y: 19.5))
            twig2.addLine(to: CGPoint(x: 1.5, y: 17))
            let twig3 = CGMutablePath()
            twig3.move(to: CGPoint(x: 26, y: 10.5))
            twig3.addLine(to: CGPoint(x: 23, y: 16.5))
            for t in [twig1, twig2, twig3] {
                ctx.stroke(t, dark, width: 2.4)
                ctx.stroke(t, brown, width: 1.4)
            }
        }
    }

    private static func coalEye(_ ctx: CGContext, _ c: CGPoint, rx: CGFloat, ry: CGFloat) {
        ctx.fill(ellipsePath(c, rx: rx, ry: ry), coal)
        ctx.circle(CGPoint(x: c.x + rx * 0.35, y: c.y + ry * 0.38), max(0.6, rx * 0.34), hex(0xFFFFFF, 0.95))
    }

    private static func happyArc(_ ctx: CGContext, _ c: CGPoint) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x - 3.2, y: c.y - 1.2))
        p.addQuadCurve(to: CGPoint(x: c.x + 3.2, y: c.y - 1.2), control: CGPoint(x: c.x, y: c.y + 3.4))
        ctx.stroke(p, coal, width: 1.8)
    }

    private static func closedArc(_ ctx: CGContext, _ c: CGPoint) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: c.x - 3, y: c.y + 0.6))
        p.addQuadCurve(to: CGPoint(x: c.x + 3, y: c.y + 0.6), control: CGPoint(x: c.x, y: c.y - 2.2))
        ctx.stroke(p, coal, width: 1.5)
    }

    private static func drawEyes(_ ctx: CGContext, style: SnowmanStyle, closed: Bool) {
        let l = CGPoint(x: 7, y: 6)
        let r = CGPoint(x: 21, y: 6)
        if closed {
            if style == .elf { happyArc(ctx, l); happyArc(ctx, r) } else { closedArc(ctx, l); closedArc(ctx, r) }
            return
        }
        switch style {
        case .santa:
            coalEye(ctx, l, rx: 2.6, ry: 3.0); coalEye(ctx, r, rx: 2.6, ry: 3.0)
        case .beanie:
            coalEye(ctx, l, rx: 2.6, ry: 3.0); happyArc(ctx, r)
        case .gentleman:
            coalEye(ctx, l, rx: 2.3, ry: 2.6); coalEye(ctx, r, rx: 2.3, ry: 2.6)
        case .earmuffs:
            coalEye(ctx, l, rx: 3.3, ry: 3.6); coalEye(ctx, r, rx: 3.3, ry: 3.6)
            ctx.circle(CGPoint(x: l.x - 1.1, y: l.y - 1.2), 0.5, hex(0xFFFFFF, 0.8))
            ctx.circle(CGPoint(x: r.x - 1.1, y: r.y - 1.2), 0.5, hex(0xFFFFFF, 0.8))
        case .elf:
            happyArc(ctx, l); happyArc(ctx, r)
        }
    }

    private static func drawCarrot(_ ctx: CGContext) {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 1, y: 1.0))
        p.addQuadCurve(to: CGPoint(x: 17.2, y: 3.7), control: CGPoint(x: 9, y: 1.4))
        p.addQuadCurve(to: CGPoint(x: 1, y: 7.0), control: CGPoint(x: 9, y: 6.6))
        p.closeSubpath()
        ctx.clipped(to: p) {
            ctx.fillLinear([hex(0xFFA24A), hex(0xF26B12), hex(0xD9530A)], [0, 0.55, 1],
                           from: CGPoint(x: 0, y: 7), to: CGPoint(x: 0, y: 1))
            for x in [CGFloat(5.5), 9.5, 13] {
                let l = CGMutablePath()
                l.move(to: CGPoint(x: x, y: 2))
                l.addLine(to: CGPoint(x: x + 0.8, y: 4.2))
                ctx.stroke(l, hex(0xB8460A, 0.75), width: 0.55)
            }
        }
        ctx.stroke(p, hex(0xB8460A, 0.55), width: 0.5)
    }

    private static func drawMouth(_ ctx: CGContext, style: SnowmanStyle) {
        switch style {
        case .santa:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 6, y: 8.5))
            p.addQuadCurve(to: CGPoint(x: 20, y: 8.5), control: CGPoint(x: 13, y: 9.6))
            p.addQuadCurve(to: CGPoint(x: 6, y: 8.5), control: CGPoint(x: 13, y: -1.5))
            p.closeSubpath()
            ctx.fill(p, mouthDark)
            ctx.clipped(to: p) { ctx.fill(ellipsePath(CGPoint(x: 13, y: 3.6), rx: 3.8, ry: 2.4), tongue) }
        case .beanie:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 6, y: 7.5))
            p.addQuadCurve(to: CGPoint(x: 19.5, y: 8), control: CGPoint(x: 12.5, y: 1.5))
            ctx.stroke(p, mouthDark, width: 1.7)
            ctx.fill(ellipsePath(CGPoint(x: 15.6, y: 4.3), rx: 1.9, ry: 1.6), tongue)
            ctx.stroke(ellipsePath(CGPoint(x: 15.6, y: 4.3), rx: 1.9, ry: 1.6), hex(0xC9566A), width: 0.4)
        case .gentleman:
            for i in 0..<5 {
                let t = CGFloat(i) / 4
                ctx.circle(CGPoint(x: 6 + 14 * t, y: 8 - sin(t * .pi) * 4), 1.25, coal)
            }
        case .earmuffs:
            ctx.fill(ellipsePath(CGPoint(x: 13, y: 5.5), rx: 2.7, ry: 3.4), mouthDark)
            ctx.fill(ellipsePath(CGPoint(x: 13, y: 3.7), rx: 1.7, ry: 1.2), tongue)
        case .elf:
            let p = CGMutablePath()
            p.move(to: CGPoint(x: 8, y: 7.2))
            p.addQuadCurve(to: CGPoint(x: 18, y: 7.2), control: CGPoint(x: 13, y: 2.6))
            ctx.stroke(p, mouthDark, width: 1.6)
        }
    }

    private static func scarfPattern(_ ctx: CGContext, _ pal: StylePalette, bounds: CGRect, horizontal: Bool) {
        let accent = hex(pal.accent)
        switch pal.pattern {
        case .stripes:
            if horizontal {
                for y in stride(from: bounds.minY + 3, to: bounds.maxY, by: 7) {
                    ctx.setFillColor(accent); ctx.fill(CGRect(x: bounds.minX, y: y, width: bounds.width, height: 3))
                }
            } else {
                for x in stride(from: bounds.minX + 4, to: bounds.maxX, by: 7) {
                    ctx.setFillColor(accent); ctx.fill(CGRect(x: x, y: bounds.minY, width: 3, height: bounds.height))
                }
            }
        case .endStripes:
            if horizontal {
                for y in [bounds.minY + 6, bounds.minY + 10] {
                    ctx.setFillColor(accent); ctx.fill(CGRect(x: bounds.minX, y: y, width: bounds.width, height: 1.8))
                }
            } else {
                for x in [bounds.minX + 6, bounds.minX + 10, bounds.maxX - 12, bounds.maxX - 8] {
                    ctx.setFillColor(accent); ctx.fill(CGRect(x: x, y: bounds.minY, width: 1.8, height: bounds.height))
                }
            }
        case .knit:
            for x in stride(from: bounds.minX - bounds.height, to: bounds.maxX, by: 3) {
                let l = CGMutablePath()
                l.move(to: CGPoint(x: x, y: bounds.minY))
                l.addLine(to: CGPoint(x: x + bounds.height * 0.6, y: bounds.maxY))
                ctx.stroke(l, hex(pal.accent, 0.45), width: 0.7)
            }
        case .dots:
            var row = 0
            for y in stride(from: bounds.minY + 2.5, to: bounds.maxY, by: 4.5) {
                for x in stride(from: bounds.minX + 2.5 + CGFloat(row % 2) * 2.5, to: bounds.maxX, by: 5) {
                    ctx.circle(CGPoint(x: x, y: y), 1.05, accent)
                }
                row += 1
            }
        }
    }

    private static func drawScarfBand(_ ctx: CGContext, _ pal: StylePalette) {
        let band = CGMutablePath()
        band.move(to: CGPoint(x: 4, y: 12.5))
        band.addQuadCurve(to: CGPoint(x: 52, y: 12.5), control: CGPoint(x: 28, y: 9))
        band.addLine(to: CGPoint(x: 53, y: 4.5))
        band.addQuadCurve(to: CGPoint(x: 3, y: 4.5), control: CGPoint(x: 28, y: -0.5))
        band.closeSubpath()
        ctx.clipped(to: band) {
            ctx.setFillColor(hex(pal.scarf)); ctx.fill(CGRect(x: 0, y: 0, width: 56, height: 18))
            scarfPattern(ctx, pal, bounds: CGRect(x: 0, y: 0, width: 56, height: 18), horizontal: false)
            ctx.fillLinear([hex(0x000000, 0.22), hex(0x000000, 0), hex(0xFFFFFF, 0.18)], [0, 0.55, 1],
                           from: CGPoint(x: 0, y: 1), to: CGPoint(x: 0, y: 13))
        }
        ctx.stroke(band, hex(pal.scarfDark, 0.65), width: 0.8)
        let knot = ellipsePath(CGPoint(x: 40, y: 7.5), rx: 5.2, ry: 5.4)
        ctx.fill(knot, hex(pal.scarf))
        ctx.clipped(to: knot) {
            scarfPattern(ctx, pal, bounds: CGRect(x: 34, y: 2, width: 12, height: 12), horizontal: true)
            ctx.fillRadial([hex(0xFFFFFF, 0.25), hex(0x000000, 0.2)], center: CGPoint(x: 40, y: 7.5), radius: 6,
                           startCenter: CGPoint(x: 38.5, y: 9.5))
        }
        ctx.stroke(knot, hex(pal.scarfDark, 0.7), width: 0.8)
    }

    private static func drawScarfTail(_ ctx: CGContext, _ pal: StylePalette) {
        let tail = CGMutablePath()
        tail.move(to: CGPoint(x: 2.5, y: 29))
        tail.addLine(to: CGPoint(x: 11.5, y: 29))
        tail.addQuadCurve(to: CGPoint(x: 12.5, y: 6), control: CGPoint(x: 13.5, y: 17))
        tail.addLine(to: CGPoint(x: 2, y: 5))
        tail.addQuadCurve(to: CGPoint(x: 2.5, y: 29), control: CGPoint(x: 0.5, y: 17))
        tail.closeSubpath()
        ctx.clipped(to: tail) {
            ctx.setFillColor(hex(pal.scarf)); ctx.fill(CGRect(x: 0, y: 0, width: 14, height: 30))
            scarfPattern(ctx, pal, bounds: CGRect(x: 0, y: 4, width: 14, height: 26), horizontal: true)
            ctx.fillLinear([hex(0x000000, 0.18), hex(0x000000, 0)], from: CGPoint(x: 12, y: 0), to: CGPoint(x: 4, y: 0))
        }
        ctx.stroke(tail, hex(pal.scarfDark, 0.65), width: 0.8)
        for i in 0..<5 {
            let x = 3 + CGFloat(i) * 2.2
            let f = CGMutablePath()
            f.move(to: CGPoint(x: x, y: 5.5))
            f.addLine(to: CGPoint(x: x - 0.3, y: 1))
            ctx.stroke(f, hex(pal.scarfDark), width: 1.0)
        }
    }

    // MARK: - Hats

    private static func hat(style: SnowmanStyle, scale: CGFloat) -> PartImage {
        switch style {
        case .santa:
            return make(CGSize(width: 70, height: 54), CGPoint(x: 30.0 / 70, y: 0), CGPoint(x: 0, y: 84), z: 7, scale) { ctx in
                let cone = CGMutablePath()
                cone.move(to: CGPoint(x: 12, y: 8))
                cone.addCurve(to: CGPoint(x: 38, y: 45), control1: CGPoint(x: 13, y: 30), control2: CGPoint(x: 24, y: 45))
                cone.addCurve(to: CGPoint(x: 58, y: 26), control1: CGPoint(x: 50, y: 45), control2: CGPoint(x: 57, y: 36))
                cone.addCurve(to: CGPoint(x: 48, y: 8), control1: CGPoint(x: 54, y: 22), control2: CGPoint(x: 49, y: 18))
                cone.closeSubpath()
                ctx.clipped(to: cone) {
                    ctx.fillLinear([hex(0xF04452), hex(0xD62839), hex(0xA9182A)], [0, 0.5, 1],
                                   from: CGPoint(x: 12, y: 40), to: CGPoint(x: 56, y: 12))
                    let fold = CGMutablePath()
                    fold.move(to: CGPoint(x: 36, y: 42))
                    fold.addQuadCurve(to: CGPoint(x: 44, y: 9), control: CGPoint(x: 46, y: 28))
                    ctx.stroke(fold, hex(0x8E1222, 0.45), width: 2.2)
                }
                ctx.stroke(cone, hex(0x8E1222, 0.6), width: 0.8)
                fluffyBand(ctx, CGRect(x: 8, y: 1, width: 44, height: 10.5))
                fluffyBall(ctx, CGPoint(x: 59, y: 23), 6.8)
            }
        case .beanie:
            return make(CGSize(width: 48, height: 40), CGPoint(x: 0.5, y: 0), CGPoint(x: 0, y: 84), z: 7, scale) { ctx in
                let dome = CGMutablePath()
                dome.move(to: CGPoint(x: 5, y: 6))
                dome.addCurve(to: CGPoint(x: 43, y: 6), control1: CGPoint(x: 5, y: 35), control2: CGPoint(x: 43, y: 35))
                dome.closeSubpath()
                ctx.clipped(to: dome) {
                    ctx.fillLinear([hex(0x5C8BEA), hex(0x3B6FD8), hex(0x2A52AE)], [0, 0.5, 1],
                                   from: CGPoint(x: 8, y: 30), to: CGPoint(x: 42, y: 6))
                    for row in 0..<5 {
                        let y = 10 + CGFloat(row) * 4.5
                        for col in 0..<10 {
                            let x = 4 + CGFloat(col) * 4.4 + CGFloat(row % 2) * 2.2
                            let v = CGMutablePath()
                            v.move(to: CGPoint(x: x - 1.4, y: y + 1.6))
                            v.addLine(to: CGPoint(x: x, y: y))
                            v.addLine(to: CGPoint(x: x + 1.4, y: y + 1.6))
                            ctx.stroke(v, hex(0xFFFFFF, 0.22), width: 0.7)
                        }
                    }
                }
                ctx.stroke(dome, hex(0x1F3F8A, 0.6), width: 0.8)
                let band = CGPath(roundedRect: CGRect(x: 3, y: 0, width: 42, height: 9.5), cornerWidth: 4, cornerHeight: 4, transform: nil)
                ctx.clipped(to: band) {
                    ctx.setFillColor(hex(0x2F5FC4)); ctx.fill(CGRect(x: 0, y: 0, width: 48, height: 10))
                    for x in stride(from: CGFloat(4.5), to: 45, by: 3) {
                        ctx.setFillColor(hex(0x6E97EC, 0.8)); ctx.fill(CGRect(x: x, y: 0, width: 1.2, height: 10))
                    }
                    ctx.fillLinear([hex(0x000000, 0.18), hex(0x000000, 0)], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: 9))
                }
                ctx.stroke(band, hex(0x1F3F8A, 0.6), width: 0.8)
                fluffyBall(ctx, CGPoint(x: 24, y: 32), 6.2)
            }
        case .gentleman:
            return make(CGSize(width: 50, height: 40), CGPoint(x: 0.5, y: 0), CGPoint(x: 0, y: 85), z: 7, scale) { ctx in
                let crown = CGMutablePath()
                crown.move(to: CGPoint(x: 12.5, y: 3))
                crown.addLine(to: CGPoint(x: 11, y: 34))
                crown.addLine(to: CGPoint(x: 39, y: 34))
                crown.addLine(to: CGPoint(x: 37.5, y: 3))
                crown.closeSubpath()
                ctx.clipped(to: crown) {
                    ctx.fillLinear([hex(0x3A3A44), hex(0x23232A), hex(0x111115)], [0, 0.35, 1],
                                   from: CGPoint(x: 11, y: 0), to: CGPoint(x: 39, y: 0))
                    ctx.setFillColor(hex(0xC8102E)); ctx.fill(CGRect(x: 10, y: 5, width: 30, height: 6.5))
                    ctx.setFillColor(hex(0xFFFFFF, 0.18)); ctx.fill(CGRect(x: 10, y: 10.6, width: 30, height: 0.9))
                    ctx.setFillColor(hex(0xFFFFFF, 0.12)); ctx.fill(CGRect(x: 14, y: 12, width: 2.2, height: 21))
                }
                ctx.fill(ellipsePath(CGPoint(x: 25, y: 34), rx: 14, ry: 2.4), hex(0x2C2C34))
                ctx.stroke(ellipsePath(CGPoint(x: 25, y: 34), rx: 14, ry: 2.4), hex(0x0B0B0E), width: 0.6)
                let brim = ellipsePath(CGPoint(x: 25, y: 3.4), rx: 23, ry: 3.4)
                ctx.fill(brim, hex(0x18181D))
                ctx.stroke(brim, hex(0x48484F), width: 0.6)
                // holly sprig
                for (angle, dx) in [(CGFloat(0.55), CGFloat(-3.2)), (CGFloat(-0.55), CGFloat(3.2))] {
                    ctx.saveGState()
                    ctx.translateBy(x: 17 + dx, y: 9.5)
                    ctx.rotate(by: angle)
                    let leaf = ellipsePath(.zero, rx: 4.2, ry: 1.9)
                    ctx.fill(leaf, hex(0x2E8B3E))
                    let vein = CGMutablePath()
                    vein.move(to: CGPoint(x: -3.5, y: 0)); vein.addLine(to: CGPoint(x: 3.5, y: 0))
                    ctx.stroke(vein, hex(0x1B5E27), width: 0.4)
                    ctx.restoreGState()
                }
                for p in [CGPoint(x: 16, y: 10.5), CGPoint(x: 18.3, y: 11.6), CGPoint(x: 18.6, y: 9.2)] {
                    ctx.circle(p, 1.55, hex(0xE0242E))
                    ctx.circle(CGPoint(x: p.x - 0.4, y: p.y + 0.4), 0.45, hex(0xFFFFFF, 0.7))
                }
            }
        case .earmuffs:
            return make(CGSize(width: 62, height: 40), CGPoint(x: 0.5, y: 0), CGPoint(x: 0, y: 62), z: 7, scale) { ctx in
                let band = CGMutablePath()
                band.move(to: CGPoint(x: 12, y: 14))
                band.addQuadCurve(to: CGPoint(x: 50, y: 14), control: CGPoint(x: 31, y: 52))
                ctx.stroke(band, hex(0xC9567A), width: 4.2)
                ctx.stroke(band, hex(0xF27AA0), width: 2.6)
                for x in [CGFloat(11), 51] { fluffyMuff(ctx, CGPoint(x: x, y: 10.5), 8.5) }
            }
        case .elf:
            return make(CGSize(width: 84, height: 60), CGPoint(x: 22.0 / 84, y: 0), CGPoint(x: 0, y: 84), z: 7, scale) { ctx in
                let cone = CGMutablePath()
                cone.move(to: CGPoint(x: 5, y: 8))
                cone.addCurve(to: CGPoint(x: 34, y: 50), control1: CGPoint(x: 8, y: 34), control2: CGPoint(x: 20, y: 50))
                cone.addCurve(to: CGPoint(x: 68, y: 40), control1: CGPoint(x: 48, y: 51), control2: CGPoint(x: 60, y: 48))
                cone.addCurve(to: CGPoint(x: 39, y: 8), control1: CGPoint(x: 58, y: 36), control2: CGPoint(x: 44, y: 28))
                cone.closeSubpath()
                ctx.clipped(to: cone) {
                    ctx.fillLinear([hex(0x4CC764), hex(0x2F9E44), hex(0x1E7A33)], [0, 0.5, 1],
                                   from: CGPoint(x: 8, y: 44), to: CGPoint(x: 52, y: 10))
                    let fold = CGMutablePath()
                    fold.move(to: CGPoint(x: 32, y: 47))
                    fold.addQuadCurve(to: CGPoint(x: 34, y: 9), control: CGPoint(x: 40, y: 28))
                    ctx.stroke(fold, hex(0x145C25, 0.4), width: 2)
                }
                ctx.stroke(cone, hex(0x145C25, 0.65), width: 0.8)
                // zig-zag cuff
                let cuff = CGMutablePath()
                cuff.move(to: CGPoint(x: 2, y: 11))
                cuff.addLine(to: CGPoint(x: 42, y: 11))
                var x: CGFloat = 42
                var down = true
                while x > 2 {
                    x -= 4
                    cuff.addLine(to: CGPoint(x: max(2, x), y: down ? 1 : 5))
                    down.toggle()
                }
                cuff.closeSubpath()
                ctx.fill(cuff, hex(0xD7263D))
                ctx.stroke(cuff, hex(0x8E1222, 0.6), width: 0.7)
                // bell
                let bell = CGPoint(x: 70, y: 37.5)
                ctx.fill(circlePath(bell, 5), hex(0xF2C14E))
                ctx.clipped(to: circlePath(bell, 5)) {
                    ctx.fillRadial([hex(0xFFF1B8), hex(0xF2C14E), hex(0xC9921E)], [0, 0.5, 1],
                                   center: bell, radius: 6, startCenter: CGPoint(x: bell.x - 1.6, y: bell.y + 1.8))
                }
                ctx.stroke(circlePath(bell, 5), hex(0x9C6E12), width: 0.6)
                let slit = CGMutablePath()
                slit.move(to: CGPoint(x: bell.x - 2.6, y: bell.y - 1.6))
                slit.addLine(to: CGPoint(x: bell.x + 2.6, y: bell.y - 1.6))
                ctx.stroke(slit, hex(0x6B4A0B), width: 1)
                ctx.circle(CGPoint(x: bell.x, y: bell.y - 3), 0.9, hex(0x6B4A0B))
            }
        }
    }

    private static func fluffyBand(_ ctx: CGContext, _ r: CGRect) {
        let path = CGPath(roundedRect: r, cornerWidth: r.height / 2, cornerHeight: r.height / 2, transform: nil)
        let span = r.width - r.height
        let count = max(1, Int(span / 3.6))
        for i in 0...count {
            let x = r.minX + r.height / 2 + CGFloat(i) * span / CGFloat(count)
            ctx.circle(CGPoint(x: x, y: r.maxY - 1.3), 2.0, hex(0xFFFFFF))
            if i < count { ctx.circle(CGPoint(x: x + span / CGFloat(count) / 2, y: r.minY + 1.5), 1.7, hex(0xF4F7FC)) }
        }
        ctx.fill(path, hex(0xFFFFFF))
        ctx.clipped(to: path) {
            ctx.fillLinear([hex(0xC9D6EA, 0.75), hex(0xFFFFFF, 0)], from: CGPoint(x: 0, y: r.minY), to: CGPoint(x: 0, y: r.midY + 2))
        }
    }

    private static func fluffyBall(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat) {
        for i in 0..<10 {
            let a = CGFloat(i) / 10 * 2 * .pi
            ctx.circle(CGPoint(x: c.x + cos(a) * r * 0.78, y: c.y + sin(a) * r * 0.78), r * 0.36, hex(0xF1F5FB))
        }
        ctx.fill(circlePath(c, r * 0.86), hex(0xFFFFFF))
        ctx.clipped(to: circlePath(c, r * 0.95)) {
            ctx.fillRadial([hex(0xFFFFFF, 0), hex(0xBFCDE2, 0.55)], [0.55, 1], center: c, radius: r,
                           startCenter: CGPoint(x: c.x - r * 0.3, y: c.y + r * 0.3))
        }
    }

    private static func fluffyMuff(_ ctx: CGContext, _ c: CGPoint, _ r: CGFloat) {
        for i in 0..<12 {
            let a = CGFloat(i) / 12 * 2 * .pi
            ctx.circle(CGPoint(x: c.x + cos(a) * r * 0.8, y: c.y + sin(a) * r * 0.8), r * 0.32, hex(0xF77FA6))
        }
        ctx.fill(circlePath(c, r * 0.86), hex(0xFF93B6))
        ctx.clipped(to: circlePath(c, r * 0.9)) {
            ctx.fillRadial([hex(0xFFD0DF), hex(0xFF93B6, 0)], center: CGPoint(x: c.x - r * 0.3, y: c.y + r * 0.3), radius: r * 0.7)
        }
        for i in 0..<7 {
            let a = CGFloat(i) * 0.9
            ctx.circle(CGPoint(x: c.x + cos(a) * r * 0.45, y: c.y + sin(a) * r * 0.45), 0.7, hex(0xFFFFFF, 0.45))
        }
    }
}
