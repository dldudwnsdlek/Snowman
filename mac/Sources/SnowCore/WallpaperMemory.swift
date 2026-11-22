import Foundation

/// The wallpaper a screen had before Snowman changed it.
public struct SavedWallpaper: Codable, Equatable, Sendable {
    public let url: String
    public let scaling: Int?
    public let allowClipping: Bool?

    public init(url: String, scaling: Int?, allowClipping: Bool?) {
        self.url = url
        self.scaling = scaling
        self.allowClipping = allowClipping
    }
}

/// Remembers each screen's original wallpaper exactly once, so "원래 배경화면으로" can restore it
/// even after several winter wallpapers were tried or the app was relaunched.
public struct WallpaperMemory: Codable, Equatable, Sendable {
    public private(set) var originals: [String: SavedWallpaper] = [:]

    public init() {}

    public var isEmpty: Bool { originals.isEmpty }

    public mutating func rememberIfNeeded(displayKey: String, _ saved: SavedWallpaper) {
        if originals[displayKey] == nil { originals[displayKey] = saved }
    }

    public mutating func takeAll() -> [String: SavedWallpaper] {
        defer { originals.removeAll() }
        return originals
    }
}
