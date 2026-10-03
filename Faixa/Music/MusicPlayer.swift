import AppKit
import Observation

@MainActor
@Observable
final class MusicPlayer {
    private(set) var state: PlaybackState = .stopped
    private(set) var track: Track?
    private(set) var artwork: NSImage?
    private(set) var artworkColor: NSColor?
    private(set) var isShuffleEnabled = false
    private var anchoredPosition: TimeInterval = 0
    private var anchorDate = Date()

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

    func position(at date: Date) -> TimeInterval {
        guard state == .playing else { return anchoredPosition }
        return min(anchoredPosition + date.timeIntervalSince(anchorDate), track?.duration ?? .infinity)
    }

    func refreshDetails() {
        guard let details = scripting.details() else { return }
        anchorPosition(details.position)
        isShuffleEnabled = details.isShuffleEnabled
    }

    func playPause() {
        scripting.playPause()
    }

    func nextTrack() {
        scripting.nextTrack()
    }

    func previousTrack() {
        scripting.previousTrack()
    }

    func seek(to position: TimeInterval) {
        scripting.seek(to: position)
        anchorPosition(position)
    }

    func toggleShuffle() {
        scripting.setShuffle(!isShuffleEnabled)
        isShuffleEnabled.toggle()
    }

    private func anchorPosition(_ position: TimeInterval) {
        anchoredPosition = position
        anchorDate = Date()
    }

    private func apply(_ snapshot: PlayerSnapshot) {
        state = snapshot.state
        if snapshot.track != track {
            track = snapshot.track
            artwork = track == nil ? nil : scripting.artwork()
            artworkColor = artwork?.averageColor
        }
        if state != .stopped {
            refreshDetails()
        }
    }
}
