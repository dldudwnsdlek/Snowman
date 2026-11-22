import CoreGraphics

/// Height map of snow lying on one ledge (window top, Dock top or the screen bottom).
/// Heights are stored per 2pt column, relative to the ledge's left end.
/// "Area" means snow volume in this 2D world: height (pt) × width (pt).
public struct SnowPile {
    public static let columnWidth: CGFloat = 2
    /// Largest height difference allowed between neighbouring columns (angle of repose).
    public static let maxStep: Float = 1.2
    /// Width over which capacity tapers down at each end, giving rounded snow caps.
    public static let taperWidth: CGFloat = 10

    private static let kernel: [Float] = [0.1, 0.2, 0.4, 0.2, 0.1]

    public private(set) var heights: [Float]
    public private(set) var width: CGFloat
    public var maxHeight: Float {
        didSet { clipToCapacity() }
    }

    public init(width: CGFloat, maxHeight: Float) {
        self.width = max(width, SnowPile.columnWidth)
        self.maxHeight = maxHeight
        self.heights = Array(repeating: 0, count: SnowPile.columns(for: width))
    }

    public var columnCount: Int { heights.count }

    public var totalArea: Float {
        heights.reduce(0, +) * Float(SnowPile.columnWidth)
    }

    public var isEmpty: Bool { heights.allSatisfy { $0 < 0.01 } }

    public func column(atLocalX x: CGFloat) -> Int? {
        guard x >= 0, x < width else { return nil }
        return min(columnCount - 1, Int(x / SnowPile.columnWidth))
    }

    public func centerX(ofColumn c: Int) -> CGFloat {
        min((CGFloat(c) + 0.5) * SnowPile.columnWidth, width)
    }

    /// Maximum snow height a column may hold: full `maxHeight` in the middle,
    /// smoothly lower toward both ends.
    public func capacity(column c: Int) -> Float {
        let center = centerX(ofColumn: c)
        let d = min(center, width - center)
        if d >= SnowPile.taperWidth { return maxHeight }
        let t = Float(max(0, d) / SnowPile.taperWidth)
        let smooth = t * t * (3 - 2 * t)
        return maxHeight * (0.35 + 0.65 * smooth)
    }

    /// Height at a local x, interpolated between column centres. 0 outside the ledge.
    public func height(atLocalX x: CGFloat) -> Float {
        guard x >= 0, x <= width, !heights.isEmpty else { return 0 }
        let pos = x / SnowPile.columnWidth - 0.5
        let i0 = Int(pos.rounded(.down))
        let frac = Float(pos - CGFloat(i0))
        let a = heights[max(0, min(columnCount - 1, i0))]
        let b = heights[max(0, min(columnCount - 1, i0 + 1))]
        return a + (b - a) * frac
    }

    /// Adds snow centred on `x`, spread over five columns. Returns the area that did not fit.
    @discardableResult
    public mutating func add(atLocalX x: CGFloat, area: Float) -> Float {
        guard area > 0, let c = column(atLocalX: max(0, min(x, width - 0.001))) else { return area }
        var weights: [(Int, Float)] = []
        for (k, w) in SnowPile.kernel.enumerated() {
            let col = c + k - 2
            if col >= 0 && col < columnCount { weights.append((col, w)) }
        }
        let total = weights.reduce(Float(0)) { $0 + $1.1 }
        var overflow: Float = 0
        for (col, w) in weights {
            let gain = (w / total) * area / Float(SnowPile.columnWidth)
            let cap = capacity(column: col)
            let room = max(0, cap - heights[col])
            let used = min(room, gain)
            heights[col] += used
            overflow += (gain - used) * Float(SnowPile.columnWidth)
        }
        return overflow
    }

