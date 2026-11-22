// swift-tools-version:6.0
import PackageDescription

let package = Package(
    name: "Snowman",
    platforms: [.macOS(.v14)],
    targets: [
        .target(name: "SnowCore"),
        .target(name: "WinterArt", dependencies: ["SnowCore"]),
        .executableTarget(name: "Snowman", dependencies: ["SnowCore", "WinterArt"]),
        .executableTarget(name: "SnowCoreChecks", dependencies: ["SnowCore", "WinterArt"]),
        .executableTarget(name: "ArtPreview", dependencies: ["SnowCore", "WinterArt"]),
    ],
    swiftLanguageModes: [.v5]
)
