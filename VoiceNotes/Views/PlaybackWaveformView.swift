import UIKit
import AVFoundation

/// Renders a static waveform generated from an audio file's samples, with a
/// progress overlay that fills left-to-right as playback advances — similar
/// to voice-message players in chat apps.
final class PlaybackWaveformView: UIView {

    private let trackLayer = CAShapeLayer()
    private let progressLayer = CAShapeLayer()
    private let progressMask = CAShapeLayer()

    private var barPath = UIBezierPath()
    private var sampleCount = 40

    /// 0...1
    var progress: CGFloat = 0 {
        didSet { updateProgressMask() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    private func setup() {
        backgroundColor = .clear
        trackLayer.fillColor = UIColor.systemGray4.cgColor
        progressLayer.fillColor = UIColor.systemRed.cgColor
        layer.addSublayer(trackLayer)
        layer.addSublayer(progressLayer)
        progressLayer.mask = progressMask
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redraw()
    }

    /// Loads and analyzes the audio file to extract amplitude samples for drawing.
    func loadWaveform(from url: URL) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self else { return }
            let samples = Self.extractAmplitudes(from: url, targetCount: self.sampleCount)
            DispatchQueue.main.async {
                self.drawBars(with: samples)
            }
        }
    }

    private func drawBars(with samples: [Float]) {
        let path = UIBezierPath()
        guard bounds.width > 0, !samples.isEmpty else { return }

        let barSpacing: CGFloat = 3
        let barWidth = (bounds.width - CGFloat(samples.count - 1) * barSpacing) / CGFloat(samples.count)
        let midY = bounds.height / 2
        let maxHeight = bounds.height

        for (i, sample) in samples.enumerated() {
            let height = max(3, CGFloat(sample) * maxHeight)
            let x = CGFloat(i) * (barWidth + barSpacing)
            let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
            path.append(UIBezierPath(roundedRect: rect, cornerRadius: barWidth / 2))
        }

        barPath = path
        trackLayer.path = path.cgPath
        progressLayer.path = path.cgPath
        updateProgressMask()
    }

    private func redraw() {
        trackLayer.path = barPath.cgPath
        progressLayer.path = barPath.cgPath
        updateProgressMask()
    }

    private func updateProgressMask() {
        let maskRect = CGRect(x: 0, y: 0, width: bounds.width * progress, height: bounds.height)
        progressMask.frame = bounds
        progressMask.path = UIBezierPath(rect: maskRect).cgPath
    }

    /// Reads an audio file and downsamples it into `targetCount` normalized (0...1) amplitude buckets.
    private static func extractAmplitudes(from url: URL, targetCount: Int) -> [Float] {
        guard let file = try? AVAudioFile(forReading: url) else {
            return (0..<targetCount).map { _ in Float.random(in: 0.15...0.5) }
        }

        let format = file.processingFormat
        let frameCount = AVAudioFrameCount(file.length)
        guard frameCount > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return Array(repeating: 0.2, count: targetCount)
        }

        do {
            try file.read(into: buffer)
        } catch {
            return Array(repeating: 0.2, count: targetCount)
        }

        guard let channelData = buffer.floatChannelData else {
            return Array(repeating: 0.2, count: targetCount)
        }

        let channelCount = Int(format.channelCount)
        let length = Int(buffer.frameLength)
        guard length > 0 else { return Array(repeating: 0.2, count: targetCount) }

        // Average across channels into a single mono amplitude array.
        var monoSamples = [Float](repeating: 0, count: length)
        for ch in 0..<channelCount {
            let data = channelData[ch]
            for i in 0..<length {
                monoSamples[i] += abs(data[i])
            }
        }
        for i in 0..<length { monoSamples[i] /= Float(channelCount) }

        // Downsample into targetCount buckets by averaging chunks.
        let chunkSize = max(1, length / targetCount)
        var result: [Float] = []
        result.reserveCapacity(targetCount)

        var maxVal: Float = 0.0001
        for bucket in 0..<targetCount {
            let start = bucket * chunkSize
            let end = min(start + chunkSize, length)
            guard start < end else { result.append(0); continue }
            let slice = monoSamples[start..<end]
            let avg = slice.reduce(0, +) / Float(slice.count)
            result.append(avg)
            maxVal = max(maxVal, avg)
        }

        // Normalize to 0...1 and apply a small floor so silence isn't invisible.
        return result.map { min(1.0, max(0.08, $0 / maxVal)) }
    }
}
