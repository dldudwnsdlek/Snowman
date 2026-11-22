import AppKit
import ApplicationServices
import SnowCore
import WinterArt

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var controller: OverlayController!
    private let settings = Settings.shared
    private var activity: NSObjectProtocol?
    private let menu = NSMenu()

    private var pauseItem: NSMenuItem!
    private var amountItems: [SnowAmount: NSMenuItem] = [:]
    private var windowsItem: NSMenuItem!
    private var soundItem: NSMenuItem!
    private var axItem: NSMenuItem!
    private var restoreItem: NSMenuItem!
    private var wallpaperItems: [NSMenuItem] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        activity = ProcessInfo.processInfo.beginActivity(options: [.userInitiatedAllowingIdleSystemSleep],
                                                         reason: "Snow animation")
        Sound.enabled = settings.soundOn
        controller = OverlayController()
        DebugSnapshot.install(controller: controller)
        buildMenu()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "snowflake", accessibilityDescription: "Snowman")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Snowman — 눈 내리는 맥"
        }
        statusItem.menu = menu
        promptAccessibilityOnce()
    }

    // MARK: - Menu

    private func item(_ title: String, _ action: Selector?, _ key: String = "", tag: Int = 0) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: action, keyEquivalent: key)
        it.target = self
        it.tag = tag
        return it
    }

    private func parent(_ title: String, _ submenu: NSMenu) -> NSMenuItem {
        let it = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        it.submenu = submenu
        return it
    }

    private func buildMenu() {
        menu.delegate = self
        menu.autoenablesItems = false

        pauseItem = item("눈 멈추기", #selector(togglePause), "p")
        menu.addItem(pauseItem)
        let amountMenu = NSMenu()
        for a in SnowAmount.allCases {
            let it = item(a.title, #selector(chooseAmount(_:)))
            it.representedObject = a.rawValue
            amountItems[a] = it
            amountMenu.addItem(it)
        }
        menu.addItem(parent("눈 양", amountMenu))
        windowsItem = item("창 위에도 쌓기", #selector(toggleWindows))
        menu.addItem(windowsItem)
        menu.addItem(.separator())

        let snowmanMenu = NSMenu()
        for style in SnowmanStyle.allCases {
            let it = item("\(style.title) 눈사람", #selector(makeSnowman(_:)), tag: style.rawValue)
            let img = SnowmanArt.composite(style: style, height: 22, scale: 2)
            it.image = NSImage(cgImage: img, size: NSSize(width: CGFloat(img.width) / 2, height: CGFloat(img.height) / 2))
            snowmanMenu.addItem(it)
        }
        snowmanMenu.addItem(.separator())
        snowmanMenu.addItem(item("랜덤", #selector(makeSnowman(_:)), tag: -1))
        menu.addItem(parent("눈사람 만들기 ⛄", snowmanMenu))
        menu.addItem(item("제설차 부르기 🚜", #selector(callPlow), "r"))
        menu.addItem(item("쌓인 눈 치우기", #selector(clearSnow), "c"))
        menu.addItem(item("눈사람 모두 치우기", #selector(clearSnowmen)))
        menu.addItem(.separator())

        menu.addItem(parent("겨울 배경화면 고르기 🖼", buildWallpaperMenu()))
        restoreItem = item("원래 배경화면으로", #selector(restoreWallpaper))
        menu.addItem(restoreItem)
        menu.addItem(.separator())

        axItem = item("Dock 크기 맞추기 권한 허용…", #selector(requestAccessibility))
        menu.addItem(axItem)
        soundItem = item("효과음", #selector(toggleSound))
        menu.addItem(soundItem)
        menu.addItem(item("사용법", #selector(showHelp)))
        menu.addItem(item("끝내기", #selector(quit), "q"))
        refreshMenu()
    }

    private func buildWallpaperMenu() -> NSMenu {
        let m = NSMenu()
        wallpaperItems = WallpaperManager.shared.menuEntries().map { entry in
            let it = item(entry.title, #selector(chooseWallpaper(_:)), tag: entry.tag)
            m.addItem(it)
            return it
        }
        WallpaperManager.shared.makeThumbnails { [weak self] thumbs in
            self?.wallpaperItems.forEach { $0.image = thumbs[$0.tag] }
        }
        WallpaperManager.shared.prerenderAll()
        return m
    }

    func menuNeedsUpdate(_ menu: NSMenu) { refreshMenu() }

    private func refreshMenu() {
        pauseItem.title = settings.paused ? "눈 다시 내리기" : "눈 멈추기"
        for (a, it) in amountItems { it.state = a == settings.amount ? .on : .off }
        windowsItem.state = settings.accumulateOnWindows ? .on : .off
        soundItem.state = settings.soundOn ? .on : .off
        axItem.isHidden = AXIsProcessTrusted()
        let current = settings.currentWallpaper
        for it in wallpaperItems { it.state = it.tag == current ? .on : .off }
        restoreItem.isEnabled = WallpaperManager.shared.hasSavedOriginal
    }

    // MARK: - Actions

    @objc private func togglePause() {
        settings.paused.toggle()
        controller.setSnowing(!settings.paused)
    }

    @objc private func chooseAmount(_ sender: NSMenuItem) {
        guard let raw = sender.representedObject as? String, let a = SnowAmount(rawValue: raw) else { return }
        settings.amount = a
        controller.setAmount(a)
        if settings.paused {
            settings.paused = false
            controller.setSnowing(true)
        }
    }

    @objc private func toggleWindows() {
        settings.accumulateOnWindows.toggle()
        controller.setAccumulateOnWindows(settings.accumulateOnWindows)
    }

    @objc private func makeSnowman(_ sender: NSMenuItem) {
        controller.spawnSnowman(style: sender.tag >= 0 ? SnowmanStyle(rawValue: sender.tag) : nil)
    }

    @objc private func callPlow() { controller.callPlow() }
    @objc private func clearSnow() { controller.clearSnow() }
    @objc private func clearSnowmen() { controller.clearSnowmen() }

    @objc private func chooseWallpaper(_ sender: NSMenuItem) {
        WallpaperManager.shared.apply(tag: sender.tag)
        refreshMenu()
    }

    @objc private func restoreWallpaper() {
        WallpaperManager.shared.restoreOriginal()
    }

    @objc private func requestAccessibility() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(options),
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func toggleSound() {
        settings.soundOn.toggle()
        Sound.enabled = settings.soundOn
    }

    @objc private func showHelp() { HelpWindowController.shared.show() }

    @objc private func quit() { NSApp.terminate(nil) }

    private func promptAccessibilityOnce() {
        let key = "didPromptAccessibility"
        guard !AXIsProcessTrusted(), !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            _ = AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary)
        }
    }
}
