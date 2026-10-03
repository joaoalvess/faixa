import Foundation

struct Track: Equatable, Sendable {
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
}

enum PlaybackState: Sendable {
    case playing
    case paused
    case stopped
}

enum RepeatMode: String, CaseIterable, Sendable {
    case off
    case one
    case all
}

struct PlayerDetails: Sendable {
    let position: TimeInterval
    let isShuffleEnabled: Bool
    let repeatMode: RepeatMode
    let volume: Double
    let isFavorited: Bool
}

struct PlayerSnapshot: Sendable {
    let state: PlaybackState
    let track: Track?

    static let stopped = PlayerSnapshot(state: .stopped, track: nil)
}

extension PlayerSnapshot {
    init(userInfo: [AnyHashable: Any]) {
        switch userInfo["Player State"] as? String {
        case "Playing": state = .playing
        case "Paused": state = .paused
        default: state = .stopped
        }

        guard state != .stopped, let title = userInfo["Name"] as? String else {
            track = nil
            return
        }

        track = Track(
            title: title,
            artist: userInfo["Artist"] as? String ?? "",
            album: userInfo["Album"] as? String ?? "",
            duration: (userInfo["Total Time"] as? Double ?? 0) / 1000
        )
    }
}
