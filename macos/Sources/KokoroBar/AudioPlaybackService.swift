import AVFoundation
import Foundation

@MainActor
final class AudioPlaybackService: NSObject, AVAudioPlayerDelegate {
    private var player: AVAudioPlayer?

    func play(fileURL: URL) throws {
        stop()
        let newPlayer = try AVAudioPlayer(contentsOf: fileURL)
        newPlayer.delegate = self
        newPlayer.prepareToPlay()

        guard newPlayer.play() else {
            throw PlaybackError.failedToStart
        }

        player = newPlayer
    }

    func stop() {
        player?.stop()
        player = nil
    }
}

enum PlaybackError: LocalizedError {
    case failedToStart

    var errorDescription: String? {
        "Audio playback failed to start."
    }
}
