import CoreGraphics
import Foundation
import SnowCore

/// The ten winter wallpapers, drawn entirely in code.
public enum WinterWallpaper: Int, CaseIterable, Sendable {
    case auroraNight, moonlitCabin, goldenForest, frozenLake, snowyVillage
    case christmasTree, blueDawnPeaks, birchForest, milkyWay, pinkSunset

    public var title: String {
        switch self {
        case .auroraNight: return "오로라의 밤"
        case .moonlitCabin: return "달빛 오두막"
        case .goldenForest: return "황금빛 설원 숲"
        case .frozenLake: return "얼어붙은 호수"
        case .snowyVillage: return "눈 내리는 마을"
        case .christmasTree: return "크리스마스 트리"
        case .blueDawnPeaks: return "푸른 새벽 설산"
        case .birchForest: return "자작나무 숲"
        case .milkyWay: return "은하수 설원"
        case .pinkSunset: return "분홍 노을 언덕"
        }
    }

    public var fileStem: String { "winter-\(String(format: "%02d", rawValue + 1))" }

    /// Renders the wallpaper at an exact pixel size. Same input → same pixels.
    public func render(pixelSize: CGSize) -> CGImage {
        let ctx = Canvas.context(width: Int(pixelSize.width), height: Int(pixelSize.height))
        let k = LandscapeKit(ctx: ctx, w: pixelSize.width, h: pixelSize.height)
        var rng = SeededGenerator(seed: UInt64(rawValue + 1) &* 7919)
        switch self {
        case .auroraNight: Scenes.aurora(k, &rng)
        case .moonlitCabin: Scenes.cabin(k, &rng)
        case .goldenForest: Scenes.golden(k, &rng)
        case .frozenLake: Scenes.lake(k, &rng)
        case .snowyVillage: Scenes.village(k, &rng)
        case .christmasTree: Scenes.christmas(k, &rng)
        case .blueDawnPeaks: Scenes.dawn(k, &rng)
        case .birchForest: Scenes.birches(k, &rng)
        case .milkyWay: Scenes.milkyWay(k, &rng)
        case .pinkSunset: Scenes.pink(k, &rng)
        }
        k.grain()
        return ctx.makeImage()!
    }
}

private typealias Wave = (a: CGFloat, f: CGFloat, p: CGFloat)

private enum Scenes {
    static func starCount(_ k: LandscapeKit, _ density: CGFloat) -> Int { Int(k.w / k.u * density) }

    // MARK: 1 오로라의 밤

    static func aurora(_ k: LandscapeKit, _ rng: inout SeededGenerator) {
        k.sky([(0, 0x1C3D70), (0.35, 0x0F2650), (0.7, 0x071633), (1, 0x030A1D)])
        k.stars(&rng, count: starCount(k, 0.45), minY: 0.3, maxR: 1.2)
        var r2 = rng
        k.blurLayer(scale: 0.25, radius: k.px(12), blend: .screen) { c in
            let curtains: [(CGFloat, CGFloat, CGFloat, UInt32, CGFloat)] = [
                (560, 70, 260, 0x3DF2A0, 0.3), (630, 60, 220, 0x29D3C8, 2.1), (700, 50, 200, 0x9B6CF2, 4.0),
            ]
            for (baseY, amp, height, color, phase) in curtains {
                let steps = 220
                var line: [CGPoint] = []
                for i in 0..<steps {
                    let fx = CGFloat(i) / CGFloat(steps)
                    let x = fx * k.w
                    let yb = k.px(baseY + amp * sin(fx * 2 * .pi * 1.3 + phase) + amp * 0.4 * sin(fx * 2 * .pi * 3.1 + phase * 1.7))
                    let swell = 0.35 + 0.65 * pow(0.5 + 0.5 * sin(fx * 2 * .pi * 2.2 + phase * 0.6), 2)
                    let hgt = k.px(height * swell * r2.range(0.8...1.2))
                    c.saveGState()
                    c.clip(to: CGRect(x: x, y: yb, width: k.w / CGFloat(steps) + 1, height: hgt))
                    c.fillLinear([hex(color, 0.95), hex(color, 0.45), hex(color, 0)], [0, 0.22, 1],
                                 from: CGPoint(x: 0, y: yb), to: CGPoint(x: 0, y: yb + hgt))
                    c.restoreGState()
                    line.append(CGPoint(x: x, y: yb))
                }
                let base = CGMutablePath()
                base.addLines(between: line)
                c.stroke(base, hex(color, 0.9), width: k.px(3))
            }
        }
        rng = r2
        let far = k.ridgePoints(&rng, base: 250, amp: 55, peaks: [(0.18, 130, 0.12), (0.6, 170, 0.15), (0.86, 100, 0.1)])
        k.mountains(far, top: 0x2E4A80, bottom: 0x1C3159, snow: 0xA9BEE6, snowLine: 300, rng: &rng, shadeAlpha: 0.32)
        let near = k.ridgePoints(&rng, base: 175, amp: 40, peaks: [(0.35, 70, 0.14), (0.75, 60, 0.12)])
        k.mountains(near, top: 0x18294F, bottom: 0x0F1C38, snow: 0x7F97C8, snowLine: 225, rng: &rng)
        k.forest(&rng, count: 80, base: 125...165, height: 50...120, color: 0x08142B, snow: 0x6F86B5, snowAlpha: 0.6)
        let field: [Wave] = [(14, 0.7, 0.4), (8, 2.3, 1.7)]
        k.hills(base: 115, waves: field, top: 0xC9D8F2, bottom: 0x8EA5CF, rim: 0xEAF2FF)
        k.glow(CGPoint(x: k.fx(0.45), y: k.px(90)), radius: k.px(650), color: 0x3DF2A0, alpha: 0.16)
        k.sparkles(&rng, count: starCount(k, 0.25), yMax: 120)
        k.pine(x: k.fx(0.05), base: k.px(40), height: k.px(420), color: hex(0x061026), snow: hex(0x9FB4DC))
        k.pine(x: k.fx(0.95), base: k.px(30), height: k.px(360), color: hex(0x061026), snow: hex(0x9FB4DC))
    }

