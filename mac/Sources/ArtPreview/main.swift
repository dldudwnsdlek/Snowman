import CoreGraphics
import Foundation
import ImageIO
import SnowCore
import UniformTypeIdentifiers
import WinterArt

func writePNG(_ image: CGImage, to path: String) {
    let url = URL(fileURLWithPath: path)
    try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("cannot write \(path)"); return
    }
    CGImageDestinationAddImage(dest, image, nil)
    CGImageDestinationFinalize(dest)
    print("wrote \(path)")
}

func spriteSheet() -> CGImage {
    let scale: CGFloat = 2
    let size = CGSize(width: 1300, height: 760)
    return Canvas.image(size: size, scale: scale) { ctx in
        ctx.fillLinear([hex(0x0B1B45), hex(0x1F3F7A)], from: CGPoint(x: 0, y: size.height), to: .zero)
        // ground strip
        ctx.setFillColor(hex(0xEEF3FB)); ctx.fill(CGRect(x: 0, y: 0, width: size.width, height: 300))
        var x: CGFloat = 40
        for style in SnowmanStyle.allCases {
            let img = SnowmanArt.composite(style: style, height: 220, scale: scale)
            let w = CGFloat(img.width) / scale
            ctx.draw(img, in: CGRect(x: x, y: 300 - 14, width: w, height: 220))
            x += w + 30
        }
        // individual parts of the santa snowman, magnified
        var px: CGFloat = 40
        for part in SnowmanArt.parts(for: .elf) {
            guard let p = SnowmanArt.part(part, style: .elf, scale: scale * 1.6) else { continue }
            let w = p.size.width * 1.6, h = p.size.height * 1.6
            ctx.setStrokeColor(hex(0xFF00FF, 0.25)); ctx.stroke(CGRect(x: px, y: 560, width: w, height: h))
            ctx.draw(p.image, in: CGRect(x: px, y: 560, width: w, height: h))
            px += w + 12
        }
        // plow
        let plowOrigin = CGPoint(x: 40, y: 40)
        ctx.draw(SpriteArt.plow(scale: scale), in: CGRect(origin: plowOrigin, size: SpriteArt.plowSize))
        for c in SpriteArt.plowWheelCenters {
            ctx.draw(SpriteArt.plowWheel(scale: scale), in: CGRect(x: plowOrigin.x + c.x - 12, y: plowOrigin.y + c.y - 12, width: 24, height: 24))
        }
        let b = SpriteArt.plowBeaconPosition
        ctx.draw(SpriteArt.glow(radius: 14, color: 0xFFB703, scale: scale),
                 in: CGRect(x: plowOrigin.x + b.x - 14, y: plowOrigin.y + b.y - 14 + 4, width: 28, height: 28))
        ctx.draw(SpriteArt.plowBeacon(scale: scale), in: CGRect(x: plowOrigin.x + b.x - 6, y: plowOrigin.y + b.y, width: 12, height: 10))
        // misc sprites on dark background
        ctx.setFillColor(hex(0x1F3F7A)); ctx.fill(CGRect(x: 200, y: 20, width: 560, height: 110))
        ctx.draw(SpriteArt.mitten(size: 56, scale: scale), in: CGRect(x: 210, y: 40, width: 56, height: 56))
        ctx.draw(SpriteArt.snowball(radius: 30, scale: scale), in: CGRect(x: 280, y: 36, width: 64, height: 64))
        ctx.draw(SpriteArt.flake(diameter: 24, scale: scale), in: CGRect(x: 360, y: 50, width: 24, height: 24))
        ctx.draw(SpriteArt.clump(diameter: 30, scale: scale), in: CGRect(x: 400, y: 46, width: 30, height: 30))
        ctx.draw(SpriteArt.puff(scale: scale), in: CGRect(x: 450, y: 36, width: 60, height: 60))
        ctx.draw(SpriteArt.sparkle(scale: scale), in: CGRect(x: 530, y: 46, width: 36, height: 36))
        ctx.draw(IconArt.appIcon(pixels: 256), in: CGRect(x: 600, y: 22, width: 106, height: 106))
    }
}

func writeIconset(_ dir: String) {
    let sizes: [(String, Int)] = [
        ("icon_16x16", 16), ("icon_16x16@2x", 32), ("icon_32x32", 32), ("icon_32x32@2x", 64),
        ("icon_128x128", 128), ("icon_128x128@2x", 256), ("icon_256x256", 256), ("icon_256x256@2x", 512),
        ("icon_512x512", 512), ("icon_512x512@2x", 1024),
    ]
    for (name, px) in sizes { writePNG(IconArt.appIcon(pixels: px), to: "\(dir)/\(name).png") }
}

let args = CommandLine.arguments
func value(after flag: String) -> String? {
    guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
    return args[i + 1]
}

func writeWallpapers(_ dir: String) {
    let size = CGSize(width: 1512, height: 982)
    var images: [CGImage] = []
    for w in WinterWallpaper.allCases {
        let start = Date()
        let img = w.render(pixelSize: size)
        print("\(w.title) \(String(format: "%.2f", Date().timeIntervalSince(start)))s")
        writePNG(img, to: "\(dir)/\(w.fileStem).png")
        images.append(img)
    }
    // contact sheet, 2 columns
    let cw: CGFloat = 756, ch: CGFloat = 491
    let sheet = Canvas.image(size: CGSize(width: cw * 2, height: ch * 5), scale: 1) { ctx in
        for (i, img) in images.enumerated() {
            let col = CGFloat(i % 2), row = CGFloat(4 - i / 2)
            ctx.draw(img, in: CGRect(x: col * cw, y: row * ch, width: cw, height: ch))
        }
    }
    writePNG(sheet, to: "\(dir)/sheet.png")
}

var didSomething = false
if let dir = value(after: "--wallpapers") { writeWallpapers(dir); didSomething = true }
if let path = value(after: "--sprites") { writePNG(spriteSheet(), to: path); didSomething = true }
if let dir = value(after: "--iconset") { writeIconset(dir); didSomething = true }
if !didSomething {
    print("usage: ArtPreview [--sprites out.png] [--iconset dir.iconset] [--wallpapers dir]")
}
