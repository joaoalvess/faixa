import AppKit
import CoreAudio
import SwiftUI

struct PlayerPopoverView: View {
    let player: MusicPlayer
    let outputs: AudioOutputs

    var body: some View {
        VStack(spacing: 0) {
            ArtworkView(image: player.artwork)
                .padding(.bottom, 3)

            VStack(spacing: 0) {
                Text(player.track?.title ?? "Nada tocando")
                Text(player.track?.artist ?? " ")
            }
            .font(.headline)
            .lineLimit(1)
            .padding(.bottom, 12)

            ProgressSection(player: player)
                .padding(.bottom, 10)

            PlaybackControls(player: player)
                .padding(.bottom, 8)

            VolumeRow(player: player, outputs: outputs)
        }
        .frame(width: 166)
        .foregroundStyle(.white)
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
                            .font(.system(size: 44))
                            .foregroundStyle(.white.opacity(0.5))
                    }
            }
        }
        .frame(width: 166, height: 166)
        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
    }
}

private struct ProgressSection: View {
    let player: MusicPlayer
    @State private var scrubPosition: TimeInterval?

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let duration = player.track?.duration ?? 0
            let position = scrubPosition ?? player.position(at: context.date)

            VStack(spacing: 4) {
                CapsuleSlider(
                    fraction: duration > 0 ? position / duration : 0,
                    height: 6,
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
                .font(.system(size: 8, weight: .medium).monospacedDigit())
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 2.5)
            }
        }
    }

    private static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%02d:%02d", total / 60, total % 60)
    }
}

private struct PlaybackControls: View {
    let player: MusicPlayer

    var body: some View {
        HStack(spacing: 0) {
            ControlButton(symbol: player.isFavorited ? "star.fill" : "star", size: 12, width: 30) {
                player.toggleFavorite()
            }
            ControlButton(symbol: "backward.fill", size: 12.5, width: 33) {
                player.previousTrack()
            }
            ControlButton(symbol: player.state == .playing ? "pause.fill" : "play.fill", size: 16, width: 33) {
                player.playPause()
            }
            ControlButton(symbol: "forward.fill", size: 12.5, width: 33) {
                player.nextTrack()
            }
            ControlButton(symbol: "shuffle", size: 12.5, width: 30) {
                player.toggleShuffle()
            }
            .opacity(player.isShuffleEnabled ? 1 : 0.45)
        }
        .frame(height: 20)
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

private struct VolumeRow: View {
    let player: MusicPlayer
    let outputs: AudioOutputs

    var body: some View {
        HStack(spacing: 0) {
            Menu {
                Picker("Saída de áudio", selection: outputSelection) {
                    ForEach(outputs.devices) { device in
                        Text(device.name).tag(Optional(device.id))
                    }
                }
                .pickerStyle(.inline)
            } label: {
                Image(systemName: "hifispeaker.fill")
                    .font(.system(size: 11))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .frame(width: 17)

            Spacer(minLength: 0)

            HStack(spacing: 8.7) {
                Image(systemName: "speaker.wave.1.fill")
                    .font(.system(size: 9.5))
                CapsuleSlider(
                    fraction: player.volume / 100,
                    height: 4,
                    onChange: { player.setVolume($0 * 100) }
                )
                .frame(width: 89)
                Image(systemName: "speaker.wave.2.fill")
                    .font(.system(size: 8))
            }

            Spacer(minLength: 0)

            Menu {
                Picker("Repetir", selection: repeatSelection) {
                    Text("Desligado").tag(RepeatMode.off)
                    Text("Uma").tag(RepeatMode.one)
                    Text("Todas").tag(RepeatMode.all)
                }
                Divider()
                Button("Sair do Faixa") {
                    NSApp.terminate(nil)
                }
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12))
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .menuIndicator(.hidden)
            .frame(width: 13)
        }
        .frame(height: 18)
    }

    private var outputSelection: Binding<AudioDeviceID?> {
        Binding(
            get: { outputs.currentID },
            set: { id in
                if let id {
                    outputs.select(id)
                }
            }
        )
    }

    private var repeatSelection: Binding<RepeatMode> {
        Binding(
            get: { player.repeatMode },
            set: { player.setRepeat($0) }
        )
    }
}