    // MARK: 2 달빛 오두막

    static func cabin(_ k: LandscapeKit, _ rng: inout SeededGenerator) {
        k.sky([(0, 0x3E5A94), (0.4, 0x1E3466), (1, 0x0A1633)])
        k.stars(&rng, count: starCount(k, 0.25), minY: 0.45)
        k.moon(CGPoint(x: k.fx(0.8), y: k.px(810)), r: k.px(52))
        let far: [Wave] = [(22, 1.2, 0.3), (10, 3.1, 1.1)]
        k.hills(base: 330, waves: far, top: 0x3E5A92, bottom: 0x2C4677, rim: 0x8FA8D6)
        k.forest(&rng, count: 110, base: 0...0, height: 35...85, color: 0x1A2C55, snow: 0x8DA3CF, snowAlpha: 0.85,
                 baseCurve: { x in k.hillY(base: 330, waves: far, x: x) - k.px(4) })
        let mid: [Wave] = [(18, 0.6, 2.0), (6, 2.7, 0.2)]
        k.hills(base: 235, waves: mid, top: 0xDCE6F7, bottom: 0x9FB3D9, rim: 0xFFFFFF)
        let cx = k.fx(0.38)
        let base = k.hillY(base: 235, waves: mid, x: cx) - k.px(14)
        for (fx, hgt) in [(0.24, 270.0), (0.29, 200.0), (0.52, 230.0), (0.57, 300.0)] as [(CGFloat, CGFloat)] {
            let x = k.fx(fx)
            k.pine(x: x, base: k.hillY(base: 235, waves: mid, x: x) - k.px(12), height: k.px(hgt),
                   color: hex(0x13254A), snow: hex(0xEAF1FF))
        }
        let windows = k.house(x: cx, base: base, width: k.px(240), wall: 0x5B3A29, roof: 0x3B2A26, windows: 2,
                              lit: true, chimney: true, rng: &rng)
        let chimneyTop = CGPoint(x: cx + k.px(240) * 0.23, y: base + k.px(240) * (0.62 + 0.46))
        k.blurLayer(scale: 0.25, radius: k.px(9), alpha: 0.7) { c in
            for i in 0..<9 {
                let t = CGFloat(i) / 8
                let p = CGPoint(x: chimneyTop.x + k.px(60) * t + k.px(14) * sin(t * 6), y: chimneyTop.y + k.px(150) * t)
                c.circle(p, k.px(10 + 26 * t), hex(0xC8D3EA, 0.4 * (1 - t) + 0.05))
            }
        }
        k.blurLayer(scale: 0.25, radius: k.px(28), blend: .screen) { c in
            for wc in windows { c.circle(wc, k.px(42), hex(0xFFB347, 0.75)) }
            c.fill(ellipsePath(CGPoint(x: cx, y: base - k.px(18)), rx: k.px(220), ry: k.px(46)), hex(0xFFB347, 0.35))
        }
        let front: [Wave] = [(16, 0.5, 4.0), (7, 1.9, 0.6)]
        k.hills(base: 120, waves: front, top: 0xEEF3FC, bottom: 0xB8C8E6, rim: 0xFFFFFF)
        k.sparkles(&rng, count: starCount(k, 0.3), yMax: 140)
        k.pine(x: k.fx(0.92), base: k.px(30), height: k.px(560), color: hex(0x0E1C3C), snow: hex(0xEAF1FF))
        k.pine(x: k.fx(0.035), base: k.px(20), height: k.px(470), color: hex(0x0E1C3C), snow: hex(0xEAF1FF))
        k.snowfall(&rng, count: starCount(k, 0.3), size: 0.8...2.2, alpha: 0.5...0.9)
        k.snowfall(&rng, count: starCount(k, 0.03), size: 5...11, alpha: 0.25...0.5, blur: 3)
    }

    // MARK: 3 황금빛 설원 숲

    static func golden(_ k: LandscapeKit, _ rng: inout SeededGenerator) {
        k.sky([(0, 0xFDF0DC), (0.3, 0xF8D9AE), (0.55, 0xF0BE92), (0.8, 0xC4A7B8), (1, 0x8E9CC4)])
        let sunC = CGPoint(x: k.fx(0.7), y: k.px(395))
        k.sun(sunC, r: k.px(38), core: 0xFFF7E6, halo: 0xFFD59A, haloRadius: k.px(760))
        let far = k.ridgePoints(&rng, base: 420, amp: 45, peaks: [(0.28, 130, 0.2), (0.82, 95, 0.18)])
        k.mountains(far, top: 0xD7BFB2, bottom: 0xE6D0C1, snow: 0xFBF1EA, snowLine: 470, rng: &rng, shade: 0x7A5E5E, shadeAlpha: 0.14)
        k.fog(y: 405, height: 130, color: 0xFFF1DE, alpha: 0.75)
        k.forest(&rng, count: 140, base: 330...365, height: 55...110, color: 0xB9A196, snow: 0xFFF1E3, snowAlpha: 0.85)
        k.fog(y: 345, height: 90, color: 0xFFEBD3, alpha: 0.55)
        k.forest(&rng, count: 80, base: 250...290, height: 100...180, color: 0x7A6358, snow: 0xFFEBD6)
        var r2 = rng
        k.blurLayer(scale: 0.25, radius: k.px(8), blend: .screen, alpha: 0.4) { c in
            for _ in 0..<7 {
                let a = r2.range(-2.6 ... -1.9)
                let spread = r2.range(0.02...0.05)
                let len = k.px(1400)
                let ray = CGMutablePath()
                ray.move(to: sunC)
                ray.addLine(to: CGPoint(x: sunC.x + cos(a - spread) * len, y: sunC.y + sin(a - spread) * len))
                ray.addLine(to: CGPoint(x: sunC.x + cos(a + spread) * len, y: sunC.y + sin(a + spread) * len))
                ray.closeSubpath()
                c.fill(ray, hex(0xFFE7BF, 0.5))
            }
        }
        rng = r2
        let field: [Wave] = [(16, 0.6, 1.0), (6, 2.1, 2.2)]
        k.hills(base: 205, waves: field, top: 0xFFF5E8, bottom: 0xE8D3C8, rim: 0xFFFFFF)
        k.fog(y: 40, height: 140, color: 0x9AA0C8, alpha: 0.3)
        k.forest(&rng, count: 18, x: 0...0.2, base: 110...180, height: 260...420, color: 0x3D3029, snow: 0xFFE6C9)
        k.forest(&rng, count: 14, x: 0.86...1, base: 110...170, height: 240...380, color: 0x3D3029, snow: 0xFFE6C9)
        let deerX = k.fx(0.78)
        k.deer(foot: CGPoint(x: deerX, y: k.hillY(base: 205, waves: field, x: deerX) - k.px(10)), size: k.px(80), color: 0x3A2C25)
        k.sparkles(&rng, count: starCount(k, 0.3), yMax: 200, color: 0xFFF6E3)
        k.snowfall(&rng, count: starCount(k, 0.12), size: 0.8...1.8, alpha: 0.4...0.8)
    }

