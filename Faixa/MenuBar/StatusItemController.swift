import AppKit
import Observation

@MainActor
final class StatusItemController {
    private let player: MusicPlayer
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let maxTitleWidth: CGFloat = 240
    private let artworkSize = NSSize(width: 18, height: 18)

    private lazy var idleImage: NSImage? = {
        let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Faixa")
        image?.isTemplate = true
        return image
    }()

    init(player: MusicPlayer) {
        self.player = player
        statusItem.menu = makeMenu()
        observe()
    }

    private func observe() {
        withObservationTracking {
            render()
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in self?.observe() }
        }
    }

    private func render() {
        guard let button = statusItem.button else { return }

        guard let track = player.track, player.state != .stopped else {
            button.image = idleImage
            button.title = ""
            button.imagePosition = .imageOnly
            return
        }

        button.image = player.artwork.map(roundedThumbnail) ?? idleImage
        button.imagePosition = .imageLeading
        button.title = fitted(
            track.artist.isEmpty ? track.title : "\(track.title) — \(track.artist)",
            font: button.font ?? .menuBarFont(ofSize: 0)
        )
    }

    private func roundedThumbnail(_ artwork: NSImage) -> NSImage {
        NSImage(size: artworkSize, flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).addClip()
            artwork.draw(in: rect)
            return true
        }
    }

    private func fitted(_ text: String, font: NSFont) -> String {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        func width(_ string: String) -> CGFloat { (string as NSString).size(withAttributes: attributes).width }

        guard width(text) > maxTitleWidth else { return text }

        var truncated = text
        while !truncated.isEmpty, width(truncated + "…") > maxTitleWidth {
            truncated.removeLast()
        }
        return truncated.trimmingCharacters(in: .whitespaces) + "…"
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.addItem(withTitle: "Sair do Faixa", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
}
