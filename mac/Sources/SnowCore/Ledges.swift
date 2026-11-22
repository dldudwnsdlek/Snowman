import CoreGraphics

/// What a ledge belongs to.
public enum LedgeKind: Hashable, Sendable {
    case window(Int)   // CGWindowNumber
    case dock
    case ground
}

/// One entry from CGWindowListCopyWindowInfo, already decoded.
public struct RawWindow: Equatable, Sendable {
    public let id: Int
    public let layer: Int
    public let alpha: Double
    public let boundsCG: CGRect     // global, top-left origin
    public let ownerPID: Int32
    public let ownerName: String

    public init(id: Int, layer: Int, alpha: Double, boundsCG: CGRect, ownerPID: Int32, ownerName: String) {
        self.id = id
        self.layer = layer
        self.alpha = alpha
        self.boundsCG = boundsCG
        self.ownerPID = ownerPID
        self.ownerName = ownerName
    }
}

/// Keeps ordinary app windows that snow can sit on, in their original front-to-back order.
public func filterSnowWindows(_ raw: [RawWindow], ownPID: Int32) -> [RawWindow] {
    let excludedOwners: Set<String> = ["Window Server", "Dock"]
    return raw.filter { w in
        w.layer == 0
            && w.alpha > 0.05
            && w.boundsCG.width >= 80
            && w.boundsCG.height >= 40
            && w.ownerPID != ownPID
            && !excludedOwners.contains(w.ownerName)
    }
}

/// A surface snow can land on, in scene coordinates (origin bottom-left, y up).
public struct LedgeSpec: Equatable, Sendable {
    public let kind: LedgeKind
    public let x0: CGFloat
    public let x1: CGFloat
    /// The surface line (top edge of the window or Dock, 0 for the ground).
    public let y: CGFloat
    public let maxHeight: Float
    public let landProbability: Float
    /// Things drawn in front of this ledge (front windows, the Dock).
    public let occluders: [CGRect]

    public init(kind: LedgeKind, x0: CGFloat, x1: CGFloat, y: CGFloat, maxHeight: Float, landProbability: Float, occluders: [CGRect]) {
        self.kind = kind
        self.x0 = x0
        self.x1 = x1
        self.y = y
        self.maxHeight = maxHeight
        self.landProbability = landProbability
        self.occluders = occluders
    }

    public var width: CGFloat { x1 - x0 }
}

public enum LedgeTuning {
    public static let windowMaxHeight: Float = 14
    public static let dockMaxHeight: Float = 16
    public static let groundMaxHeight: Float = 22
    /// How far snow may rise into the menu bar (it is drawn behind it).
    public static let menuBarAllowance: CGFloat = 10
    public static let windowLandProbability: Float = 0.4
    public static let dockLandProbability: Float = 0.85
    public static let groundLandProbability: Float = 1.0
    public static let minimumLedgeWidth: CGFloat = 40
}

/// Builds every ledge for one screen. `windowFrames` are scene-space frames, front to back.
public func buildLedgeSpecs(windowFrames: [(id: Int, frame: CGRect)],
                            dockFrame: CGRect?,
                            sceneSize: CGSize,
                            menuBarHeight: CGFloat,
                            includeWindows: Bool) -> [LedgeSpec] {
    var result: [LedgeSpec] = []
    let snowCeiling = sceneSize.height - menuBarHeight + LedgeTuning.menuBarAllowance
    let dockOccluder: [CGRect] = dockFrame.map { [$0] } ?? []

    if includeWindows {
        for (index, entry) in windowFrames.enumerated() {
            let f = entry.frame
            let x0 = max(f.minX, 0)
            let x1 = min(f.maxX, sceneSize.width)
            let y = f.maxY
            guard x1 - x0 >= LedgeTuning.minimumLedgeWidth,
                  y > 4, y < sceneSize.height - 0.5 else { continue }
            let maxHeight = min(LedgeTuning.windowMaxHeight, Float(snowCeiling - y))
            guard maxHeight > 1 else { continue }
            let front = windowFrames[..<index].map(\.frame)
            result.append(LedgeSpec(kind: .window(entry.id), x0: x0, x1: x1, y: y,
                                    maxHeight: maxHeight,
                                    landProbability: LedgeTuning.windowLandProbability,
                                    occluders: Array(front) + dockOccluder))
        }
    }

    if let dock = dockFrame {
        let x0 = max(dock.minX, 0)
        let x1 = min(dock.maxX, sceneSize.width)
        if x1 - x0 >= LedgeTuning.minimumLedgeWidth {
            result.append(LedgeSpec(kind: .dock, x0: x0, x1: x1, y: dock.maxY,
                                    maxHeight: LedgeTuning.dockMaxHeight,
                                    landProbability: LedgeTuning.dockLandProbability,
                                    occluders: []))
        }
    }

    result.append(LedgeSpec(kind: .ground, x0: 0, x1: sceneSize.width, y: 0,
                            maxHeight: LedgeTuning.groundMaxHeight,
                            landProbability: LedgeTuning.groundLandProbability,
                            occluders: dockOccluder))
    return result
}

/// Per-column visibility of a ledge's snow.
public struct Visibility: Equatable, Sendable {
    /// The ledge itself is covered by something in front.
    public var hidden: [Bool]
    /// Highest visible snow height (pt) before something in front covers it.
    public var ceiling: [Float]

    public init(hidden: [Bool], ceiling: [Float]) {
        self.hidden = hidden
        self.ceiling = ceiling
    }

    public func visibleHeight(column c: Int, height: Float) -> Float {
        guard c >= 0, c < hidden.count, !hidden[c] else { return 0 }
        return min(height, ceiling[c])
    }
}

public func visibility(for spec: LedgeSpec, columnCount: Int) -> Visibility {
    var hidden = [Bool](repeating: false, count: columnCount)
    var ceiling = [Float](repeating: .infinity, count: columnCount)
    guard !spec.occluders.isEmpty else { return Visibility(hidden: hidden, ceiling: ceiling) }
    for c in 0..<columnCount {
        let x = spec.x0 + (CGFloat(c) + 0.5) * SnowPile.columnWidth
        for o in spec.occluders where x >= o.minX && x < o.maxX {
            if spec.y >= o.minY && spec.y <= o.maxY {
                hidden[c] = true
                break
            } else if o.minY > spec.y {
                ceiling[c] = min(ceiling[c], Float(o.minY - spec.y))
            }
        }
    }
    return Visibility(hidden: hidden, ceiling: ceiling)
}