    // MARK: 4 얼어붙은 호수

    static func lake(_ k: LandscapeKit, _ rng: inout SeededGenerator) {
        k.sky([(0.38, 0xF7D2C2), (0.52, 0xE9AABB), (0.72, 0x8F8DC4), (1, 0x2D3A6B)])
        k.stars(&rng, count: starCount(k, 0.06), minY: 0.78, maxR: 0.9)
        k.glow(CGPoint(x: k.fx(0.5), y: k.px(480)), radius: k.px(650), color: 0xFFD9C7, alpha: 0.35)
        let ridge = k.ridgePoints(&rng, base: 470, amp: 55, rough: 0.6, peaks: [(0.24, 170, 0.18), (0.55, 230, 0.16), (0.8, 150, 0.17)])
        k.mountains(ridge, top: 0x6E6BA6, bottom: 0x938AB8, snow: 0xF6E3EC, snowLine: 560, rng: &rng, shade: 0x2E2A5A, shadeAlpha: 0.3)
        k.forest(&rng, count: 90, base: 428...440, height: 30...70, color: 0x3E3A6A, snow: 0xF4E6EF, snowAlpha: 0.9)
        let shore = k.px(430)
        let lakeBottom = k.px(130)
        if let snapshot = k.ctx.makeImage() {
            k.ctx.saveGState()
            k.ctx.clip(to: CGRect(x: 0, y: lakeBottom, width: k.w, height: shore - lakeBottom))
            k.ctx.translateBy(x: 0, y: 2 * shore)
            k.ctx.scaleBy(x: 1, y: -1)
            k.ctx.setAlpha(0.6)
            k.ctx.draw(snapshot, in: CGRect(x: 0, y: 0, width: k.w, height: k.h))
            k.ctx.restoreGState()
        }
        k.ctx.saveGState()
        k.ctx.clip(to: CGRect(x: 0, y: lakeBottom, width: k.w, height: shore - lakeBottom))
        k.ctx.fillLinear([hex(0x7F95C9, 0.55), hex(0xB7C3E6, 0.35)], from: CGPoint(x: 0, y: lakeBottom), to: CGPoint(x: 0, y: shore))
        for _ in 0..<Int(k.w / k.u * 0.06) {
            let y = rng.range(lakeBottom...shore)
            let x = rng.unit() * k.w
            let len = k.px(rng.range(40...260))
            let l = CGMutablePath(); l.move(to: CGPoint(x: x, y: y)); l.addLine(to: CGPoint(x: x + len, y: y))
            k.ctx.stroke(l, hex(0xFFFFFF, rng.range(0.08...0.25)), width: k.px(rng.range(0.5...1.5)))
        }
        for _ in 0..<14 {
            var p = CGPoint(x: rng.unit() * k.w, y: rng.range(lakeBottom...shore))
            let crack = CGMutablePath(); crack.move(to: p)
            for _ in 0..<5 {
                p = CGPoint(x: p.x + k.px(rng.range(-50...50)), y: p.y + k.px(rng.range(-20...20)))
                crack.addLine(to: p)
            }
            k.ctx.stroke(crack, hex(0xFFFFFF, 0.22), width: k.px(0.8))
        }
        k.ctx.restoreGState()
        let strip = CGMutablePath()
        strip.move(to: CGPoint(x: 0, y: shore - k.px(5)))
        for i in 0...120 {
            let fx = CGFloat(i) / 120
            strip.addLine(to: CGPoint(x: fx * k.w, y: shore + k.px(3 + 3 * sin(fx * 13) + 2 * sin(fx * 31))))
        }
        strip.addLine(to: CGPoint(x: k.w, y: shore - k.px(5)))
        strip.closeSubpath()
        k.ctx.fill(strip, hex(0xF6EEF5))
        k.ctx.clipped(to: strip) {
            k.ctx.fillLinear([hex(0xB9B4D8, 0.8), hex(0xFFFFFF, 0)], from: CGPoint(x: 0, y: shore - k.px(5)), to: CGPoint(x: 0, y: shore + k.px(4)))
        }
        let front: [Wave] = [(18, 0.55, 2.4), (6, 2.2, 0.3)]
        k.hills(base: 115, waves: front, top: 0xF8F2F8, bottom: 0xD6D4EA, rim: 0xFFFFFF)
        k.pine(x: k.fx(0.08), base: k.px(60), height: k.px(380), color: hex(0x2E2A55), snow: hex(0xF7ECF4))
        k.pine(x: k.fx(0.14), base: k.px(80), height: k.px(240), color: hex(0x2E2A55), snow: hex(0xF7ECF4))
        k.sparkles(&rng, count: starCount(k, 0.25), yMax: 130)
    }

