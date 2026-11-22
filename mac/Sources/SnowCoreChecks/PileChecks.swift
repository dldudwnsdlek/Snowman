import CoreGraphics
import SnowCore

private func filledFlat(width: CGFloat, maxHeight: Float, areaPerStep: Float) -> SnowPile {
    var p = SnowPile(width: width, maxHeight: maxHeight)
    for x in stride(from: CGFloat(1), to: width, by: SnowPile.columnWidth) {
        p.add(atLocalX: x, area: areaPerStep)
    }
    return p
}

func runPileChecks() {
    do { // addIncreasesArea
        var p = SnowPile(width: 100, maxHeight: 14)
        let over = p.add(atLocalX: 50, area: 10)
        checkClose("addIncreasesArea.area", Double(p.totalArea), 10, tol: 0.01)
        checkClose("addIncreasesArea.overflow", Double(over), 0, tol: 0.0001)
    }
    do { // capacityTapersAtEnds
        let p = SnowPile(width: 100, maxHeight: 14)
        check("capacityTapersAtEnds.end", p.capacity(column: 0) < 0.5 * 14, "cap0 \(p.capacity(column: 0))")
        check("capacityTapersAtEnds.middle", p.capacity(column: p.columnCount / 2) == 14)
    }
    do { // overflowReturnedWhenFull
        var p = SnowPile(width: 100, maxHeight: 14)
        let over = p.add(atLocalX: 50, area: 10_000)
        check("overflowReturnedWhenFull.overflow", over > 0)
        let capped = (0..<p.columnCount).allSatisfy { p.heights[$0] <= p.capacity(column: $0) + 0.0001 }
        check("overflowReturnedWhenFull.capped", capped)
    }
    do { // relaxLimitsSlope
        var p = SnowPile(width: 100, maxHeight: 14)
        for _ in 0..<20 { p.add(atLocalX: 50, area: 6) }
        _ = p.relax(iterations: 50)
        let maxStep = zip(p.heights, p.heights.dropFirst()).map { abs($0 - $1) }.max() ?? 0
        check("relaxLimitsSlope", maxStep <= 1.2 + 0.01, "maxStep \(maxStep)")
    }
    do { // relaxSpillsAtEnds
        var p = SnowPile(width: 100, maxHeight: 14)
        p.add(atLocalX: 1, area: 8)
        let spill = p.relax(iterations: 50)
        check("relaxSpillsAtEnds", spill.left > 0, "left \(spill.left)")
    }
    do { // takeRemovesUpToMax
        var p = filledFlat(width: 100, maxHeight: 14, areaPerStep: 12)
        let before = p.totalArea
        let got = p.take(localRange: 10...30, maxArea: 20)
        checkClose("takeRemovesUpToMax.returned", Double(got), 20, tol: 0.01)
        checkClose("takeRemovesUpToMax.areaDrop", Double(before - p.totalArea), 20, tol: 0.01)
    }
    do { // resamplePreservesVolume
        var p = filledFlat(width: 100, maxHeight: 14, areaPerStep: 12)
        let before = Double(p.totalArea)
        p.resample(toWidth: 160)
        check("resamplePreservesVolume.width", p.width == 160)
        checkClose("resamplePreservesVolume.area", Double(p.totalArea), before, tol: before * 0.05)
    }
}
