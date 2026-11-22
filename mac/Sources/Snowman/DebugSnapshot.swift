import AppKit
import ImageIO
import SnowCore
import SpriteKit
import UniformTypeIdentifiers
import WinterArt

/// Developer aid: when launched with SNOWMAN_DEBUG_DIR set, `kill -USR1 <pid>` writes each overlay
/// (drawn over outlines of the tracked windows and Dock) plus a text report into that folder.
enum DebugSnapshot {
    private static var source: DispatchSourceSignal?
    private static var commandSource: DispatchSourceSignal?

    static func install(controller: OverlayController) {
        guard let dir = ProcessInfo.processInfo.environment["SNOWMAN_DEBUG_DIR"] else { return }
        signal(SIGUSR1, SIG_IGN)
        signal(SIGUSR2, SIG_IGN)
        let src = DispatchSource.makeSignalSource(signal: SIGUSR1, queue: .main)
        src.setEventHandler { [weak controller] in
            guard let controller else { return }
            write(controller, dir: dir)
        }
        src.resume()
        source = src
        let cmd = DispatchSource.makeSignalSource(signal: SIGUSR2, queue: .main)
        cmd.setEventHandler { [weak controller] in
            guard let controller else { return }
            let path = "\(dir)/cmd.txt"
            guard let text = try? String(contentsOfFile: path, encoding: .utf8) else { return }
            try? FileManager.default.removeItem(atPath: path)
            run(text.split(separator: "\n").map(String.init), controller: controller, dir: dir)
        }
        cmd.resume()
        commandSource = cmd
    }

    /// Runs debug commands one after another; `wait <s>` pauses between them.
    private static func run(_ lines: [String], controller: OverlayController, dir: String) {
        var rest = lines
        while !rest.isEmpty {
            let parts = rest.removeFirst().split(separator: " ").map(String.init)
            guard let op = parts.first else { continue }
            let arg = parts.count > 1 ? parts[1] : ""
            let num = { (i: Int) -> CGFloat in parts.count > i ? CGFloat(Double(parts[i]) ?? 0) : 0 }
            guard let scene = controller.overlays.first?.scene else { return }
            switch op {
            case "wait":
                let remaining = rest
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(num(1))) { run(remaining, controller: controller, dir: dir) }
                return
            case "snap": write(controller, dir: dir)
            case "spawn": controller.spawnSnowman(style: SnowmanStyle.allCases.first { "\($0)" == arg })
            case "plow": controller.callPlow()
            case "clear": controller.clearSnow()
            case "clearmen": controller.clearSnowmen()
            case "amount": if let a = SnowAmount(rawValue: arg) { controller.setAmount(a) }
            case "pause": controller.setSnowing(arg != "on")
            case "windows": controller.setAccumulateOnWindows(arg == "on")
            case "fill": scene.debugFill(height: num(1))
            case "roll": scene.debugRoll(from: num(1), to: num(2), lift: parts.count > 4 ? CGPoint(x: num(3), y: num(4)) : nil)
            case "throw": scene.debugThrow(vx: num(1), vy: num(2))
            case "wallpaper": WallpaperManager.shared.apply(tag: Int(num(1)))
            case "restore": WallpaperManager.shared.restoreOriginal()
            case "help":
                HelpWindowController.shared.show()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                    guard let w = HelpWindowController.shared.currentWindow, let v = w.contentView else { return }
                    w.appearance = NSAppearance(named: .aqua)
                    v.layoutSubtreeIfNeeded()
                    guard let rep = v.bitmapImageRepForCachingDisplay(in: v.bounds) else { return }
                    v.cacheDisplay(in: v.bounds, to: rep)
                    try? rep.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: "\(dir)/help.png"))
                    w.close()
                }
            default: break
            }
        }
    }

    private static func write(_ controller: OverlayController, dir: String) {
        var report = "time \(Date())\naxTrusted \(controller.axTrusted)\n"
        let snap = controller.lastSnapshot
        report += "dockFrameCG \(String(describing: snap?.dockFrameCG))\n"
        for w in snap?.windows ?? [] { report += "window #\(w.id) \(w.ownerName) \(w.boundsCG)\n" }
        for (i, o) in controller.overlays.enumerated() {
            let scene = o.scene
            report += "\n[overlay \(i)] size \(scene.size) menuBar \(scene.geometry.menuBarHeight) particles \(scene.particles.count) wantsMouse \(scene.wantsMouse)\n"
            for l in scene.frameLedges {
                let pile = scene.store.piles[l.kind]
                let hidden = l.vis.hidden.filter { $0 }.count
                report += "  ledge \(l.kind) x \(Int(l.spec.x0))..\(Int(l.spec.x1)) y \(Int(l.spec.y)) max \(l.spec.maxHeight) area \(Int(pile?.totalArea ?? 0)) peak \(String(format: "%.1f", pile?.heights.max() ?? 0)) hiddenCols \(hidden)/\(l.columns)\n"
            }
            report += scene.debugObjectsReport()
            guard let tex = o.view.texture(from: scene) else { continue }
            let overlay = tex.cgImage()
            let size = scene.size
            let image = Canvas.image(size: size, scale: 1) { ctx in
                ctx.setFillColor(hex(0x2B3445)); ctx.fill(CGRect(origin: .zero, size: size))
                for w in (snap?.windows ?? []).reversed() {
                    let r = scene.geometry.toScene(cgRect: w.boundsCG)
                    ctx.setFillColor(hex(0x5A6478, 0.85)); ctx.fill(r)
                    ctx.setFillColor(hex(0x737D92)); ctx.fill(CGRect(x: r.minX, y: r.maxY - 28, width: r.width, height: 28))
                    ctx.setStrokeColor(hex(0xAAB4C8)); ctx.setLineWidth(1); ctx.stroke(r)
                }
                if let d = snap?.dockFrameCG {
                    let r = scene.geometry.toScene(cgRect: d)
                    ctx.setFillColor(hex(0x8FA3C7, 0.6)); ctx.fill(r)
                    ctx.setStrokeColor(hex(0xD8E2F5)); ctx.stroke(r)
                }
                ctx.draw(overlay, in: CGRect(origin: .zero, size: size))
            }
            save(image, to: "\(dir)/overlay-\(i).png")
        }
        try? report.write(toFile: "\(dir)/report.txt", atomically: true, encoding: .utf8)
    }

    private static func save(_ image: CGImage, to path: String) {
        let url = URL(fileURLWithPath: path)
        guard let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else { return }
        CGImageDestinationAddImage(dest, image, nil)
        CGImageDestinationFinalize(dest)
    }
}
