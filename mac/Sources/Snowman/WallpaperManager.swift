import AppKit
import ImageIO
import SnowCore
import UniformTypeIdentifiers
import WinterArt

/// Renders, caches, applies and restores the winter wallpapers.
final class WallpaperManager {
    static let shared = WallpaperManager()

    struct Entry {
        let title: String
        let tag: Int
    }

    /// Bump when the wallpaper art changes so cached files are re-rendered.
    private static let artVersion = 3
    private let defaults = UserDefaults.standard
    private let memoryKey = "wallpaperMemory"
    private let renderQueue = DispatchQueue(label: "snowman.wallpapers", qos: .userInitiated)

    private var memory: WallpaperMemory {
        get {
            guard let data = defaults.data(forKey: memoryKey),
                  let m = try? JSONDecoder().decode(WallpaperMemory.self, from: data) else { return WallpaperMemory() }
            return m
        }
        set { defaults.set(try? JSONEncoder().encode(newValue), forKey: memoryKey) }
    }

    var hasSavedOriginal: Bool { !memory.isEmpty }

    var folder: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Snowman/Wallpapers", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    func menuEntries() -> [Entry] {
        WinterWallpaper.allCases.map { Entry(title: $0.title, tag: $0.rawValue) }
    }

    /// Small rounded previews for the menu, made off the main thread.
    func makeThumbnails(_ done: @escaping ([Int: NSImage]) -> Void) {
        renderQueue.async {
            var result: [Int: NSImage] = [:]
            for w in WinterWallpaper.allCases {
                let img = w.render(pixelSize: CGSize(width: 128, height: 80))
                let rounded = Canvas.image(size: CGSize(width: 64, height: 40), scale: 2) { ctx in
                    let r = CGRect(x: 0, y: 0, width: 64, height: 40)
                    ctx.clipped(to: CGPath(roundedRect: r, cornerWidth: 6, cornerHeight: 6, transform: nil)) {
                        ctx.draw(img, in: r)
                    }
                }
                result[w.rawValue] = NSImage(cgImage: rounded, size: NSSize(width: 64, height: 40))
            }
            DispatchQueue.main.async { done(result) }
        }
    }

    /// Renders every wallpaper for the current screens in the background so choosing one is instant.
    func prerenderAll() {
        var sizes: [CGSize] = []
        for size in NSScreen.screens.map({ pixelSize(of: $0) }) where !sizes.contains(size) { sizes.append(size) }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 6) { [self] in
            for w in WinterWallpaper.allCases {
                for size in sizes { _ = ensureFile(w, size: size) }
            }
        }
    }

    func apply(tag: Int) {
        guard let w = WinterWallpaper(rawValue: tag) else { return }
        var mem = memory
        let ownFolder = folder.path
        for screen in NSScreen.screens {
            guard let url = NSWorkspace.shared.desktopImageURL(for: screen), !url.path.hasPrefix(ownFolder) else { continue }
            let opts = NSWorkspace.shared.desktopImageOptions(for: screen) ?? [:]
            mem.rememberIfNeeded(displayKey: key(for: screen), SavedWallpaper(
                url: url.absoluteString,
                scaling: (opts[.imageScaling] as? NSNumber)?.intValue,
                allowClipping: (opts[.allowClipping] as? NSNumber)?.boolValue))
        }
        memory = mem
        Settings.shared.currentWallpaper = tag
        let jobs = NSScreen.screens.map { (key: key(for: $0), size: pixelSize(of: $0)) }
        renderQueue.async { [self] in
            let files = jobs.map { (key: $0.key, url: ensureFile(w, size: $0.size)) }
            DispatchQueue.main.async {
                for file in files {
                    guard let url = file.url, let screen = NSScreen.screens.first(where: { self.key(for: $0) == file.key }) else { continue }
                    try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: [
                        .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
                        .allowClipping: true,
                    ])
                }
            }
        }
    }

    func restoreOriginal() {
        var mem = memory
        let originals = mem.takeAll()
        memory = mem
        guard !originals.isEmpty else { return }
        for screen in NSScreen.screens {
            guard let saved = originals[key(for: screen)] ?? originals.values.first, let url = URL(string: saved.url) else { continue }
            var opts: [NSWorkspace.DesktopImageOptionKey: Any] = [:]
            if let s = saved.scaling { opts[.imageScaling] = s }
            if let c = saved.allowClipping { opts[.allowClipping] = c }
            try? NSWorkspace.shared.setDesktopImageURL(url, for: screen, options: opts)
        }
        Settings.shared.currentWallpaper = nil
    }

    // MARK: - Files

    private func key(for screen: NSScreen) -> String {
        let n = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
        return n.map { "\($0.uint32Value)" } ?? screen.localizedName
    }

    private func pixelSize(of screen: NSScreen) -> CGSize {
        CGSize(width: (screen.frame.width * screen.backingScaleFactor).rounded(),
               height: (screen.frame.height * screen.backingScaleFactor).rounded())
    }

    private func fileURL(_ w: WinterWallpaper, size: CGSize) -> URL {
        folder.appendingPathComponent("\(w.fileStem)-v\(WallpaperManager.artVersion)-\(Int(size.width))x\(Int(size.height)).jpg")
    }

    /// Returns the cached file, rendering it first if needed.
    private func ensureFile(_ w: WinterWallpaper, size: CGSize) -> URL? {
        let url = fileURL(w, size: size)
        if FileManager.default.fileExists(atPath: url.path) { return url }
        let image = w.render(pixelSize: size)
        let tmp = url.appendingPathExtension("part")
        guard let dest = CGImageDestinationCreateWithURL(tmp as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
        CGImageDestinationAddImage(dest, image, [kCGImageDestinationLossyCompressionQuality: 0.93] as CFDictionary)
        guard CGImageDestinationFinalize(dest) else { return nil }
        try? FileManager.default.removeItem(at: url)
        try? FileManager.default.moveItem(at: tmp, to: url)
        return url
    }
}