    // MARK: 5 눈 내리는 마을

    static func village(_ k: LandscapeKit, _ rng: inout SeededGenerator) {
        k.sky([(0, 0x36528C), (0.45, 0x1D2F5E), (1, 0x0A1532)])
        k.stars(&rng, count: starCount(k, 0.2), minY: 0.5)
        k.moon(CGPoint(x: k.fx(0.14), y: k.px(830)), r: k.px(36))
        let far: [Wave] = [(25, 0.9, 0.8), (10, 2.6, 2.0)]
        k.hills(base: 390, waves: far, top: 0x2B4475, bottom: 0x23396A, rim: 0x6F8BC0)
        k.forest(&rng, count: 120, base: 0...0, height: 30...70, color: 0x142449, snow: 0x7C93C4, snowAlpha: 0.75,
                 baseCurve: { x in k.hillY(base: 390, waves: far, x: x) - k.px(3) })
        let mid: [Wave] = [(14, 0.8, 1.4), (5, 3.0, 0.1)]
        k.hills(base: 300, waves: mid, top: 0xD6E1F4, bottom: 0xA8BADB, rim: 0xFFFFFF)
        let walls: [UInt32] = [0x8C3B3B, 0x3B5B8C, 0x9A7B3E, 0x5B3B8C, 0x3B7C6B, 0xA0522D]
        let roofs: [UInt32] = [0x4A2A2A, 0x2E2E44, 0x3D2B1F, 0x2F3B2A]
        var lights: [CGPoint] = []
        var chimneys: [CGPoint] = []
        for i in 0..<8 {
            let x = k.fx(0.07 + CGFloat(i) * 0.12 + rng.range(-0.02...0.02))
            let wdt = k.px(rng.range(70...100))
            let b = k.hillY(base: 300, waves: mid, x: x) - k.px(6)
            let chimney = rng.unit() < 0.6
            lights += k.house(x: x, base: b, width: wdt, wall: walls[i % walls.count], roof: roofs[i % roofs.count],
                              windows: 1 + Int(rng.unit() * 2), lit: rng.unit() < 0.85, chimney: chimney, rng: &rng)
            if chimney { chimneys.append(CGPoint(x: x + wdt * 0.23, y: b + wdt * 1.08)) }
        }
        // church
        let chx = k.fx(0.63)
        let chb = k.hillY(base: 300, waves: mid, x: chx) - k.px(4)
        let cw = k.px(110)
        k.ctx.setFillColor(hex(0xD9D2C4)); k.ctx.fill(CGRect(x: chx - cw / 2, y: chb, width: cw, height: cw * 0.9))
        let steeple = CGMutablePath()
        steeple.move(to: CGPoint(x: chx - cw * 0.22, y: chb + cw * 0.9))
        steeple.addLine(to: CGPoint(x: chx, y: chb + cw * 2.1))
        steeple.addLine(to: CGPoint(x: chx + cw * 0.22, y: chb + cw * 0.9))
        steeple.closeSubpath()
        k.ctx.fill(steeple, hex(0x3A3F5C))
        let cross = CGMutablePath()
        cross.move(to: CGPoint(x: chx, y: chb + cw * 2.1)); cross.addLine(to: CGPoint(x: chx, y: chb + cw * 2.35))
        cross.move(to: CGPoint(x: chx - cw * 0.07, y: chb + cw * 2.25)); cross.addLine(to: CGPoint(x: chx + cw * 0.07, y: chb + cw * 2.25))
        k.ctx.stroke(cross, hex(0xE8D9A8), width: k.px(3))
        let rose = CGPoint(x: chx, y: chb + cw * 0.6)
        k.ctx.fill(circlePath(rose, cw * 0.12), hex(0xFFD27A))
        lights.append(rose)
        let front: [Wave] = [(10, 0.7, 3.0), (4, 2.4, 1.2)]
        k.hills(base: 190, waves: front, top: 0xE3EBF8, bottom: 0xB3C4E2, rim: 0xFFFFFF)
        var frontHouses: [CGPoint] = []
        for i in 0..<5 {
            let x = k.fx(0.12 + CGFloat(i) * 0.19 + rng.range(-0.02...0.02))
            let wdt = k.px(rng.range(130...170))
            let b = k.hillY(base: 190, waves: front, x: x) - k.px(8)
            lights += k.house(x: x, base: b, width: wdt, wall: walls[(i + 3) % walls.count], roof: roofs[(i + 1) % roofs.count],
                              windows: 2, lit: true, chimney: i % 2 == 0, rng: &rng)
            if i % 2 == 0 { chimneys.append(CGPoint(x: x + wdt * 0.23, y: b + wdt * 1.08)) }
            frontHouses.append(CGPoint(x: x, y: b + wdt * 0.62))
        }
        // string lights between the front houses
        let bulbs: [UInt32] = [0xFF5A5A, 0xFFD84D, 0x5AD1FF, 0x7CFF8A]
        var bulbPoints: [(CGPoint, UInt32)] = []
        for i in 0..<(frontHouses.count - 1) {
            let a = frontHouses[i], b = frontHouses[i + 1]
            let wire = CGMutablePath()
            wire.move(to: a)
            let ctl = CGPoint(x: (a.x + b.x) / 2, y: min(a.y, b.y) - k.px(50))
            wire.addQuadCurve(to: b, control: ctl)
            k.ctx.stroke(wire, hex(0x1B1F33, 0.8), width: k.px(1.2))
            for j in 1..<12 {
                let t = CGFloat(j) / 12
                let p = CGPoint(x: (1 - t) * (1 - t) * a.x + 2 * (1 - t) * t * ctl.x + t * t * b.x,
                                y: (1 - t) * (1 - t) * a.y + 2 * (1 - t) * t * ctl.y + t * t * b.y)
                let col = bulbs[(i * 11 + j) % bulbs.count]
                k.ctx.circle(p, k.px(3.2), hex(col))
                bulbPoints.append((p, col))
            }
        }
        k.blurLayer(scale: 0.25, radius: k.px(12), blend: .screen) { c in
            for p in lights { c.circle(p, k.px(30), hex(0xFFB347, 0.6)) }
            for (p, col) in bulbPoints { c.circle(p, k.px(9), hex(col, 0.8)) }
        }
        k.blurLayer(scale: 0.25, radius: k.px(8), alpha: 0.55) { c in
            for ch in chimneys {
                for i in 0..<7 {
                    let t = CGFloat(i) / 6
                    c.circle(CGPoint(x: ch.x + k.px(40) * t, y: ch.y + k.px(110) * t), k.px(6 + 18 * t), hex(0xC8D3EA, 0.4 * (1 - t) + 0.05))
                }
            }
        }
        let fg: [Wave] = [(12, 0.5, 0.9), (5, 1.8, 2.2)]
        k.hills(base: 85, waves: fg, top: 0xEEF3FC, bottom: 0xBCCBE6, rim: 0xFFFFFF)
        k.pine(x: k.fx(0.96), base: k.px(20), height: k.px(420), color: hex(0x0E1C3C), snow: hex(0xEAF1FF))
        k.sparkles(&rng, count: starCount(k, 0.25), yMax: 100)
        k.snowfall(&rng, count: starCount(k, 0.55), size: 0.8...2.4, alpha: 0.5...0.95)
        k.snowfall(&rng, count: starCount(k, 0.04), size: 5...12, alpha: 0.25...0.5, blur: 3)
    }

