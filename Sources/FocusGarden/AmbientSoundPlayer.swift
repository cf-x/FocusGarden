import AVFoundation
import Foundation

@MainActor
final class AmbientSoundPlayer: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?
    private var selectedSound: AmbientSound?
    private var masterVolume = 0.28

    private(set) var isPlaying = false

    func play(_ sound: AmbientSound, volume: Double) {
        stop()

        let resource = sound.audioResource
        guard let url = Bundle.main.url(
            forResource: resource.name,
            withExtension: resource.extension,
            subdirectory: "AmbientSounds"
        ) else {
            isPlaying = false
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.delegate = self
            player.numberOfLoops = -1
            player.enableRate = false
            selectedSound = sound
            masterVolume = volume
            player.volume = effectiveVolume(for: sound, masterVolume: volume)
            player.prepareToPlay()
            isPlaying = player.play()
            self.player = player
        } catch {
            player = nil
            selectedSound = nil
            isPlaying = false
        }
    }

    func setVolume(_ volume: Double) {
        masterVolume = volume
        guard let selectedSound else { return }
        player?.volume = effectiveVolume(for: selectedSound, masterVolume: volume)
    }

    func stop() {
        player?.stop()
        player = nil
        selectedSound = nil
        isPlaying = false
    }

    nonisolated func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        Task { @MainActor [weak self] in
            self?.stop()
        }
    }

    private func effectiveVolume(for sound: AmbientSound, masterVolume: Double) -> Float {
        Float(min(1, max(0, masterVolume * sound.playbackGain)))
    }
}
