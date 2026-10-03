import AppKit
import Observation

@MainActor
@Observable
final class MusicPlayer {
    private(set) var state: PlaybackState = .stopped
    private(set) var track: Track?
    private(set) var artwork: NSImage?

    @ObservationIgnored private let scripting = MusicScripting()

    func start() {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let snapshot = PlayerSnapshot(userInfo: notification.userInfo ?? [:])
            MainActor.assumeIsolated { self?.apply(snapshot) }
        }

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            guard app?.bundleIdentifier == MusicScripting.bundleIdentifier else { return }
            MainActor.assumeIsolated { self?.apply(.stopped) }
        }

        if let snapshot = scripting.snapshot() {
            apply(snapshot)
        }
    }

    private func apply(_ snapshot: PlayerSnapshot) {
        state = snapshot.state
        guard snapshot.track != track else { return }
        track = snapshot.track
        artwork = track == nil ? nil : scripting.artwork()
    }
}