    // MARK: 6 크리스마스 트리

    static func christmas(_ k: LandscapeKit, _ rng: inout SeededGenerator) {
        k.sky([(0, 0x2A3C70), (0.5, 0x142452), (1, 0x070F28)])
        var r2 = rng
        k.blurLayer(scale: 0.25, radius: k.px(10), blend: .screen, alpha: 0.9) { c in
            let colors: [UInt32] = [0xFFC46B, 0xFF7A7A, 0x7AD7FF, 0xFFE9A8, 0xB98CFF]
            for _ in 0..<70 {
                let p = CGPoint(x: r2.unit() * k.w, y: k.px(r2.range(300...980)))
                c.circle(p, k.px(r2.range(14...46)), hex(colors[Int(r2.unit() * 5) % 5], r2.range(0.2...0.55)))
            }
        }
        rng = r2
        let ground: [Wave] = [(10, 0.6, 1.1), (4, 2.0, 0.4)]
        k.hills(base: 165, waves: ground, top: 0xE9F0FB, bottom: 0xAFC0E0, rim: 0xFFFFFF)
        k.forest(&rng, count: 10, x: 0...0.16, base: 140...170, height: 150...260, color: 0x0D1D3D, snow: 0xDDE7F7)
        k.forest(&rng, count: 10, x: 0.84...1, base: 140...170, height: 150...260, color: 0x0D1D3D, snow: 0xDDE7F7)
        let cx = k.fx(0.5)
        let base = k.px(150)
        let H = k.px(700)
        k.ctx.setFillColor(hex(0x4A2E1E)); k.ctx.fill(CGRect(x: cx - H * 0.035, y: base, width: H * 0.07, height: H * 0.1))
        let tiers = 7
        var outline = CGMutablePath()
        var tierShapes: [(CGPath, CGFloat, CGFloat, CGFloat)] = []
        for i in 0..<tiers {
            let t = CGFloat(i) / CGFloat(tiers)
            let bottomY = base + H * 0.08 + H * 0.84 * t
            let apexY = min(base + H, bottomY + H * (0.24 - t * 0.08))
            let half = H * 0.38 * (1 - t * 0.82)
            let tier = CGMutablePath()
            tier.move(to: CGPoint(x: cx - half, y: bottomY))
            tier.addLine(to: CGPoint(x: cx, y: apexY))
            tier.addLine(to: CGPoint(x: cx + half, y: bottomY))
            tier.addQuadCurve(to: CGPoint(x: cx - half, y: bottomY), control: CGPoint(x: cx, y: bottomY + half * 0.2))
            tier.closeSubpath()
            tierShapes.append((tier, bottomY, apexY, half))
            outline.addPath(tier)
        }
        for (tier, bottomY, apexY, half) in tierShapes {
            k.ctx.clipped(to: tier) {
                k.ctx.fillLinear([hex(0x0E4A28), hex(0x1F7A45), hex(0x2E9A58)], [0, 0.6, 1],
                                 from: CGPoint(x: cx + half, y: bottomY), to: CGPoint(x: cx - half * 0.3, y: apexY))
            }
            k.ctx.fill(ellipsePath(CGPoint(x: cx - half * 0.88, y: bottomY + half * 0.04), rx: half * 0.16, ry: half * 0.06), hex(0xF4F8FF))
            k.ctx.fill(ellipsePath(CGPoint(x: cx + half * 0.88, y: bottomY + half * 0.04), rx: half * 0.16, ry: half * 0.06), hex(0xF4F8FF))
        }
        outline = outline.mutableCopy()!
        k.ctx.clipped(to: outline) {
            for (_, bottomY, apexY, half) in tierShapes.dropLast() {
                let y = bottomY + (apexY - bottomY) * 0.32
                let g = CGMutablePath()
                g.move(to: CGPoint(x: cx - half, y: y + half * 0.15))
                g.addQuadCurve(to: CGPoint(x: cx + half, y: y + half * 0.05), control: CGPoint(x: cx, y: y - half * 0.25))
                k.ctx.stroke(g, hex(0xF5C451), width: k.px(4))
                k.ctx.stroke(g, hex(0xFFF0B3, 0.6), width: k.px(1.4))
            }
        }
        func inside(_ y: CGFloat) -> CGFloat {
            let t = (y - base - H * 0.08) / (H * 0.92)
            return max(0, H * 0.36 * (1 - t))
        }
        let ballColors: [UInt32] = [0xE63946, 0xF4C430, 0x3A86FF, 0xF1F1F1, 0xC77DFF]
        var lightsPts: [CGPoint] = []
        for i in 0..<34 {
            let y = base + H * rng.range(0.14...0.82)
            let half = inside(y) * 0.8
            let p = CGPoint(x: cx + rng.range(-1...1) * half, y: y)
            let r = k.px(rng.range(9...15))
            let col = hex(ballColors[i % ballColors.count])
            k.ctx.fill(circlePath(p, r), col)
            k.ctx.clipped(to: circlePath(p, r)) {
                k.ctx.fillRadial([hex(0xFFFFFF, 0.65), hex(0xFFFFFF, 0), hex(0x000000, 0.3)], [0, 0.45, 1], center: p, radius: r,
                                 startCenter: CGPoint(x: p.x - r * 0.35, y: p.y + r * 0.35))
            }
            k.ctx.setFillColor(hex(0xD4AF37)); k.ctx.fill(CGRect(x: p.x - r * 0.25, y: p.y + r * 0.85, width: r * 0.5, height: r * 0.3))
        }
        for _ in 0..<80 {
            let y = base + H * rng.range(0.12...0.86)
            let p = CGPoint(x: cx + rng.range(-1...1) * inside(y) * 0.9, y: y)
            k.ctx.circle(p, k.px(2.6), hex(0xFFF3C4))
            lightsPts.append(p)
        }
        let starC = CGPoint(x: cx, y: base + H + k.px(18))
        let star = CGMutablePath()
        for i in 0..<10 {
            let a = CGFloat(i) * .pi / 5 + .pi / 2
            let r = i % 2 == 0 ? k.px(46) : k.px(19)
            let p = CGPoint(x: starC.x + cos(a) * r, y: starC.y + sin(a) * r)
            if i == 0 { star.move(to: p) } else { star.addLine(to: p) }
        }
        star.closeSubpath()
        k.blurLayer(scale: 0.25, radius: k.px(9), blend: .screen) { c in
            for p in lightsPts { c.circle(p, k.px(9), hex(0xFFE7A0, 0.85)) }
            c.circle(starC, k.px(62), hex(0xFFE08A, 0.5))
        }
        k.ctx.clipped(to: star) {
            k.ctx.fillLinear([hex(0xFFF3B0), hex(0xF5C451), hex(0xD49A1F)], [0, 0.5, 1],
                             from: CGPoint(x: starC.x - k.px(30), y: starC.y + k.px(40)), to: CGPoint(x: starC.x + k.px(30), y: starC.y - k.px(40)))
        }
        k.ctx.stroke(star, hex(0xB07A12), width: k.px(1.2))
        let gifts: [(CGFloat, CGFloat, CGFloat, UInt32, UInt32)] = [
            (-0.2, 90, 70, 0xE63946, 0xF5C451), (-0.08, 70, 55, 0x2A9D8F, 0xE63946), (0.07, 100, 60, 0x5E60CE, 0xFFFFFF), (0.2, 75, 80, 0xF4A261, 0x2E7D32),
        ]
        for (fx, gw, gh, body, ribbon) in gifts {
            let r = CGRect(x: cx + H * fx - k.px(gw) / 2, y: base - k.px(6), width: k.px(gw), height: k.px(gh))
            k.ctx.setFillColor(hex(body)); k.ctx.fill(r)
            k.ctx.clipped(to: CGPath(rect: r, transform: nil)) {
                k.ctx.fillLinear([hex(0x000000, 0.25), hex(0x000000, 0)], from: CGPoint(x: r.maxX, y: 0), to: CGPoint(x: r.midX, y: 0))
            }
            k.ctx.setFillColor(hex(ribbon))
            k.ctx.fill(CGRect(x: r.midX - k.px(5), y: r.minY, width: k.px(10), height: r.height))
            k.ctx.fill(CGRect(x: r.minX, y: r.midY - k.px(5), width: r.width, height: k.px(10)))
            k.ctx.fill(ellipsePath(CGPoint(x: r.midX - k.px(10), y: r.maxY + k.px(6)), rx: k.px(11), ry: k.px(7)), hex(ribbon))
            k.ctx.fill(ellipsePath(CGPoint(x: r.midX + k.px(10), y: r.maxY + k.px(6)), rx: k.px(11), ry: k.px(7)), hex(ribbon))
        }
        k.sparkles(&rng, count: starCount(k, 0.25), yMax: 160)
        k.snowfall(&rng, count: starCount(k, 0.35), size: 0.8...2.2, alpha: 0.45...0.9)
        k.snowfall(&rng, count: starCount(k, 0.03), size: 5...11, alpha: 0.2...0.45, blur: 3)
    }

