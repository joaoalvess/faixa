import AppKit

@MainActor
final class MusicScripting {
    nonisolated static let bundleIdentifier = "com.apple.Music"

    private var compiledScripts: [String: NSAppleScript] = [:]

    var isMusicRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: Self.bundleIdentifier).isEmpty
    }

    func snapshot() -> PlayerSnapshot? {
        guard let result = run("""
            tell application id "com.apple.Music"
                if player state is stopped then return {false}
                set t to current track
                return {true, player state is playing, name of t, artist of t, album of t, duration of t}
            end tell
            """)
        else { return nil }

        guard result.numberOfItems == 6, result.atIndex(1)?.booleanValue == true else { return .stopped }

        return PlayerSnapshot(
            state: result.atIndex(2)?.booleanValue == true ? .playing : .paused,
            track: Track(
                title: result.atIndex(3)?.stringValue ?? "",
                artist: result.atIndex(4)?.stringValue ?? "",
                album: result.atIndex(5)?.stringValue ?? "",
                duration: result.atIndex(6)?.doubleValue ?? 0
            )
        )
    }

    func details() -> PlayerDetails? {
        guard let result = run("""
            tell application id "com.apple.Music"
                if player state is stopped then return {false}
                try
                    set isFavorited to favorited of current track
                on error
                    set isFavorited to false
                end try
                return {true, player position, shuffle enabled, song repeat is one, song repeat is all, sound volume, isFavorited}
            end tell
            """),
            result.numberOfItems == 7,
            result.atIndex(1)?.booleanValue == true
        else { return nil }

        let repeatMode: RepeatMode =
            if result.atIndex(4)?.booleanValue == true { .one }
            else if result.atIndex(5)?.booleanValue == true { .all }
            else { .off }

        return PlayerDetails(
            position: result.atIndex(2)?.doubleValue ?? 0,
            isShuffleEnabled: result.atIndex(3)?.booleanValue == true,
            repeatMode: repeatMode,
            volume: result.atIndex(6)?.doubleValue ?? 0,
            isFavorited: result.atIndex(7)?.booleanValue == true
        )
    }

    func artwork() -> NSImage? {
        guard let result = run("""
            tell application id "com.apple.Music"
                if (count of artworks of current track) is 0 then return missing value
                return raw data of artwork 1 of current track
            end tell
            """)
        else { return nil }

        return NSImage(data: result.data)
    }

    func playPause() {
        tell("playpause")
    }

    func nextTrack() {
        tell("next track")
    }

    func previousTrack() {
        tell("back track")
    }

    func seek(to position: TimeInterval) {
        tell("set player position to \(position)", cached: false)
    }

    func setVolume(_ volume: Int) {
        tell("set sound volume to \(volume)", cached: false)
    }

    func setShuffle(_ isEnabled: Bool) {
        tell("set shuffle enabled to \(isEnabled)")
    }

    func setRepeat(_ mode: RepeatMode) {
        tell("set song repeat to \(mode.rawValue)")
    }

    func toggleFavorite() -> Bool? {
        run("""
            tell application id "com.apple.Music"
                set favorited of current track to not (favorited of current track)
                return favorited of current track
            end tell
            """)?.booleanValue
    }

    private func tell(_ command: String, cached: Bool = true) {
        run("tell application id \"com.apple.Music\" to \(command)", cached: cached)
    }

    @discardableResult
    private func run(_ source: String, cached: Bool = true) -> NSAppleEventDescriptor? {
        guard isMusicRunning else { return nil }

        let script = compiledScripts[source] ?? NSAppleScript(source: source)
        if cached {
            compiledScripts[source] = script
        }

        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}