    /// Lets snow settle: neighbouring columns may differ by at most `maxStep`, and snow
    /// beyond either end falls off. Returns the area spilled off each end.
    @discardableResult
    public mutating func relax(iterations: Int) -> (left: Float, right: Float) {
        guard columnCount > 0 else { return (0, 0) }
        let step = SnowPile.maxStep
        let colW = Float(SnowPile.columnWidth)
        var left: Float = 0
        var right: Float = 0
        let n = columnCount
        for iter in 0..<iterations {
            var moved = false
            // Ends: the air beyond the ledge acts as a neighbour of height 0.
            if heights[0] > step {
                let t = (heights[0] - step) / 2
                heights[0] -= t; left += t * colW; moved = true
            }
            if heights[n - 1] > step {
                let t = (heights[n - 1] - step) / 2
                heights[n - 1] -= t; right += t * colW; moved = true
            }
            let forward = iter % 2 == 0
            for j in 0..<(n - 1) {
                let i = forward ? j : (n - 2 - j)
                let d = heights[i] - heights[i + 1]
                if abs(d) > step {
                    let t = (abs(d) - step) / 2
                    if d > 0 { heights[i] -= t; heights[i + 1] += t } else { heights[i] += t; heights[i + 1] -= t }
                    moved = true
                }
            }
            // Anything above capacity slides off the nearer end.
            for c in 0..<n {
                let cap = capacity(column: c)
                if heights[c] > cap {
                    let excess = (heights[c] - cap) * colW
                    heights[c] = cap
                    if c < n / 2 { left += excess } else { right += excess }
                    moved = true
                }
            }
            if !moved { break }
        }
        return (left, right)
    }

    /// Removes up to `maxArea` of snow from the columns whose centres lie in `localRange`,
    /// proportionally to their heights. Returns the area removed.
    @discardableResult
    public mutating func take(localRange: ClosedRange<CGFloat>, maxArea: Float) -> Float {
        let cols = columns(in: localRange)
        guard !cols.isEmpty, maxArea > 0 else { return 0 }
        let available = cols.reduce(Float(0)) { $0 + heights[$1] } * Float(SnowPile.columnWidth)
        guard available > 0 else { return 0 }
        let taken = min(available, maxArea)
        let factor = 1 - taken / available
        for c in cols { heights[c] *= factor }
        return taken
    }

    @discardableResult
    public mutating func takeAll(localRange: ClosedRange<CGFloat>) -> Float {
        take(localRange: localRange, maxArea: .greatestFiniteMagnitude)
    }

    /// Changes the ledge width, spreading the same amount of snow over the new width.
    /// Returns the area that no longer fits (when the ledge got narrower).
    @discardableResult
    public mutating func resample(toWidth newWidth: CGFloat) -> Float {
        let newWidth = max(newWidth, SnowPile.columnWidth)
        guard newWidth != width else { return 0 }
        let oldArea = totalArea
        let newCount = SnowPile.columns(for: newWidth)
        var out = [Float](repeating: 0, count: newCount)
        let ratio = width / newWidth
        for i in 0..<newCount {
            let x = (CGFloat(i) + 0.5) * SnowPile.columnWidth * ratio
            out[i] = height(atLocalX: x)
        }
        heights = out
        width = newWidth
        let newArea = totalArea
        if newArea > 0 {
            let scale = oldArea / newArea
            for i in 0..<heights.count { heights[i] *= scale }
        }
        return clipToCapacity()
    }

    public mutating func clear() {
        for i in 0..<heights.count { heights[i] = 0 }
    }

    /// Multiplies every height by `factor` (used for melting and shaking snow off).
    public mutating func scale(by factor: Float) {
        let f = max(0, factor)
        for i in 0..<heights.count { heights[i] *= f }
    }

    // MARK: - Private

    private static func columns(for width: CGFloat) -> Int {
        max(1, Int((width / columnWidth).rounded(.up)))
    }

    private func columns(in range: ClosedRange<CGFloat>) -> [Int] {
        (0..<columnCount).filter { range.contains(centerX(ofColumn: $0)) }
    }

    @discardableResult
    private mutating func clipToCapacity() -> Float {
        var overflow: Float = 0
        for c in 0..<heights.count {
            let cap = capacity(column: c)
            if heights[c] > cap {
                overflow += (heights[c] - cap) * Float(SnowPile.columnWidth)
                heights[c] = cap
            }
        }
        return overflow
    }
}
