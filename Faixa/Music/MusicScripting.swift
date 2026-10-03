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

    private func run(_ source: String) -> NSAppleEventDescriptor? {
        guard isMusicRunning else { return nil }

        let script = compiledScripts[source] ?? NSAppleScript(source: source)
        compiledScripts[source] = script

        var error: NSDictionary?
        let result = script?.executeAndReturnError(&error)
        return error == nil ? result : nil
    }
}
