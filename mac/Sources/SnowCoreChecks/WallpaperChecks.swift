import CoreGraphics
import Foundation
import SnowCore
import WinterArt

private func thumb(_ img: CGImage, w: Int = 16, h: Int = 10) -> [UInt8] {
    var data = [UInt8](repeating: 0, count: w * h * 4)
    data.withUnsafeMutableBytes { buf in
        let ctx = CGContext(data: buf.baseAddress, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4,
                            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.interpolationQuality = .medium
        ctx.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    }
    return data
}

private func meanAbsDiff(_ a: [UInt8], _ b: [UInt8]) -> Double {
    var sum = 0
    for i in 0..<min(a.count, b.count) where i % 4 != 3 { sum += abs(Int(a[i]) - Int(b[i])) }
    return Double(sum) / Double(a.count * 3 / 4)
}

func runWallpaperChecks() {
    do { // originalWallpaperSavedOnce
        var m = WallpaperMemory()
        m.rememberIfNeeded(displayKey: "1", SavedWallpaper(url: "file:///A.heic", scaling: 3, allowClipping: true))
        m.rememberIfNeeded(displayKey: "1", SavedWallpaper(url: "file:///B.jpg", scaling: 1, allowClipping: false))
        check("originalWallpaperSavedOnce.kept", m.originals["1"]?.url == "file:///A.heic")
        let all = m.takeAll()
        check("originalWallpaperSavedOnce.taken", all.count == 1 && m.originals.isEmpty)
    }
    do { // wallpaperMemoryCodable — survives relaunch via UserDefaults data
        var m = WallpaperMemory()
        m.rememberIfNeeded(displayKey: "2", SavedWallpaper(url: "u", scaling: nil, allowClipping: nil))
        let back = try? JSONDecoder().decode(WallpaperMemory.self, from: JSONEncoder().encode(m))
        check("wallpaperMemoryCodable", back?.originals["2"]?.url == "u")
    }
    do { // catalog
        check("wallpaperCount", WinterWallpaper.allCases.count == 10)
        check("wallpaperTitles", WinterWallpaper.allCases.map(\.title) == [
            "오로라의 밤", "달빛 오두막", "황금빛 설원 숲", "얼어붙은 호수", "눈 내리는 마을",
            "크리스마스 트리", "푸른 새벽 설산", "자작나무 숲", "은하수 설원", "분홍 노을 언덕",
        ])
    }
    do { // wallpapersRenderDistinct
        let thumbs = WinterWallpaper.allCases.map { thumb($0.render(pixelSize: CGSize(width: 320, height: 200))) }
        var minDiff = Double.infinity
        for i in 0..<thumbs.count { for j in (i + 1)..<thumbs.count { minDiff = min(minDiff, meanAbsDiff(thumbs[i], thumbs[j])) } }
        check("wallpapersRenderDistinct", minDiff > 8, "min pairwise diff \(minDiff)")
    }
    do { // wallpaperDeterministic + size
        let a = thumb(WinterWallpaper.auroraNight.render(pixelSize: CGSize(width: 320, height: 200)), w: 64, h: 40)
        let b = thumb(WinterWallpaper.auroraNight.render(pixelSize: CGSize(width: 320, height: 200)), w: 64, h: 40)
        check("wallpaperDeterministic", a == b)
        let img = WinterWallpaper.moonlitCabin.render(pixelSize: CGSize(width: 302, height: 196))
        check("wallpaperSize", img.width == 302 && img.height == 196)
    }
}