    // MARK: 7 푸른 새벽 설산

    static func dawn(_ k: LandscapeKit, _ rng: inout SeededGenerator) {
        k.sky([(0, 0xDDE9F8), (0.25, 0xA9C6EC), (0.55, 0x4F78B8), (1, 0x0E1E45)])
        k.stars(&rng, count: starCount(k, 0.06), minY: 0.8, maxR: 0.9)
        k.glow(CGPoint(x: k.fx(0.62), y: k.px(470)), radius: k.px(720), color: 0xFFFFFF, alpha: 0.28)
        let far = k.ridgePoints(&rng, base: 430, amp: 70, rough: 0.6,
                                peaks: [(0.14, 170, 0.14), (0.44, 240, 0.15), (0.7, 300, 0.14), (0.9, 190, 0.12)])
        k.mountains(far, top: 0x9DB4DA, bottom: 0xB8CAE6, snow: 0xF2F7FD, snowLine: 480, rng: &rng, shade: 0x3B5A93, shadeAlpha: 0.38)
        k.fog(y: 425, height: 150, color: 0xE3EDF9, alpha: 0.85)
        let mid = k.ridgePoints(&rng, base: 300, amp: 55, rough: 0.56, peaks: [(0.3, 160, 0.14), (0.63, 120, 0.12)])
        k.mountains(mid, top: 0x5E7DB3, bottom: 0x7D97C7, snow: 0xE2EBF8, snowLine: 360, rng: &rng, shade: 0x203A6E, shadeAlpha: 0.4)
        k.fog(y: 290, height: 110, color: 0xDCE6F5, alpha: 0.55)
        k.forest(&rng, count: 170, base: 120...170, height: 60...150, color: 0x12223F, snow: 0x4E6A9C, snowAlpha: 0.6)
        let field: [Wave] = [(10, 0.7, 0.6), (5, 2.2, 1.9)]
        k.hills(base: 92, waves: field, top: 0xCFDDF2, bottom: 0x93AACF, rim: 0xEAF2FF)
        k.sparkles(&rng, count: starCount(k, 0.2), yMax: 95)
    }

