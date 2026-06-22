import UIKit

/// Renders a smooth, scrolling bar-style waveform driven by incoming power levels,
/// similar to Loom's live recording indicator. New samples push in from the right;
/// older bars scroll left and fade.
final class LiveWaveformView: UIView {

    // MARK: - Config

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 3
    private let minBarHeight: CGFloat = 4
    private let maxSamples = 100

    private var samples: [Float] = []

    var barColor: UIColor = .systemRed {
        didSet { setNeedsDisplay() }
    }

    override class var layerClass: AnyClass { CAShapeLayer.self }

    private var shapeLayer: CAShapeLayer {
        layer as! CAShapeLayer
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
        shapeLayer.fillColor = nil
        backgroundColor = .clear
        isUserInteractionEnabled = false
    }

    /// Call this with a new normalized (0...1) power level each tick.
    func addSample(_ level: Float) {
        samples.append(level)
        if samples.count > maxSamples {
            samples.removeFirst(samples.count - maxSamples)
        }
        redraw()
    }

    func reset() {
        samples.removeAll()
        redraw()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        redraw()
    }

    private func redraw() {
        let path = UIBezierPath()
        let midY = bounds.height / 2
        let totalStep = barWidth + barSpacing
        let maxBarHeight = bounds.height - 4

        // Draw from right edge backwards so newest sample is rightmost,
        // matching the "scrolling in" feel of Loom's recorder.
        var x = bounds.width - barWidth
        var index = samples.count - 1

        while x > -barWidth && index >= 0 {
            let level = CGFloat(samples[index])
            let height = max(minBarHeight, level * maxBarHeight)
            let rect = CGRect(x: x, y: midY - height / 2, width: barWidth, height: height)
            let barPath = UIBezierPath(roundedRect: rect, cornerRadius: barWidth / 2)
            path.append(barPath)

            x -= totalStep
            index -= 1
        }

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = barColor.cgColor
        CATransaction.commit()
    }
}
