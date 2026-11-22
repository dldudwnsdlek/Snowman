import AppKit
import ApplicationServices
import SnowCore
import WinterArt

/// "사용법" window.
final class HelpWindowController: NSObject, NSWindowDelegate {
    static let shared = HelpWindowController()
    private var window: NSWindow?

    private let sections: [(String, String, String)] = [
        ("snowflake", "눈이 내려요", "모든 창 위, Dock 위, 화면 맨 아래에 눈이 쌓여요. 메뉴 막대의 ❄에서 눈 양(조금·보통·펑펑)을 고르거나 잠시 멈출 수 있어요."),
        ("macwindow", "창을 닫으면 우수수", "눈이 쌓인 창을 닫거나 최소화하면 쌓였던 눈이 떨어져 아래에 다시 쌓여요. 창을 세게 흔들어도 눈이 털려요."),
        ("hand.raised.fill", "눈 굴리기", "쌓인 눈 위에 마우스를 올리면 장갑이 나타나요. 눌러서 한 줌 뜬 뒤 옆으로 끌면 굴러가며 커져요. 위로 들어 올리면 들고 다닐 수 있어요."),
        ("figure.stand", "눈사람 만들기", "눈덩이를 다른 눈덩이 위에 놓으면 팔, 눈, 코, 모자가 하나씩 생기며 눈사람이 완성돼요. 메뉴에서 5종 중 하나를 바로 만들 수도 있어요."),
        ("hands.sparkles.fill", "살아 있는 눈사람", "눈사람은 숨 쉬고, 눈을 깜빡이고, 커서가 다가오면 손을 흔들어요. 한 번 클릭하면 춤을 춰요."),
        ("arrow.up.right", "던지기", "눈사람을 잡고 휙 던지면 벽에 부딪혀 와장창! 반대로 튕겨요. 아주 세게 던지면 부서져서 눈덩이 두 개로 돌아가요."),
        ("car.side.fill", "제설차 부르기 (⌘R)", "제설차가 Dock 위 눈을 싹 밀어내요. Dock이 숨어 있으면 화면 아래쪽 눈을 치워요."),
        ("photo.on.rectangle", "겨울 배경화면 10종", "고르는 즉시 바탕화면이 바뀌어요. '원래 배경화면으로'를 누르면 처음 배경화면으로 돌아가요. (macOS는 지금 보고 있는 데스크톱 공간에만 적용해요.)"),
    ]

    func show() {
        if window == nil { window = makeWindow() }
        NSApp.activate(ignoringOtherApps: true)
        window?.center()
        window?.makeKeyAndOrderFront(nil)
    }

    var currentWindow: NSWindow? { window }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }

    private func makeWindow() -> NSWindow {
        let w = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 520, height: 640),
                         styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        w.title = "Snowman 사용법"
        w.titlebarAppearsTransparent = true
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.level = .floating

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 14
        root.edgeInsets = NSEdgeInsets(top: 40, left: 28, bottom: 24, right: 28)

        let header = NSStackView()
        header.orientation = .horizontal
        header.spacing = 6
        for style in SnowmanStyle.allCases {
            let img = SnowmanArt.composite(style: style, height: 64, scale: 2)
            let view = NSImageView(image: NSImage(cgImage: img, size: NSSize(width: CGFloat(img.width) / 2, height: 64)))
            header.addArrangedSubview(view)
        }
        root.addArrangedSubview(header)

        let title = NSTextField(labelWithString: "눈 내리는 맥, Snowman")
        title.font = .systemFont(ofSize: 22, weight: .bold)
        root.addArrangedSubview(title)

        for (symbol, heading, body) in sections {
            root.addArrangedSubview(row(symbol: symbol, heading: heading, body: body))
        }

        if !AXIsProcessTrusted() {
            let note = NSTextField(wrappingLabelWithString: "Dock 크기에 딱 맞게 쌓으려면 메뉴의 'Dock 크기 맞추기 권한 허용…'에서 손쉬운 사용 권한을 켜 주세요. 켜지 않아도 나머지 기능은 모두 동작해요.")
            note.font = .systemFont(ofSize: 12)
            note.textColor = .secondaryLabelColor
            note.preferredMaxLayoutWidth = 464
            root.addArrangedSubview(note)
        }

        root.translatesAutoresizingMaskIntoConstraints = false
        root.widthAnchor.constraint(equalToConstant: 520).isActive = true
        w.contentView = root
        root.layoutSubtreeIfNeeded()
        w.setContentSize(root.fittingSize)
        return w
    }

    private func row(symbol: String, heading: String, body: String) -> NSView {
        let icon = NSImageView(image: NSImage(systemSymbolName: symbol, accessibilityDescription: nil) ?? NSImage())
        icon.symbolConfiguration = .init(pointSize: 18, weight: .medium)
        icon.contentTintColor = .systemBlue
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true

        let h = NSTextField(labelWithString: heading)
        h.font = .systemFont(ofSize: 14, weight: .semibold)
        let b = NSTextField(wrappingLabelWithString: body)
        b.font = .systemFont(ofSize: 12.5)
        b.textColor = .secondaryLabelColor
        b.preferredMaxLayoutWidth = 420

        let text = NSStackView(views: [h, b])
        text.orientation = .vertical
        text.alignment = .leading
        text.spacing = 3

        let line = NSStackView(views: [icon, text])
        line.orientation = .horizontal
        line.alignment = .top
        line.spacing = 12
        return line
    }
}