    // MARK: 8 자작나무 숲

    static func birches(_ k: LandscapeKit, _ rng: inout SeededGenerator) {
        k.sky([(0, 0xF2F4F7), (0.5, 0xE1E6EE), (1, 0xC9D1DD)])
        for _ in 0..<42 {
            k.birch(x: rng.unit() * k.w, base: k.px(rng.range(270...320)), top: k.h, width: k.px(rng.range(5...9)), rng: &rng, alpha: 0.35)
        }
        k.fog(y: 300, height: 280, color: 0xF1F4F8, alpha: 0.9)
        for _ in 0..<24 {
            k.birch(x: rng.unit() * k.w, base: k.px(rng.range(205...245)), top: k.h, width: k.px(rng.range(10...18)), rng: &rng, alpha: 0.75)
        }
        k.fog(y: 220, height: 170, color: 0xF1F4F8, alpha: 0.55)
        let ground: [Wave] = [(6, 0.8, 0.4), (3, 2.6, 1.3)]
        k.hills(base: 215, waves: ground, top: 0xF7F9FC, bottom: 0xDDE3EC, rim: 0xFFFFFF)
        let fronts: [CGFloat] = [0.06, 0.2, 0.37, 0.58, 0.71, 0.86, 0.97]
        for fx in fronts {
            k.birch(x: k.fx(fx + rng.range(-0.02...0.02)), base: k.px(rng.range(40...120)), top: k.h,
                    width: k.px(rng.range(28...58)), rng: &rng)
        }
        // winterberry twigs for a touch of colour
        for (fx, fy) in [(0.82, 120.0), (0.9, 90.0), (0.12, 70.0)] as [(CGFloat, CGFloat)] {
            let root = CGPoint(x: k.fx(fx), y: 0)
            for _ in 0..<5 {
                let tip = CGPoint(x: root.x + k.px(rng.range(-120...120)), y: k.px(fy + rng.range(0...110)))
                let twig = CGMutablePath(); twig.move(to: root)
                twig.addQuadCurve(to: tip, control: CGPoint(x: (root.x + tip.x) / 2 + k.px(rng.range(-30...30)), y: tip.y * 0.5))
                k.ctx.stroke(twig, hex(0x4A3B33), width: k.px(2.2))
                for _ in 0..<6 {
                    let b = CGPoint(x: tip.x + k.px(rng.range(-12...12)), y: tip.y + k.px(rng.range(-14...10)))
                    k.ctx.circle(b, k.px(rng.range(3.5...5.5)), hex(0xC8102E))
                    k.ctx.circle(CGPoint(x: b.x - k.px(1.2), y: b.y + k.px(1.2)), k.px(1.1), hex(0xFFFFFF, 0.6))
                }
                k.ctx.fill(ellipsePath(CGPoint(x: tip.x, y: tip.y + k.px(9)), rx: k.px(12), ry: k.px(4)), hex(0xFFFFFF, 0.95))
            }
        }
        k.sparkles(&rng, count: starCount(k, 0.2), yMax: 210, color: 0xFFFFFF)
        k.snowfall(&rng, count: starCount(k, 0.4), size: 1...2.6, alpha: 0.55...0.95)
        k.snowfall(&rng, count: starCount(k, 0.03), size: 5...10, alpha: 0.4...0.7, blur: 2.5)
    }

    // MARK: 9 은하수 설원

