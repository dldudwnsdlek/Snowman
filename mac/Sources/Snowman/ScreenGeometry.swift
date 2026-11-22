import AppKit

/// Converts between global CG coordinates (top-left origin, y down) and one screen's scene (bottom-left, y up).
struct ScreenGeometry {
    let frameCG: CGRect
    let menuBarHeight: CGFloat
    let backingScale: CGFloat

    init(screen: NSScreen) {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        frameCG = CGRect(x: screen.frame.minX, y: primaryHeight - screen.frame.maxY,
                         width: screen.frame.width, height: screen.frame.height)
        menuBarHeight = max(0, screen.frame.maxY - screen.visibleFrame.maxY)
        backingScale = screen.backingScaleFactor
    }

    var size: CGSize { frameCG.size }

    func toScene(cgPoint p: CGPoint) -> CGPoint {
        CGPoint(x: p.x - frameCG.minX, y: frameCG.maxY - p.y)
    }

    func toScene(cgRect r: CGRect) -> CGRect {
        CGRect(x: r.minX - frameCG.minX, y: frameCG.maxY - r.maxY, width: r.width, height: r.height)
    }

    /// Mouse location (AppKit global coordinates) in this scene, or nil when it is on another screen.
    func sceneMouse(_ nsPoint: NSPoint) -> CGPoint? {
        let primaryHeight = NSScreen.screens.first?.frame.height ?? frameCG.height
        let cg = CGPoint(x: nsPoint.x, y: primaryHeight - nsPoint.y)
        guard frameCG.insetBy(dx: -1, dy: -1).contains(cg) else { return nil }
        return toScene(cgPoint: cg)
    }
}
