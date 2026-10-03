import AppKit
import SwiftUI

struct PlayerPopoverView: View {
    let player: MusicPlayer
    @State private var isHoveringArtwork = false

    var body: some View {
        VStack(spacing: 0) {
            ArtworkView(image: player.artwork)
                .overlay(alignment: .bottom) {
                    if isHoveringArtwork {
                        ControlPanel(player: player)
                            .padding(8.5)
                            .transition(.opacity)
                    }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isHoveringArtwork = hovering
                    }
                }
                .padding(.bottom, 18.5)

            VStack(spacing: -3.5) {
                Text(player.track?.title ?? "Nada tocando")
                    .foregroundStyle(.white)
                Text(player.track?.artist ?? " ")
                    .foregroundStyle(.white.opacity(0.6))
            }
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
        }
        .padding(.horizontal, 12.5)
        .padding(.top, 13.5)
        .padding(.bottom, 21)
        .frame(width: 247)
        .background {
            Backdrop(image: player.artwork)
        }
    }
}

private struct Backdrop: View {
    let image: NSImage?

    var body: some View {
        ZStack {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
                    .blur(radius: 45, opaque: true)
                    .opacity(0.7)
            }
            Color.black.opacity(0.2)
        }
        .ignoresSafeArea()
    }
}

private struct ArtworkView: View {
    let image: NSImage?

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Rectangle()
                    .fill(.white.opacity(0.1))
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }
        }
        .frame(width: 222, height: 222)
        .clipShape(RoundedRectangle(cornerRadius: 11.5, style: .continuous))
    }
}

private struct ControlPanel: View {
    let player: MusicPlayer

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 0) {
                LinkButton(track: player.track)
                ControlButton(symbol: "backward.fill", size: 13.5, width: 34) {
                    player.previousTrack()
                }
                .foregroundStyle(.white.opacity(0.9))
                ControlButton(symbol: player.state == .playing ? "pause.fill" : "play.fill", size: 17, width: 34) {
                    player.playPause()
                }
                .foregroundStyle(.white.opacity(0.9))
                ControlButton(symbol: "forward.fill", size: 13.5, width: 34) {
                    player.nextTrack()
                }
                .foregroundStyle(.white.opacity(0.9))
                ControlButton(symbol: "shuffle", size: 13, width: 29.5) {
                    player.toggleShuffle()
                }
                .foregroundStyle(.white.opacity(player.isShuffleEnabled ? 0.9 : 0.55))
            }

            ProgressSection(player: player)
        }
        .padding(.top, 18)
        .padding(.horizontal, 12)
        .padding(.bottom, 5)
        .background {
            RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                .fill(Color(white: 0.21).opacity(0.94))
                .overlay {
                    RoundedRectangle(cornerRadius: 11.5, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 0.5)
                }
        }
    }
}

private struct LinkButton: View {
    let track: Track?
    @State private var didCopy = false

    var body: some View {
        ControlButton(symbol: didCopy ? "checkmark" : "link", size: 12.5, width: 29.5) {
            guard let track else { return }
            Task {
                guard let url = await AppleMusicLink.url(for: track) else { return }
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(url.absoluteString, forType: .string)
                didCopy = true
                try? await Task.sleep(for: .seconds(1.5))
                didCopy = false
            }
        }
        .foregroundStyle(.white.opacity(0.55))
    }
}

private struct ControlButton: View {
    let symbol: String
    let size: CGFloat
    let width: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: size))
                .frame(width: width, height: 20)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ProgressSection: View {
    let player: MusicPlayer
    @State private var scrubPosition: TimeInterval?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = player.track?.duration ?? 0
            let position = scrubPosition ?? player.position(at: context.date)

            VStack(spacing: 7) {
                CapsuleSlider(
                    fraction: duration > 0 ? position / duration : 0,
                    height: 8,
                    onChange: { scrubPosition = $0 * duration },
                    onCommit: { fraction in
                        player.seek(to: fraction * duration)
                        scrubPosition = nil
                    }
                )

                HStack {
                    Text(Self.format(position))
                    Spacer()
                    Text("-" + Self.format(duration - position))
                }
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.white.opacity(0.72))
                .padding(.horizontal, 3)
            }
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}
