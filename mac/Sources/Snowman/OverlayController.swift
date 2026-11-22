import AppKit
import SnowCore
import SpriteKit

/// Borderless panel that never takes focus.
final class OverlayPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

/// SpriteKit view that reacts to the very first click without activating the app.
final class OverlaySKView: SKView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}

/// One transparent overlay per screen, fed by the window tracker.
final class OverlayController {
    struct Overlay {
        let screenNumber: Int
        let panel: OverlayPanel
        let view: OverlaySKView
        let scene: SnowScene
    }

    private(set) var overlays: [Overlay] = []
    private let tracker = WindowTracker()
    private var timer: Timer?
    private var lastPoll: TimeInterval = 0
    private var fastUntil: TimeInterval = 0
    private(set) var lastSnapshot: TrackerSnapshot?
    private(set) var axTrusted = AXIsProcessTrusted()

    init() {
        rebuild()
        let t = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        timer = t
        NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification,
                                               object: nil, queue: .main) { [weak self] _ in self?.rebuild() }
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.activeSpaceDidChangeNotification,
                                                          object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            let now = CACurrentMediaTime()
            self.fastUntil = now + 1.5
            self.overlays.forEach { $0.scene.noteSpaceChange(now: now) }
        }
    }

    var scenes: [SnowScene] { overlays.map(\.scene) }

    func rebuild() {
        let settings = Settings.shared
        for o in overlays { o.panel.orderOut(nil); o.panel.close() }
        overlays = NSScreen.screens.map { screen in
            let panel = OverlayPanel(contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
                                     backing: .buffered, defer: false)
            panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.dockWindow)) + 1)
            panel.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = false
            panel.ignoresMouseEvents = true
            panel.isReleasedWhenClosed = false
            panel.hidesOnDeactivate = false
            panel.becomesKeyOnlyIfNeeded = true
            panel.animationBehavior = .none
            panel.setFrame(screen.frame, display: false)

            let view = OverlaySKView(frame: CGRect(origin: .zero, size: screen.frame.size))
            view.allowsTransparency = true
            view.preferredFramesPerSecond = 60
            view.ignoresSiblingOrder = true
            let scene = SnowScene(geometry: ScreenGeometry(screen: screen))
            scene.amount = settings.amount
            scene.snowing = !settings.paused
            scene.accumulateOnWindows = settings.accumulateOnWindows
            view.presentScene(scene)
            panel.contentView = view
            panel.orderFrontRegardless()
            let number = (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.intValue ?? 0
            return Overlay(screenNumber: number, panel: panel, view: view, scene: scene)
        }
        lastSnapshot = nil
    }

    private func tick() {
        let now = CACurrentMediaTime()
        let mouseDown = NSEvent.pressedMouseButtons != 0
        let nearBottom = NSEvent.mouseLocation.y < 12
        let fast = mouseDown || nearBottom || now < fastUntil
        if now - lastPoll >= (fast ? 1.0 / 60 : 1.0 / 8) {
            lastPoll = now
            let snap = tracker.snapshot(now: now)
            axTrusted = snap.axTrusted
            if snap != lastSnapshot {
                if lastSnapshot != nil { fastUntil = now + 1.0 }
                lastSnapshot = snap
                for o in overlays { o.scene.apply(snapshot: snap, now: now) }
            }
        }
        for o in overlays where o.panel.ignoresMouseEvents == o.scene.wantsMouse {
            o.panel.ignoresMouseEvents = !o.scene.wantsMouse
        }
    }

    // MARK: - Commands from the menu

    func setSnowing(_ on: Bool) { scenes.forEach { $0.setSnowing(on) } }
    func setAmount(_ a: SnowAmount) { scenes.forEach { $0.setAmount(a) } }
    func setAccumulateOnWindows(_ on: Bool) {
        scenes.forEach { $0.setAccumulateOnWindows(on) }
        lastSnapshot = nil
    }
    func clearSnow() { scenes.forEach { $0.clearSnow() } }
    func clearSnowmen() { scenes.forEach { $0.clearSnowmen() } }
    func callPlow() { scenes.forEach { $0.callPlow() } }

    /// Builds a snowman on the screen that has the mouse (or the main screen).
    func spawnSnowman(style: SnowmanStyle?) {
        let mouse = NSEvent.mouseLocation
        let target = overlays.first { $0.scene.geometry.sceneMouse(mouse) != nil } ?? overlays.first
        target?.scene.spawnSnowman(style: style)
    }
}
