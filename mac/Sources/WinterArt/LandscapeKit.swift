import CoreGraphics
import CoreImage
import Foundation
import SnowCore

/// Drawing helpers for the winter wallpapers. Canvas is in pixels, origin bottom-left;
/// vertical sizes are given in units of 1/1000 of the height so scenes scale with resolution.
public struct LandscapeKit {
    public let ctx: CGContext
    public let w: CGFloat
    public let h: CGFloat

    public var u: CGFloat { h / 1000 }
    public func px(_ units: CGFloat) -> CGFloat { units * u }
    public func fx(_ fraction: CGFloat) -> CGFloat { fraction * w }

    private static let ciContext = CIContext(options: [.cacheIntermediates: false])

    // MARK: Sky & light

    /// Vertical gradient; positions are fractions of the height from the bottom.
    public func sky(_ stops: [(CGFloat, UInt32)]) {
        ctx.fillLinear(stops.map { hex($0.1) }, stops.map { $0.0 }, from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: h))
    }

    public func glow(_ c: CGPoint, radius: CGFloat, color: UInt32, alpha: CGFloat, blend: CGBlendMode = .screen) {
        ctx.saveGState()
        ctx.setBlendMode(blend)
        ctx.fillRadial([hex(color, alpha), hex(color, alpha * 0.35), hex(color, 0)], [0, 0.35, 1], center: c, radius: radius, extend: false)
        ctx.restoreGState()
    }

    public func stars(_ rng: inout SeededGenerator, count: Int, minY: CGFloat, maxR: CGFloat = 1.3, tint: UInt32 = 0xFFFFFF) {
        for _ in 0..<count {
            let p = CGPoint(x: rng.unit() * w, y: (minY + (1 - minY) * pow(rng.unit(), 0.8)) * h)
            let r = px(rng.range(0.25...maxR)) * (rng.unit() < 0.06 ? 1.8 : 1)
            let a = rng.range(0.35...1)
            ctx.circle(p, r, hex(tint, a))
            if r > px(maxR) * 0.9 {
                glow(p, radius: r * 6, color: tint, alpha: 0.35)
                let s = CGMutablePath()
                s.move(to: CGPoint(x: p.x - r * 5, y: p.y)); s.addLine(to: CGPoint(x: p.x + r * 5, y: p.y))
                s.move(to: CGPoint(x: p.x, y: p.y - r * 5)); s.addLine(to: CGPoint(x: p.x, y: p.y + r * 5))
                ctx.stroke(s, hex(tint, 0.35), width: max(0.6, r * 0.35))
            }
        }
    }

    public func moon(_ c: CGPoint, r: CGFloat, color: UInt32 = 0xFFF6DD, glowColor: UInt32 = 0xBFD3FF) {
        glow(c, radius: r * 7, color: glowColor, alpha: 0.28)
        glow(c, radius: r * 2.6, color: color, alpha: 0.35)
        ctx.fill(circlePath(c, r), hex(color))
        ctx.clipped(to: circlePath(c, r)) {
            ctx.fillRadial([hex(0xFFFFFF, 0), hex(0xD9CFB0, 0.45)], [0.5, 1], center: c, radius: r,
                           startCenter: CGPoint(x: c.x - r * 0.25, y: c.y + r * 0.25))
            var rng = SeededGenerator(seed: 99)
            for _ in 0..<7 {
                let p = CGPoint(x: c.x + rng.range(-0.6...0.6) * r, y: c.y + rng.range(-0.6...0.6) * r)
                ctx.circle(p, r * rng.range(0.06...0.2), hex(0xCFC5A4, 0.35))
            }
        }
    }

    public func sun(_ c: CGPoint, r: CGFloat, core: UInt32, halo: UInt32, haloRadius: CGFloat) {
        glow(c, radius: haloRadius, color: halo, alpha: 0.55)
        glow(c, radius: r * 3, color: core, alpha: 0.7)
        ctx.fill(circlePath(c, r), hex(core))
    }

    /// Soft horizontal haze band centred at `y` (units).
    public func fog(y: CGFloat, height: CGFloat, color: UInt32, alpha: CGFloat) {
        let y0 = px(y - height / 2), y1 = px(y + height / 2)
        ctx.saveGState()
        ctx.clip(to: CGRect(x: 0, y: y0, width: w, height: y1 - y0))
        ctx.fillLinear([hex(color, 0), hex(color, alpha), hex(color, 0)], [0, 0.5, 1],
                       from: CGPoint(x: 0, y: y0), to: CGPoint(x: 0, y: y1))
        ctx.restoreGState()
    }

    // MARK: Layers

    /// Draws into a reduced-size layer, blurs it and composites it over the canvas.
    public func blurLayer(scale: CGFloat = 0.25, radius: CGFloat, blend: CGBlendMode = .normal, alpha: CGFloat = 1,
                          _ draw: (CGContext) -> Void) {
        let lw = max(4, Int(w * scale)), lh = max(4, Int(h * scale))
        let layer = Canvas.context(width: lw, height: lh)
        layer.scaleBy(x: CGFloat(lw) / w, y: CGFloat(lh) / h)
        draw(layer)
        guard var image = layer.makeImage() else { return }
        if radius > 0 {
            let ci = CIImage(cgImage: image)
            let blurred = ci.clampedToExtent().applyingGaussianBlur(sigma: Double(radius * scale)).cropped(to: ci.extent)
            if let out = LandscapeKit.ciContext.createCGImage(blurred, from: ci.extent, format: .RGBA8, colorSpace: sRGB) {
                image = out
            }
        }
        ctx.saveGState()
        ctx.setBlendMode(blend)
        ctx.setAlpha(alpha)
        ctx.interpolationQuality = .high
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: w, height: h))
        ctx.restoreGState()
    }

    /// Fine film grain so large gradients never band.
    public func grain(amount: CGFloat = 0.07) {
        ctx.saveGState()
        ctx.setBlendMode(.overlay)
        ctx.setAlpha(amount)
        ctx.draw(LandscapeKit.grainTile, in: CGRect(x: 0, y: 0, width: 256, height: 256), byTiling: true)
        ctx.restoreGState()
    }

    private static let grainTile: CGImage = {
        let n = 256
        var rng = SeededGenerator(seed: 4242)
        var bytes = [UInt8](repeating: 255, count: n * n * 4)
        for i in 0..<(n * n) {
            let v = UInt8(max(0, min(255, 128 + Int((rng.unit() - 0.5) * 200))))
            bytes[i * 4] = v; bytes[i * 4 + 1] = v; bytes[i * 4 + 2] = v
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(width: n, height: n, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: n * 4, space: sRGB,
                       bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent)!
    }()

    // MARK: Terrain

    /// Mountain ridge by midpoint displacement plus explicit peaks. Heights in units.
    public func ridgePoints(_ rng: inout SeededGenerator, base: CGFloat, amp: CGFloat, rough: CGFloat = 0.55,
                            peaks: [(x: CGFloat, height: CGFloat, width: CGFloat)] = []) -> [CGPoint] {
        let count = 513
        var hs = [CGFloat](repeating: 0, count: count)
        hs[0] = rng.range(-0.5...0.5) * amp
        hs[count - 1] = rng.range(-0.5...0.5) * amp
        var step = count - 1
        var a = amp
        while step > 1 {
            let half = step / 2
            var i = half
            while i < count {
                hs[i] = (hs[i - half] + hs[i + half]) / 2 + rng.range(-1...1) * a
                i += step
            }
            a *= rough
            step = half
        }
        var fine = [CGFloat](repeating: 0, count: count)
        step = count - 1
        a = 1
        while step > 1 {
            let half = step / 2
            var i = half
            while i < count {
                fine[i] = (fine[i - half] + fine[i + half]) / 2 + rng.range(-1...1) * a
                i += step
            }
            a *= 0.68
            step = half
        }
        return (0..<count).map { i in
            let fx = CGFloat(i) / CGFloat(count - 1)
            var lift: CGFloat = 0
            for p in peaks {
                let d = abs(fx - p.x) / p.width
                if d < 1 { lift += p.height * pow(1 - d, 1.25) }
            }
            let y = base + hs[i] + lift * (1 + 0.16 * fine[i])
            return CGPoint(x: fx * w, y: px(y))
        }
    }

    public func areaPath(_ pts: [CGPoint], bottom: CGFloat = 0) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: pts[0].x, y: bottom))
        for pt in pts { p.addLine(to: pt) }
        p.addLine(to: CGPoint(x: pts[pts.count - 1].x, y: bottom))
        p.closeSubpath()
        return p
    }

    /// Fills a mountain range with rock gradient, optional snow caps and shaded left faces.
    @discardableResult
    public func mountains(_ pts: [CGPoint], top: UInt32, bottom: UInt32, snow: UInt32? = nil, snowLine: CGFloat = 0,
                          rng: inout SeededGenerator, shade: UInt32 = 0x0A1430, shadeAlpha: CGFloat = 0.28) -> CGPath {
        let path = areaPath(pts)
        let maxY = pts.map(\.y).max() ?? h
        ctx.clipped(to: path) {
            ctx.fillLinear([hex(bottom), hex(top)], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: maxY))
            if let snow {
                let line = CGMutablePath()
                var y = px(snowLine)
                line.move(to: CGPoint(x: 0, y: h))
                line.addLine(to: CGPoint(x: 0, y: y))
                var x: CGFloat = 0
                while x < w {
                    x += w / 160
                    y += px(rng.range(-6...6))
                    y = max(px(snowLine - 30), min(px(snowLine + 30), y))
                    line.addLine(to: CGPoint(x: x, y: y))
                }
                line.addLine(to: CGPoint(x: w, y: h))
                line.closeSubpath()
                ctx.clipped(to: line) {
                    ctx.fillLinear([hex(snow, 0.85), hex(snow)], from: CGPoint(x: 0, y: px(snowLine)), to: CGPoint(x: 0, y: maxY))
                }
            }
            // shaded left faces
            let n = pts.count
            var i = 8
            while i < n - 8 {
                let window = pts[max(0, i - 24)...min(n - 1, i + 24)]
                if pts[i].y >= (window.map(\.y).max() ?? 0) && pts[i].y > px(snowLine) * 0.5 {
                    var j = i
                    while j > 0 && pts[j - 1].y <= pts[j].y + px(0.5) { j -= 1 }
                    let peak = pts[i], valley = pts[j]
                    let rise = peak.y - valley.y
                    if rise > px(12) {
                        let foot = CGPoint(x: peak.x + rise * 0.16, y: valley.y - rise * 0.22)
                        let face = CGMutablePath()
                        face.move(to: peak)
                        for k in stride(from: i, through: j, by: -1) { face.addLine(to: pts[k]) }
                        face.addLine(to: foot)
                        face.closeSubpath()
                        ctx.clipped(to: face) {
                            ctx.fillLinear([hex(shade, 0), hex(shade, shadeAlpha * 0.7), hex(shade, shadeAlpha)], [0, 0.35, 1],
                                           from: CGPoint(x: 0, y: foot.y), to: CGPoint(x: 0, y: peak.y))
                        }
                    }
                    i += 24
                }
                i += 1
            }
        }
        return path
    }

    /// Smooth rolling hills: y = base + Σ a·sin(2π f x + p) (units). Optional bright rim along the crest.
    @discardableResult
    public func hills(base: CGFloat, waves: [(a: CGFloat, f: CGFloat, p: CGFloat)], top: UInt32, bottom: UInt32,
                      rim: UInt32? = nil, rimWidth: CGFloat = 3) -> CGPath {
        var pts: [CGPoint] = []
        let steps = 200
        for i in 0...steps {
            let fx = CGFloat(i) / CGFloat(steps)
            var y = base
            for wv in waves { y += wv.a * sin(2 * .pi * wv.f * fx + wv.p) }
            pts.append(CGPoint(x: fx * w, y: px(y)))
        }
        let path = areaPath(pts)
        let maxY = pts.map(\.y).max() ?? h
        ctx.clipped(to: path) {
            ctx.fillLinear([hex(bottom), hex(top)], from: CGPoint(x: 0, y: 0), to: CGPoint(x: 0, y: maxY))
        }
        if let rim {
            let crest = CGMutablePath()
            crest.addLines(between: pts)
            ctx.clipped(to: path) { ctx.stroke(crest, hex(rim, 0.9), width: px(rimWidth)) }
        }
        return path
    }

    /// Height (pixels) of a hill curve at x, matching `hills`.
    public func hillY(base: CGFloat, waves: [(a: CGFloat, f: CGFloat, p: CGFloat)], x: CGFloat) -> CGFloat {
        var y = base
        let fx = x / w
        for wv in waves { y += wv.a * sin(2 * .pi * wv.f * fx + wv.p) }
        return px(y)
    }

    // MARK: Trees

    /// Stylised conifer with optional snow on each tier.
    public func pine(x: CGFloat, base: CGFloat, height H: CGFloat, color: CGColor, snow: CGColor?, lean: CGFloat = 0) {
        let tiers = 5
        let trunkH = H * 0.08
        ctx.setFillColor(mix(color, hex(0x000000), 0.25))
        ctx.fill(CGRect(x: x - H * 0.025, y: base, width: H * 0.05, height: trunkH + H * 0.05))
        let body = H - trunkH
        for i in 0..<tiers {
            let t = CGFloat(i) / CGFloat(tiers)
            let bottomY = base + trunkH + body * t * 0.78
            let apexY = min(base + H, bottomY + body * (0.4 - t * 0.12))
            let half = H * 0.34 * (1 - t * 0.74)
            let cx = x + lean * (bottomY - base)
            let ax = x + lean * (apexY - base)
            let tier = CGMutablePath()
            tier.move(to: CGPoint(x: cx - half, y: bottomY))
            tier.addLine(to: CGPoint(x: ax, y: apexY))
            tier.addLine(to: CGPoint(x: cx + half, y: bottomY))
            tier.addQuadCurve(to: CGPoint(x: cx - half, y: bottomY), control: CGPoint(x: cx, y: bottomY + half * 0.22))
            tier.closeSubpath()
            ctx.fill(tier, color)
            if let snow {
                let capY = apexY - (apexY - bottomY) * 0.55
                let capHalf = half * 0.52
                let cap = CGMutablePath()
                cap.move(to: CGPoint(x: ax - capHalf * 1.05, y: capY))
                cap.addLine(to: CGPoint(x: ax, y: apexY))
                cap.addLine(to: CGPoint(x: ax + capHalf * 1.05, y: capY))
                cap.addQuadCurve(to: CGPoint(x: ax + capHalf * 0.2, y: capY + (apexY - capY) * 0.12),
                                 control: CGPoint(x: ax + capHalf * 0.6, y: capY - (apexY - capY) * 0.25))
                cap.addQuadCurve(to: CGPoint(x: ax - capHalf * 1.05, y: capY),
                                 control: CGPoint(x: ax - capHalf * 0.5, y: capY - (apexY - capY) * 0.3))
                cap.closeSubpath()
                ctx.fill(cap, snow)
                ctx.fill(ellipsePath(CGPoint(x: cx - half * 0.86, y: bottomY + half * 0.05), rx: half * 0.2, ry: half * 0.08), snow)
                ctx.fill(ellipsePath(CGPoint(x: cx + half * 0.86, y: bottomY + half * 0.05), rx: half * 0.2, ry: half * 0.08), snow)
            }
        }
    }

    /// A band of trees; `base` and `height` ranges in units, x in fractions.
    public func forest(_ rng: inout SeededGenerator, count: Int, x: ClosedRange<CGFloat> = 0...1,
                       base: ClosedRange<CGFloat>, height: ClosedRange<CGFloat>,
                       color: UInt32, snow: UInt32?, snowAlpha: CGFloat = 1, baseCurve: ((CGFloat) -> CGFloat)? = nil) {
        var trees: [(CGFloat, CGFloat, CGFloat)] = []
        for _ in 0..<count {
            let tx = rng.range(x) * w
            let b = baseCurve?(tx) ?? px(rng.range(base))
            trees.append((tx, b + px(rng.range(-3...3)), px(rng.range(height))))
        }
        trees.sort { $0.1 > $1.1 }
        for (tx, b, th) in trees {
            pine(x: tx, base: b, height: th, color: hex(color), snow: snow.map { hex($0, snowAlpha) })
        }
    }

    public func birch(x: CGFloat, base: CGFloat, top: CGFloat, width bw: CGFloat, rng: inout SeededGenerator,
                      bark: UInt32 = 0xF3F0EA, mark: UInt32 = 0x2A2623, alpha: CGFloat = 1) {
        let lean = rng.range(-0.015...0.015) * (top - base)
        let trunk = CGMutablePath()
        trunk.move(to: CGPoint(x: x - bw / 2, y: base))
        trunk.addLine(to: CGPoint(x: x - bw * 0.32 + lean, y: top))
        trunk.addLine(to: CGPoint(x: x + bw * 0.32 + lean, y: top))
        trunk.addLine(to: CGPoint(x: x + bw / 2, y: base))
        trunk.closeSubpath()
        ctx.saveGState()
        ctx.setAlpha(alpha)
        ctx.beginTransparencyLayer(auxiliaryInfo: nil)
        ctx.clipped(to: trunk) {
            ctx.fillLinear([hex(bark), hex(bark), mix(hex(bark), hex(0x8A8478), 0.45)], [0, 0.55, 1],
                           from: CGPoint(x: x - bw / 2, y: 0), to: CGPoint(x: x + bw / 2, y: 0))
            var y = base + bw * 0.5
            while y < top {
                let len = bw * rng.range(0.25...0.85)
                let off = rng.range(-0.5...0.5) * (bw - len)
                let tall = bw * rng.range(0.05...0.13)
                let shift = lean * (y - base) / (top - base)
                ctx.fill(ellipsePath(CGPoint(x: x + off + shift, y: y), rx: len / 2, ry: tall / 2), hex(mark, 0.85))
                y += bw * rng.range(0.35...1.2)
            }
        }
        // a few short twigs on the bigger trunks
        if bw > px(20) && alpha >= 1 {
            for _ in 0..<3 {
                let sy = base + (top - base) * rng.range(0.5...0.9)
                let dir: CGFloat = rng.unit() < 0.5 ? -1 : 1
                let sx = x + lean * (sy - base) / (top - base) + dir * bw * 0.3
                let tip = CGPoint(x: sx + dir * bw * rng.range(1.0...2.2), y: sy + bw * rng.range(0.8...1.8))
                let b = CGMutablePath()
                b.move(to: CGPoint(x: sx, y: sy))
                b.addQuadCurve(to: tip, control: CGPoint(x: sx + dir * bw * 0.8, y: sy + bw * 0.2))
                ctx.stroke(b, hex(0x4E463E, 0.85), width: max(1, bw * 0.07))
                let b2 = CGMutablePath()
                b2.move(to: CGPoint(x: (sx + tip.x) / 2, y: (sy + tip.y) / 2))
                b2.addLine(to: CGPoint(x: tip.x + dir * bw * 0.3, y: tip.y + bw * 0.6))
                ctx.stroke(b2, hex(0x4E463E, 0.7), width: max(0.7, bw * 0.035))
            }
        }
        ctx.endTransparencyLayer()
        ctx.restoreGState()
    }

    // MARK: Buildings

    public func house(x: CGFloat, base: CGFloat, width hw: CGFloat, wall: UInt32, roof: UInt32,
                      windows: Int, lit: Bool, chimney: Bool, rng: inout SeededGenerator) -> [CGPoint] {
        let wallH = hw * 0.62
        let body = CGRect(x: x - hw / 2, y: base, width: hw, height: wallH)
        ctx.setFillColor(hex(wall)); ctx.fill(body)
        ctx.clipped(to: CGPath(rect: body, transform: nil)) {
            ctx.fillLinear([hex(0x000000, 0.25), hex(0x000000, 0)], from: CGPoint(x: x + hw / 2, y: 0), to: CGPoint(x: x - hw * 0.1, y: 0))
            for k in 1..<6 {
                let ly = base + wallH * CGFloat(k) / 6
                let l = CGMutablePath(); l.move(to: CGPoint(x: x - hw / 2, y: ly)); l.addLine(to: CGPoint(x: x + hw / 2, y: ly))
                ctx.stroke(l, hex(0x000000, 0.12), width: max(1, hw * 0.01))
            }
        }
        let peak = CGPoint(x: x, y: base + wallH + hw * 0.42)
        if chimney {
            ctx.setFillColor(hex(0x6B4A3A)); ctx.fill(CGRect(x: x + hw * 0.18, y: base + wallH + hw * 0.12, width: hw * 0.1, height: hw * 0.32))
            ctx.fill(ellipsePath(CGPoint(x: x + hw * 0.23, y: base + wallH + hw * 0.44), rx: hw * 0.075, ry: hw * 0.03), hex(0xF4F8FF))
        }
        let roofPath = CGMutablePath()
        roofPath.move(to: CGPoint(x: x - hw * 0.62, y: base + wallH - hw * 0.02))
        roofPath.addLine(to: peak)
        roofPath.addLine(to: CGPoint(x: x + hw * 0.62, y: base + wallH - hw * 0.02))
        roofPath.closeSubpath()
        ctx.fill(roofPath, hex(roof))
        // thick snow on the roof with drips
        let snow = CGMutablePath()
        let t = hw * 0.09
        snow.move(to: CGPoint(x: x - hw * 0.66, y: base + wallH - hw * 0.01))
        snow.addLine(to: CGPoint(x: peak.x, y: peak.y + t * 0.9))
        snow.addLine(to: CGPoint(x: x + hw * 0.66, y: base + wallH - hw * 0.01))
        var sx = x + hw * 0.66
        var drip = false
        while sx > x - hw * 0.66 {
            let nx = sx - hw * rng.range(0.06...0.12)
            let edgeY = base + wallH - hw * 0.01 + (hw * 0.42 + t) * (1 - abs(nx - x) / (hw * 0.62)) * 0 // flat eave
            snow.addQuadCurve(to: CGPoint(x: max(x - hw * 0.66, nx), y: edgeY - (drip ? t * 0.55 : t * 0.15)),
                              control: CGPoint(x: (sx + nx) / 2, y: edgeY - t * (drip ? 0.9 : 0.35)))
            drip.toggle()
            sx = nx
        }
        snow.closeSubpath()
        ctx.fill(snow, hex(0xF6F9FF))
        ctx.clipped(to: snow) {
            ctx.fillLinear([hex(0xB9CBE6, 0.9), hex(0xFFFFFF, 0)], from: CGPoint(x: 0, y: base + wallH - t), to: CGPoint(x: 0, y: base + wallH + hw * 0.2))
        }
        // windows
        var centers: [CGPoint] = []
        let ww = hw * 0.16, wh = hw * 0.15
        for k in 0..<windows {
            let fx = windows == 1 ? 0 : (CGFloat(k) / CGFloat(windows - 1) - 0.5) * hw * 0.5
            let c = CGPoint(x: x + fx, y: base + wallH * 0.52)
            let r = CGRect(x: c.x - ww / 2, y: c.y - wh / 2, width: ww, height: wh)
            ctx.setFillColor(hex(0x2B1D16)); ctx.fill(r.insetBy(dx: -hw * 0.015, dy: -hw * 0.015))
            if lit {
                ctx.clipped(to: CGPath(rect: r, transform: nil)) {
                    ctx.fillLinear([hex(0xFFE7A3), hex(0xFFB347)], from: CGPoint(x: 0, y: r.maxY), to: CGPoint(x: 0, y: r.minY))
                }
            } else {
                ctx.setFillColor(hex(0x2A3550)); ctx.fill(r)
            }
            let bars = CGMutablePath()
            bars.move(to: CGPoint(x: c.x, y: r.minY)); bars.addLine(to: CGPoint(x: c.x, y: r.maxY))
            bars.move(to: CGPoint(x: r.minX, y: c.y)); bars.addLine(to: CGPoint(x: r.maxX, y: c.y))
            ctx.stroke(bars, hex(0x2B1D16), width: max(1, hw * 0.012))
            centers.append(c)
        }
        return centers
    }

    /// Simple deer silhouette standing at `foot`, `size` = body length in pixels.
    public func deer(foot: CGPoint, size s: CGFloat, color: UInt32, facingLeft: Bool = true) {
        ctx.saveGState()
        ctx.translateBy(x: foot.x, y: foot.y)
        if facingLeft { ctx.scaleBy(x: -1, y: 1) }
        let c = hex(color)
        ctx.fill(ellipsePath(CGPoint(x: 0, y: s * 0.62), rx: s * 0.42, ry: s * 0.17), c)
        for (lx, lean) in [(-0.3, -0.03), (-0.2, 0.02), (0.22, -0.02), (0.32, 0.03)] as [(CGFloat, CGFloat)] {
            let leg = CGMutablePath()
            leg.move(to: CGPoint(x: s * lx, y: s * 0.58))
            leg.addLine(to: CGPoint(x: s * (lx + lean), y: 0))
            ctx.stroke(leg, c, width: s * 0.05)
        }
        let neck = CGMutablePath()
        neck.move(to: CGPoint(x: s * 0.28, y: s * 0.68))
        neck.addQuadCurve(to: CGPoint(x: s * 0.46, y: s * 1.02), control: CGPoint(x: s * 0.42, y: s * 0.78))
        ctx.stroke(neck, c, width: s * 0.13)
        ctx.fill(ellipsePath(CGPoint(x: s * 0.53, y: s * 1.04), rx: s * 0.12, ry: s * 0.065), c)
        ctx.fill(ellipsePath(CGPoint(x: s * 0.42, y: s * 1.1), rx: s * 0.03, ry: s * 0.06), c)
        let antlers = CGMutablePath()
        antlers.move(to: CGPoint(x: s * 0.47, y: s * 1.09))
        antlers.addQuadCurve(to: CGPoint(x: s * 0.36, y: s * 1.45), control: CGPoint(x: s * 0.36, y: s * 1.22))
        antlers.move(to: CGPoint(x: s * 0.39, y: s * 1.26)); antlers.addLine(to: CGPoint(x: s * 0.27, y: s * 1.36))
        antlers.move(to: CGPoint(x: s * 0.37, y: s * 1.37)); antlers.addLine(to: CGPoint(x: s * 0.47, y: s * 1.5))
        antlers.move(to: CGPoint(x: s * 0.51, y: s * 1.09))
        antlers.addQuadCurve(to: CGPoint(x: s * 0.6, y: s * 1.42), control: CGPoint(x: s * 0.62, y: s * 1.2))
        antlers.move(to: CGPoint(x: s * 0.59, y: s * 1.25)); antlers.addLine(to: CGPoint(x: s * 0.7, y: s * 1.33))
        ctx.stroke(antlers, c, width: s * 0.025)
        ctx.restoreGState()
    }

    // MARK: Snowfall

    /// Static falling snow; some flakes big and soft like out-of-focus bokeh.
    public func snowfall(_ rng: inout SeededGenerator, count: Int, size: ClosedRange<CGFloat>, alpha: ClosedRange<CGFloat>,
                         blur: CGFloat = 0) {
        var r2 = rng
        func paint(_ c: CGContext) {
            for _ in 0..<count {
                let p = CGPoint(x: r2.unit() * w, y: r2.unit() * h)
                let r = px(r2.range(size))
                c.fillRadial([hex(0xFFFFFF, r2.range(alpha)), hex(0xFFFFFF, 0)], [0.5, 1], center: p, radius: r, extend: false)
            }
        }
        if blur > 0 {
            blurLayer(scale: 0.5, radius: px(blur), paint)
        } else {
            paint(ctx)
        }
        rng = r2
    }

    /// Glittering specks on a snow field.
    public func sparkles(_ rng: inout SeededGenerator, count: Int, yMax: CGFloat, color: UInt32 = 0xFFFFFF) {
        for _ in 0..<count {
            let p = CGPoint(x: rng.unit() * w, y: rng.unit() * px(yMax))
            ctx.circle(p, px(rng.range(0.3...1.0)), hex(color, rng.range(0.3...0.9)))
        }
    }
}
