import AppKit
import ApplicationServices
import SnowCore

struct TrackerSnapshot: Equatable {
    /// Ordinary windows, front to back, global CG coordinates.
    var windows: [RawWindow] = []
    /// Dock platter in global CG coordinates while the Dock is on screen.
    var dockFrameCG: CGRect?
    var axTrusted = false
}

/// Reads where every window and the Dock are.
final class WindowTracker {
    private let ownPID = getpid()
    private var cachedDockFrame: CGRect?
    private var lastAXQuery: TimeInterval = 0
    private var dockWasVisible = false
    private var dockElement: AXUIElement?
    private var dockPID: pid_t = 0

    func snapshot(now: TimeInterval) -> TrackerSnapshot {
        var snap = TrackerSnapshot()
        snap.axTrusted = AXIsProcessTrusted()
        guard let list = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] else {
            return snap
        }
        var raw: [RawWindow] = []
        var dockVisible = false
        raw.reserveCapacity(list.count)
        for w in list {
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            if owner == "Dock" && layer == Int(CGWindowLevelForKey(.dockWindow)) { dockVisible = true }
            guard layer == 0 else { continue }
            var bounds = CGRect.zero
            if let dict = w[kCGWindowBounds as String] as? NSDictionary {
                CGRectMakeWithDictionaryRepresentation(dict, &bounds)
            }
            raw.append(RawWindow(id: w[kCGWindowNumber as String] as? Int ?? 0,
                                 layer: layer,
                                 alpha: w[kCGWindowAlpha as String] as? Double ?? 1,
                                 boundsCG: bounds,
                                 ownerPID: Int32(w[kCGWindowOwnerPID as String] as? Int ?? 0),
                                 ownerName: owner))
        }
        snap.windows = filterSnowWindows(raw, ownPID: ownPID)

        if dockVisible {
            let justAppeared = !dockWasVisible
            if snap.axTrusted {
                if justAppeared || now - lastAXQuery > 0.25 || cachedDockFrame == nil {
                    lastAXQuery = now
                    if let f = queryDockListFrame() { cachedDockFrame = f }
                }
            } else {
                cachedDockFrame = estimatedDockFrame()
            }
            if let f = cachedDockFrame, isOnScreen(f) {
                // The AX list is the icon row; the glass platter is a little larger.
                snap.dockFrameCG = CGRect(x: f.minX - 10, y: f.minY - 8, width: f.width + 20, height: f.height + 14)
            }
        }
        dockWasVisible = dockVisible
        return snap
    }

    private func isOnScreen(_ f: CGRect) -> Bool {
        guard let main = NSScreen.screens.first else { return true }
        let h = main.frame.height
        return NSScreen.screens.contains { s in
            let cg = CGRect(x: s.frame.minX, y: h - s.frame.maxY, width: s.frame.width, height: s.frame.height)
            return cg.insetBy(dx: -2, dy: -2).contains(CGPoint(x: f.midX, y: f.maxY - 4))
        }
    }

    // MARK: - Accessibility

    private func dockApp() -> AXUIElement? {
        guard let app = NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.dock").first else { return nil }
        if dockElement == nil || dockPID != app.processIdentifier {
            dockPID = app.processIdentifier
            let el = AXUIElementCreateApplication(dockPID)
            AXUIElementSetMessagingTimeout(el, 0.15)
            dockElement = el
        }
        return dockElement
    }

    private func queryDockListFrame() -> CGRect? {
        guard let app = dockApp() else { return nil }
        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(app, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else { return nil }
        for child in children {
            var roleRef: CFTypeRef?
            AXUIElementCopyAttributeValue(child, kAXRoleAttribute as CFString, &roleRef)
            guard (roleRef as? String) == (kAXListRole as String) else { continue }
            if let pos = axPoint(child, kAXPositionAttribute), let size = axSize(child, kAXSizeAttribute), size.width > 40 {
                return CGRect(origin: pos, size: size)
            }
        }
        return nil
    }

    private func axRaw(_ el: AXUIElement, _ attr: String) -> AXValue? {
        var ref: CFTypeRef?
        guard AXUIElementCopyAttributeValue(el, attr as CFString, &ref) == .success, let value = ref,
              CFGetTypeID(value) == AXValueGetTypeID() else { return nil }
        return (value as! AXValue)
    }

    private func axPoint(_ el: AXUIElement, _ attr: String) -> CGPoint? {
        guard let v = axRaw(el, attr) else { return nil }
        var p = CGPoint.zero
        return AXValueGetValue(v, .cgPoint, &p) ? p : nil
    }

    private func axSize(_ el: AXUIElement, _ attr: String) -> CGSize? {
        guard let v = axRaw(el, attr) else { return nil }
        var s = CGSize.zero
        return AXValueGetValue(v, .cgSize, &s) ? s : nil
    }

    /// Rough Dock size from its preferences, used until Accessibility is allowed.
    private func estimatedDockFrame() -> CGRect? {
        guard let main = NSScreen.screens.first else { return nil }
        let prefs = UserDefaults(suiteName: "com.apple.dock")
        var tile = CGFloat(prefs?.double(forKey: "tilesize") ?? 0)
        if tile <= 0 { tile = 48 }
        let apps = prefs?.array(forKey: "persistent-apps")?.count ?? 10
        let others = prefs?.array(forKey: "persistent-others")?.count ?? 1
        let recents = (prefs?.object(forKey: "show-recents") as? Bool ?? true) ? 3 : 0
        let screenW = main.frame.width
        var count = CGFloat(apps + others + recents + 2)
        var width = count * (tile + 4) + 16
        if width > screenW - 24 {
            let shrink = (screenW - 24) / width
            tile *= shrink
            count *= 1
            width = screenW - 24
        }
        let height = tile + 10
        return CGRect(x: (screenW - width) / 2, y: main.frame.height - height - 10, width: width, height: height)
    }
}
