import AppKit
import Observation
import SwiftUI

@MainActor
final class StatusItemController: NSObject {
    private let player: MusicPlayer
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let nowPlayingView = NowPlayingView()

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
        let controller = NSHostingController(rootView: PlayerPopoverView(player: player))
        controller.sizingOptions = .preferredContentSize
        let popover = NSPopover()
        popover.behavior = .transient
        popover.hasFullSizeContent = true
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
            button.addSubview(nowPlayingView)
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
        NSApp.activate()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        tintPopoverGlass(with: player.artworkColor)
    }

    private func tintPopoverGlass(with color: NSColor?) {
        guard popover.isShown, let frameView = popover.contentViewController?.view.superview else { return }
        glassView(in: frameView)?.tintColor = color?.withAlphaComponent(0.5)
    }

    private func glassView(in view: NSView) -> NSGlassEffectView? {
        if let glass = view as? NSGlassEffectView {
            return glass
        }
        return view.subviews.lazy.compactMap { self.glassView(in: $0) }.first
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
        tintPopoverGlass(with: player.artworkColor)

        guard let track = player.track, player.state != .stopped else {
            nowPlayingView.isHidden = true
            statusItem.length = NSStatusItem.variableLength
            button.image = idleImage
            button.setAccessibilityTitle("Faixa")
            return
        }

        button.image = nil
        button.setAccessibilityTitle(track.title)
        nowPlayingView.isHidden = false
        nowPlayingView.update(artwork: player.artwork, title: track.title, isPlaying: player.state == .playing)
        statusItem.length = nowPlayingView.fittingWidth
        nowPlayingView.frame = NSRect(x: 0, y: 0, width: nowPlayingView.fittingWidth, height: button.bounds.height)
    }
}

private final class NowPlayingView: NSView {
    private let horizontalPadding: CGFloat = 4
    private let artworkSize: CGFloat = 20
    private let spacing: CGFloat = 6
    private let artworkView = NSImageView()
    private let marquee = MarqueeLabel(maxWidth: 90)

    var fittingWidth: CGFloat {
        horizontalPadding * 2 + artworkSize + spacing + marquee.displayedWidth
    }

    init() {
        super.init(frame: .zero)
        artworkView.imageScaling = .scaleAxesIndependently
        addSubview(artworkView)
        addSubview(marquee)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(artwork: NSImage?, title: String, isPlaying: Bool) {
        artworkView.image = artwork.map(roundedThumbnail)
        marquee.update(text: title, isScrolling: isPlaying)
        needsLayout = true
    }

    override func layout() {
        super.layout()
        artworkView.frame = NSRect(
            x: horizontalPadding,
            y: (bounds.height - artworkSize) / 2,
            width: artworkSize,
            height: artworkSize
        )
        marquee.frame = NSRect(
            x: horizontalPadding + artworkSize + spacing,
            y: 0,
            width: marquee.displayedWidth,
            height: bounds.height
        )
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        nil
    }

    private func roundedThumbnail(_ artwork: NSImage) -> NSImage {
        NSImage(size: NSSize(width: artworkSize, height: artworkSize), flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).addClip()
            artwork.draw(in: rect)
            return true
        }
    }
}
