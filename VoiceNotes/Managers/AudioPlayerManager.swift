import AVFoundation

protocol AudioPlayerManagerDelegate: AnyObject {
    func audioPlayerManager(_ manager: AudioPlayerManager, didUpdateProgress progress: Double, currentTime: TimeInterval)
    func audioPlayerManagerDidFinishPlaying(_ manager: AudioPlayerManager)
}

/// Wraps `AVAudioPlayer` to provide play/pause/seek with progress callbacks
/// suitable for driving a playback progress bar or waveform highlight.
final class AudioPlayerManager: NSObject {

    weak var delegate: AudioPlayerManagerDelegate?

    private var player: AVAudioPlayer?
    private var progressTimer: Timer?

    private(set) var isPlaying = false
    var duration: TimeInterval { player?.duration ?? 0 }
    var currentTime: TimeInterval { player?.currentTime ?? 0 }

    func load(url: URL) {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.delegate = self
            player?.prepareToPlay()
        } catch {
            player = nil
        }
    }

    func play() {
        guard let player = player else { return }
        player.play()
        isPlaying = true
        startProgressTimer()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        stopProgressTimer()
    }

    func togglePlayPause() {
        isPlaying ? pause() : play()
    }

    func seek(to progress: Double) {
        guard let player = player else { return }
        let clamped = max(0, min(1, progress))
        player.currentTime = clamped * player.duration
        delegate?.audioPlayerManager(self, didUpdateProgress: clamped, currentTime: player.currentTime)
    }

    func stop() {
        player?.stop()
        isPlaying = false
        stopProgressTimer()
    }

    private func startProgressTimer() {
        progressTimer?.invalidate()
        let timer = Timer(timeInterval: 0.03, repeats: true) { [weak self] _ in
            guard let self, let player = self.player, player.duration > 0 else { return }
            let progress = player.currentTime / player.duration
            self.delegate?.audioPlayerManager(self, didUpdateProgress: progress, currentTime: player.currentTime)
        }
        RunLoop.main.add(timer, forMode: .common)
        progressTimer = timer
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}

extension AudioPlayerManager: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        isPlaying = false
        stopProgressTimer()
        delegate?.audioPlayerManager(self, didUpdateProgress: 0, currentTime: 0)
        delegate?.audioPlayerManagerDidFinishPlaying(self)
    }
}
