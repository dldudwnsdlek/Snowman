import CoreGraphics
import SnowCore

private let scene = CGSize(width: 1512, height: 982)

private func specs(_ windows: [(id: Int, frame: CGRect)], dock: CGRect? = nil, includeWindows: Bool = true) -> [LedgeSpec] {
    buildLedgeSpecs(windowFrames: windows, dockFrame: dock, sceneSize: scene, menuBarHeight: 33, includeWindows: includeWindows)
}

private func columns(_ s: LedgeSpec) -> Int {
    SnowPile(width: s.x1 - s.x0, maxHeight: s.maxHeight).columnCount
}

func runLedgeChecks() {
    do { // filterKeepsOnlyNormalWindows
        let raw = [
            RawWindow(id: 1, layer: 0, alpha: 1, boundsCG: CGRect(x: 0, y: 33, width: 800, height: 600), ownerPID: 100, ownerName: "Claude"),
            RawWindow(id: 2, layer: 25, alpha: 1, boundsCG: CGRect(x: 0, y: 0, width: 40, height: 33), ownerPID: 101, ownerName: "제어 센터"),
            RawWindow(id: 3, layer: 0, alpha: 1, boundsCG: CGRect(x: 0, y: 0, width: 1512, height: 982), ownerPID: 999, ownerName: "Snowman"),
            RawWindow(id: 4, layer: 0, alpha: 1, boundsCG: CGRect(x: 10, y: 10, width: 50, height: 20), ownerPID: 102, ownerName: "Tiny"),
            RawWindow(id: 5, layer: 0, alpha: 1, boundsCG: CGRect(x: 0, y: 0, width: 1512, height: 982), ownerPID: 103, ownerName: "Dock"),
            RawWindow(id: 6, layer: 0, alpha: 0, boundsCG: CGRect(x: 0, y: 100, width: 500, height: 500), ownerPID: 104, ownerName: "Ghost"),
            RawWindow(id: 8, layer: 0, alpha: 1, boundsCG: CGRect(x: 462, y: 228, width: 380, height: 640), ownerPID: 105, ownerName: "카카오톡"),
        ]
        let kept = filterSnowWindows(raw, ownPID: 999)
        check("filterKeepsOnlyNormalWindows", kept.map(\.id) == [1, 8], "kept \(kept.map(\.id))")
    }
    do { // frontWindowHidesBackLedge
        let f = CGRect(x: 0, y: 0, width: 1512, height: 949)
        let all = specs([(1, f), (2, f)])
        if let back = all.first(where: { $0.kind == .window(2) }) {
            let vis = visibility(for: back, columnCount: columns(back))
            check("frontWindowHidesBackLedge", vis.hidden.allSatisfy { $0 })
        } else {
            check("frontWindowHidesBackLedge.exists", false)
        }
    }
    do { // occluderAboveLimitsCeiling
        let back = CGRect(x: 0, y: 100, width: 600, height: 400)   // top edge y = 500
        let front = CGRect(x: 0, y: 505, width: 300, height: 195)  // bottom edge 5pt above
        let all = specs([(1, front), (2, back)])
        if let s = all.first(where: { $0.kind == .window(2) }) {
            let vis = visibility(for: s, columnCount: columns(s))
            checkClose("occluderAboveLimitsCeiling.covered", Double(vis.ceiling[10]), 5, tol: 0.001)
            check("occluderAboveLimitsCeiling.free", vis.ceiling[200] == .infinity)
            check("occluderAboveLimitsCeiling.notHidden", !vis.hidden[10])
        } else {
            check("occluderAboveLimitsCeiling.exists", false)
        }
    }
    do { // maximizedWindowCappedUnderMenuBar
        let all = specs([(1, CGRect(x: 0, y: 0, width: 1512, height: 949))])
        let s = all.first { $0.kind == .window(1) }
        check("maximizedWindowCappedUnderMenuBar", s?.maxHeight == 10, "got \(String(describing: s?.maxHeight))")
    }
    do { // groundAlwaysPresent
        let all = specs([])
        check("groundAlwaysPresent", all.count == 1 && all[0].kind == .ground && all[0].maxHeight == 22 && all[0].landProbability == 1)
    }
    do { // dockLedgeAndOcclusion
        let dock = CGRect(x: 300, y: 4, width: 900, height: 64)
        let all = specs([], dock: dock)
        let d = all.first { $0.kind == .dock }
        check("dockLedge.geometry", d?.x0 == 300 && d?.x1 == 1200 && d?.y == 68 && d?.maxHeight == 16 && d?.landProbability == 0.85)
        if let g = all.first(where: { $0.kind == .ground }) {
            let vis = visibility(for: g, columnCount: columns(g))
            checkClose("dockLimitsGroundUnderIt", Double(vis.ceiling[400]), 4, tol: 0.001)  // x = 801
            check("groundFreeBesideDock", vis.ceiling[50] == .infinity)                     // x = 101
        }
    }
    do { // windowsExcludedWhenToggledOff
        let all = specs([(1, CGRect(x: 100, y: 200, width: 400, height: 300))], includeWindows: false)
        check("windowsExcludedWhenToggledOff", !all.contains { if case .window = $0.kind { return true } else { return false } })
    }
    let w7 = CGRect(x: 100, y: 200, width: 400, height: 300)
    do { // pileStoreDropsClosedWindow
        let store = PileStore()
        _ = store.sync(specs([(7, w7)]), now: 0, graceUntil: 0)
        store.piles[.window(7)]?.add(atLocalX: 50, area: 10)
        let r = store.sync(specs([]), now: 10, graceUntil: 0)
        check("pileStoreDropsClosedWindow.dropped", r.dropped.contains { $0.spec.kind == .window(7) && $0.pile.totalArea > 9 })
        check("pileStoreDropsClosedWindow.removed", store.piles[.window(7)] == nil)
    }
    do { // pileStoreStashesDuringGrace
        let store = PileStore()
        _ = store.sync(specs([(7, w7)]), now: 0, graceUntil: 0)
        store.piles[.window(7)]?.add(atLocalX: 50, area: 10)
        let r = store.sync(specs([]), now: 10, graceUntil: 11)
        check("pileStoreStashesDuringGrace.nothingDropped", r.dropped.isEmpty)
        _ = store.sync(specs([(7, w7)]), now: 20, graceUntil: 0)
        checkClose("pileStoreStashesDuringGrace.restored", Double(store.piles[.window(7)]?.totalArea ?? 0), 10, tol: 0.01)
    }
    do { // dockIsAlwaysStashed
        let dock = CGRect(x: 300, y: 4, width: 900, height: 64)
        let store = PileStore()
        _ = store.sync(specs([], dock: dock), now: 0, graceUntil: 0)
        store.piles[.dock]?.add(atLocalX: 100, area: 10)
        let r = store.sync(specs([]), now: 10, graceUntil: 0)
        check("dockIsAlwaysStashed.nothingDropped", r.dropped.isEmpty)
        _ = store.sync(specs([], dock: dock), now: 20, graceUntil: 0)
        checkClose("dockIsAlwaysStashed.restored", Double(store.piles[.dock]?.totalArea ?? 0), 10, tol: 0.01)
    }
    do { // movedWindowReportsDelta
        let store = PileStore()
        _ = store.sync(specs([(7, w7)]), now: 0, graceUntil: 0)
        let r = store.sync(specs([(7, w7.offsetBy(dx: 30, dy: -10))]), now: 1, graceUntil: 0)
        let m = r.moved.first { $0.kind == .window(7) }
        check("movedWindowReportsDelta", m?.dx == 30 && m?.dy == -10, "got \(String(describing: m))")
    }
}
