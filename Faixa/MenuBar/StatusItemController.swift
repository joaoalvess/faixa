import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let player: MusicPlayer
    private let outputs = AudioOutputs()
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let maxTitleWidth: CGFloat = 240
    private let artworkSize = NSSize(width: 18, height: 18)

    private lazy var idleImage: NSImage? = {
        let image = NSImage(systemSymbolName: "music.note", accessibilityDescription: "Faixa")
        image?.isTemplate = true
        return image
    }()

    private lazy var menu: NSMenu = {
        let menu = NSMenu()
        menu.addItem(withTitle: "Sair do Faixa", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }()

    private lazy var popover: NSPopover = {
        let controller = NSHostingController(rootView: PlayerPopoverView(player: player, outputs: outputs))
        controller.sizingOptions = .preferredContentSize
        let popover = NSPopover()
        popover.behavior = .transient
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentViewController = controller
        return popover
    }()

    init(player: MusicPlayer) {
        self.player = player
        super.init()
        if let button = statusItem.button {
            button.target = self
            button.action = #selector(handleClick(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        observe()
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        if NSApp.currentEvent?.type == .rightMouseUp {
            popover.performClose(nil)
            statusItem.menu = menu
            sender.performClick(nil)
            statusItem.menu = nil
        } else {
            togglePopover(relativeTo: sender)
        }
    }

    private func togglePopover(relativeTo button: NSStatusBarButton) {
        guard !popover.isShown else {
            popover.performClose(nil)
            return
        }
        player.refreshDetails()
        outputs.refresh()
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
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
}