    static func milkyWay(_ k: LandscapeKit, _ rng: inout SeededGenerator) {
        k.sky([(0, 0x22315F), (0.3, 0x111A3D), (1, 0x04060F)])
        func band(_ t: CGFloat) -> CGPoint {
            CGPoint(x: k.fx(-0.1 + 1.2 * t), y: k.px(330 + 560 * t + 70 * sin(t * .pi * 1.4)))
        }
        var r2 = rng
        k.blurLayer(scale: 0.25, radius: k.px(36), blend: .screen, alpha: 0.95) { c in
            let palette: [(UInt32, CGFloat)] = [(0x5E4BA6, 0.32), (0x3F6FC0, 0.28), (0xC36B9F, 0.22), (0xE9C99B, 0.3)]
            for _ in 0..<160 {
                let t = r2.unit()
                let p = band(t)
                let off = k.px(r2.range(-90...90))
                let (col, a) = palette[Int(r2.unit() * 4) % 4]
                let core = 1 - abs(t - 0.55) * 1.4
                c.circle(CGPoint(x: p.x + off * 0.4, y: p.y + off), k.px(r2.range(50...170)), hex(col, a * max(0.3, core)))
            }
        }
        k.blurLayer(scale: 0.25, radius: k.px(13), blend: .multiply, alpha: 0.38) { c in
            for _ in 0..<90 {
                let t = r2.unit()
                let p = band(t)
                let off = k.px(r2.range(-40...40))
                c.fill(ellipsePath(CGPoint(x: p.x + off * 0.3, y: p.y + off), rx: k.px(r2.range(30...90)), ry: k.px(r2.range(6...16))),
                       hex(0x1A1424, r2.range(0.4...0.9)))
            }
        }
        k.blurLayer(scale: 0.25, radius: k.px(18), blend: .screen, alpha: 0.6) { c in
            c.circle(band(0.55), k.px(160), hex(0xF3D9B5, 0.45))
            c.circle(band(0.5), k.px(110), hex(0xFFE8C8, 0.4))
        }
        rng = r2
        k.stars(&rng, count: starCount(k, 0.5), minY: 0.2, maxR: 1.1)
        for _ in 0..<starCount(k, 2.2) {
            let t = rng.unit()
            let p = band(t)
            let g = (rng.unit() + rng.unit() + rng.unit() - 1.5) / 1.5
            let q = CGPoint(x: p.x + k.px(g * 40), y: p.y + k.px(g * 110))
            k.ctx.circle(q, k.px(rng.range(0.25...0.8)), hex(0xFFFFFF, rng.range(0.3...0.9)))
        }
        k.fog(y: 205, height: 170, color: 0x3F5A9A, alpha: 0.45)
        let hill: [Wave] = [(45, 0.55, 0.6), (8, 2.0, 1.5)]
        k.hills(base: 170, waves: hill, top: 0x5E6E9E, bottom: 0x2F3A63, rim: 0x9FB0DA)
        let tx = k.fx(0.7)
        k.pine(x: tx, base: k.hillY(base: 170, waves: hill, x: tx) - k.px(6), height: k.px(320),
               color: hex(0x0A0F22), snow: hex(0x7E8FBC, 0.7))
        k.pine(x: k.fx(0.745), base: k.hillY(base: 170, waves: hill, x: k.fx(0.745)) - k.px(6), height: k.px(170),
               color: hex(0x0A0F22), snow: hex(0x7E8FBC, 0.7))
        k.sparkles(&rng, count: starCount(k, 0.2), yMax: 180, color: 0xCFD9F5)
    }

    // MARK: 10 분홍 노을 언덕

    static func pink(_ k: LandscapeKit, _ rng: inout SeededGenerator) {
        k.sky([(0, 0xFFE3C9), (0.25, 0xFFC9C2), (0.5, 0xF7A8C0), (0.8, 0xB48FD1), (1, 0x7D6BBF)])
        k.sun(CGPoint(x: k.fx(0.5), y: k.px(335)), r: k.px(62), core: 0xFFF4E3, halo: 0xFFC1B0, haloRadius: k.px(640))
        var r2 = rng
        k.blurLayer(scale: 0.25, radius: k.px(18), alpha: 0.75) { c in
            for _ in 0..<26 {
                let p = CGPoint(x: r2.unit() * k.w, y: k.px(r2.range(560...880)))
                c.fill(ellipsePath(p, rx: k.px(r2.range(80...220)), ry: k.px(r2.range(14...34))), hex(0xFFD6DE, r2.range(0.35...0.7)))
            }
        }
        rng = r2
        let far: [Wave] = [(28, 0.8, 0.4), (10, 2.3, 1.9)]
        k.hills(base: 330, waves: far, top: 0xE7A7C9, bottom: 0xE9B5CF, rim: 0xFFE8F1)
        k.forest(&rng, count: 60, base: 0...0, height: 25...55, color: 0xB07FAE, snow: 0xFFE6F0, snowAlpha: 0.9,
                 baseCurve: { x in k.hillY(base: 330, waves: far, x: x) - k.px(3) })
        let mid: [Wave] = [(24, 0.6, 2.2), (8, 1.9, 0.7)]
        k.hills(base: 245, waves: mid, top: 0xC99BD1, bottom: 0xD9AFD8, rim: 0xFFEFF7)
        k.forest(&rng, count: 40, base: 0...0, height: 45...100, color: 0x8E6A9E, snow: 0xFFF0F6,
                 baseCurve: { x in k.hillY(base: 245, waves: mid, x: x) - k.px(4) })
        let near: [Wave] = [(20, 0.5, 4.1), (6, 2.6, 1.1)]
        k.hills(base: 150, waves: near, top: 0xF5D9E6, bottom: 0xE2C3DA, rim: 0xFFFFFF)
        let fg: [Wave] = [(12, 0.45, 1.0), (4, 2.0, 2.6)]
        k.hills(base: 70, waves: fg, top: 0xFFF5F8, bottom: 0xEED9E6, rim: 0xFFFFFF)
        k.pine(x: k.fx(0.09), base: k.px(40), height: k.px(300), color: hex(0x6E4E7E), snow: hex(0xFFF2F7))
        k.pine(x: k.fx(0.9), base: k.px(30), height: k.px(360), color: hex(0x6E4E7E), snow: hex(0xFFF2F7))
        for _ in 0..<9 {
            let p = CGPoint(x: k.fx(rng.range(0.25...0.7)), y: k.px(rng.range(600...820)))
            let s = k.px(rng.range(6...12))
            let bird = CGMutablePath()
            bird.move(to: CGPoint(x: p.x - s, y: p.y + s * 0.4))
            bird.addQuadCurve(to: p, control: CGPoint(x: p.x - s * 0.5, y: p.y + s * 0.6))
            bird.addQuadCurve(to: CGPoint(x: p.x + s, y: p.y + s * 0.4), control: CGPoint(x: p.x + s * 0.5, y: p.y + s * 0.6))
            k.ctx.stroke(bird, hex(0x6B4E7A, 0.7), width: k.px(1.6))
        }
        k.sparkles(&rng, count: starCount(k, 0.25), yMax: 150, color: 0xFFF6FA)
    }
}
