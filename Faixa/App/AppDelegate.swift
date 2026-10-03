import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let player = MusicPlayer()
    private var statusItemController: StatusItemController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        player.start()
        statusItemController = StatusItemController(player: player)
    }
}
