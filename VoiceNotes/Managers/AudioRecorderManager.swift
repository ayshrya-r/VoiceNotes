import AVFoundation

protocol AudioRecorderManagerDelegate: AnyObject {
    /// Called frequently (driven by CADisplayLink-equivalent timer) with a normalized
    /// power level in 0...1 suitable for driving a live waveform.
    func audioRecorderManager(_ manager: AudioRecorderManager, didUpdatePower level: Float)
    func audioRecorderManager(_ manager: AudioRecorderManager, didFinishRecordingTo url: URL, duration: TimeInterval)
    func audioRecorderManager(_ manager: AudioRecorderManager, didFailWithError error: Error)
}

/// Wraps `AVAudioRecorder` to provide simple start/stop recording with
/// real-time metering suitable for driving a live waveform UI.
final class AudioRecorderManager: NSObject {

    weak var delegate: AudioRecorderManagerDelegate?

    private var recorder: AVAudioRecorder?
    private var meterTimer: Timer?
    private var currentURL: URL?

    private(set) var isRecording = false

    /// How often we sample the meter. 0.05s (20fps) is smooth enough for a waveform
    /// while being cheap on CPU.
    private let meterInterval: TimeInterval = 0.05

    // MARK: - Permission

    func requestPermission(completion: @escaping (Bool) -> Void) {
        if #available(iOS 17.0, *) {
            AVAudioApplication.requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                DispatchQueue.main.async { completion(granted) }
            }
        }
    }

    // MARK: - Recording lifecycle

    func startRecording() {
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            let fileName = "rec_\(UUID().uuidString).m4a"
            let url = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(fileName)
            currentURL = url

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            let newRecorder = try AVAudioRecorder(url: url, settings: settings)
            newRecorder.delegate = self
            newRecorder.isMeteringEnabled = true
            newRecorder.prepareToRecord()
            newRecorder.record()

            self.recorder = newRecorder
            self.isRecording = true
            startMeterTimer()
        } catch {
            delegate?.audioRecorderManager(self, didFailWithError: error)
        }
    }

    func stopRecording() {
        guard isRecording, let recorder = recorder else { return }
        let duration = recorder.currentTime
        recorder.stop()
        stopMeterTimer()
        isRecording = false

        if let url = currentURL {
            delegate?.audioRecorderManager(self, didFinishRecordingTo: url, duration: duration)
        }

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    func cancelRecording() {
        guard let recorder = recorder else { return }
        recorder.stop()
        recorder.deleteRecording()
        stopMeterTimer()
        isRecording = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    // MARK: - Metering

    private func startMeterTimer() {
        meterTimer?.invalidate()
        let timer = Timer(timeInterval: meterInterval, repeats: true) { [weak self] _ in
            self?.sampleMeter()
        }
        RunLoop.main.add(timer, forMode: .common)
        meterTimer = timer
    }

    private func stopMeterTimer() {
        meterTimer?.invalidate()
        meterTimer = nil
    }

    private func sampleMeter() {
        guard let recorder = recorder, recorder.isRecording else { return }
        recorder.updateMeters()
        let decibels = recorder.averagePower(forChannel: 0)
        let normalized = AudioRecorderManager.normalizedPowerLevel(fromDecibels: decibels)
        delegate?.audioRecorderManager(self, didUpdatePower: normalized)
    }

    /// Converts a decibel reading (-160 silence ... 0 loudest) into a 0...1 range,
    /// applying a noise floor so quiet rooms don't constantly flicker the waveform.
    static func normalizedPowerLevel(fromDecibels decibels: Float) -> Float {
        let minDecibels: Float = -50
        if decibels < minDecibels { return 0 }
        if decibels >= 0 { return 1 }
        let scale = (decibels - minDecibels) / (0 - minDecibels)
        // Slight curve so mid-range speech reads as visually lively, not flat.
        return pow(scale, 1.5)
    }
}

extension AudioRecorderManager: AVAudioRecorderDelegate {
    func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
        if let error = error {
            delegate?.audioRecorderManager(self, didFailWithError: error)
        }
    }
}
