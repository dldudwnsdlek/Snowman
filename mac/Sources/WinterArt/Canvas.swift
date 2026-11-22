import CoreGraphics
import Foundation

public let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!

/// Colour from 0xRRGGBB.
public func hex(_ v: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: sRGB, components: [
        CGFloat((v >> 16) & 0xFF) / 255, CGFloat((v >> 8) & 0xFF) / 255, CGFloat(v & 0xFF) / 255, alpha,
    ])!
}

public func rgba(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: sRGB, components: [r, g, b, a])!
}

/// Linear blend of two colours (both must be RGBA).
public func mix(_ a: CGColor, _ b: CGColor, _ t: CGFloat) -> CGColor {
    let ca = a.converted(to: sRGB, intent: .defaultIntent, options: nil)?.components ?? [0, 0, 0, 1]
    let cb = b.converted(to: sRGB, intent: .defaultIntent, options: nil)?.components ?? [0, 0, 0, 1]
    let t = max(0, min(1, t))
    return rgba(ca[0] + (cb[0] - ca[0]) * t, ca[1] + (cb[1] - ca[1]) * t,
                ca[2] + (cb[2] - ca[2]) * t, ca[3] + (cb[3] - ca[3]) * t)
}

public enum Canvas {
    /// A transparent bitmap of `size` points at `scale` pixels per point, y up, origin bottom-left.
    public static func image(size: CGSize, scale: CGFloat, _ draw: (CGContext) -> Void) -> CGImage {
        let w = max(1, Int((size.width * scale).rounded(.up)))
        let h = max(1, Int((size.height * scale).rounded(.up)))
        let ctx = context(width: w, height: h)
        ctx.scaleBy(x: scale, y: scale)
        draw(ctx)
        return ctx.makeImage()!
    }

    public static func context(width: Int, height: Int) -> CGContext {
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                            space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.setAllowsAntialiasing(true)
        ctx.setShouldAntialias(true)
        ctx.interpolationQuality = .high
        return ctx
    }
}

public extension CGContext {
    func fillLinear(_ colors: [CGColor], _ locations: [CGFloat]? = nil, from: CGPoint, to: CGPoint) {
        guard let g = CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: locations) else { return }
        drawLinearGradient(g, start: from, end: to, options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])
    }

    func fillRadial(_ colors: [CGColor], _ locations: [CGFloat]? = nil, center: CGPoint, radius: CGFloat,
                    startCenter: CGPoint? = nil, startRadius: CGFloat = 0, extend: Bool = true) {
        guard let g = CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: locations) else { return }
        drawRadialGradient(g, startCenter: startCenter ?? center, startRadius: startRadius,
                           endCenter: center, endRadius: radius,
                           options: extend ? [.drawsBeforeStartLocation, .drawsAfterEndLocation] : [.drawsBeforeStartLocation])
    }

    /// Runs `body` with `path` as the clip.
    func clipped(to path: CGPath, _ body: () -> Void) {
        saveGState()
        addPath(path)
        clip()
        body()
        restoreGState()
    }

    func fill(_ path: CGPath, _ color: CGColor) {
        saveGState()
        setFillColor(color)
        addPath(path)
        fillPath()
        restoreGState()
    }

    func stroke(_ path: CGPath, _ color: CGColor, width: CGFloat, cap: CGLineCap = .round, join: CGLineJoin = .round) {
        saveGState()
        setStrokeColor(color)
        setLineWidth(width)
        setLineCap(cap)
        setLineJoin(join)
        addPath(path)
        strokePath()
        restoreGState()
    }

    func circle(_ c: CGPoint, _ r: CGFloat, _ color: CGColor) {
        setFillColor(color)
        fillEllipse(in: CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
    }

    func withShadow(offset: CGSize, blur: CGFloat, color: CGColor, _ body: () -> Void) {
        saveGState()
        setShadow(offset: offset, blur: blur, color: color)
        beginTransparencyLayer(auxiliaryInfo: nil)
        body()
        endTransparencyLayer()
        restoreGState()
    }
}

public func ellipsePath(_ c: CGPoint, rx: CGFloat, ry: CGFloat) -> CGPath {
    CGPath(ellipseIn: CGRect(x: c.x - rx, y: c.y - ry, width: 2 * rx, height: 2 * ry), transform: nil)
}

public func circlePath(_ c: CGPoint, _ r: CGFloat) -> CGPath { ellipsePath(c, rx: r, ry: r) }
