import UIKit

/// A circular record button that morphs between a "record" (circle) and
/// "stop" (rounded square) icon, with a pulsing ring while recording.
final class RecordButton: UIControl {

    private let outerRing = CAShapeLayer()
    private let innerShape = CAShapeLayer()
    private let pulseLayer = CAShapeLayer()

    private(set) var isRecordingState = false

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

        outerRing.fillColor = UIColor.white.cgColor
        outerRing.shadowColor = UIColor.black.cgColor
        outerRing.shadowOpacity = 0.15
        outerRing.shadowRadius = 8
        outerRing.shadowOffset = CGSize(width: 0, height: 2)
        layer.addSublayer(outerRing)

        pulseLayer.fillColor = UIColor.systemRed.withAlphaComponent(0.25).cgColor
        pulseLayer.opacity = 0
        layer.addSublayer(pulseLayer)

        innerShape.fillColor = UIColor.systemRed.cgColor
        layer.addSublayer(innerShape)

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUp), for: [.touchUpInside, .touchUpOutside, .touchCancel])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let outerRect = bounds
        outerRing.path = UIBezierPath(ovalIn: outerRect).cgPath
        outerRing.frame = bounds

        pulseLayer.path = UIBezierPath(ovalIn: outerRect).cgPath
        pulseLayer.frame = bounds

        updateInnerShape(animated: false)
    }

    @objc private func touchDown() {
        UIView.animate(withDuration: 0.12) { self.transform = CGAffineTransform(scaleX: 0.92, y: 0.92) }
    }

    @objc private func touchUp() {
        UIView.animate(withDuration: 0.12) { self.transform = .identity }
    }

    /// Switches the button between idle (record) and active (stop) appearance.
    func setRecording(_ recording: Bool, animated: Bool = true) {
        isRecordingState = recording
        updateInnerShape(animated: animated)
        recording ? startPulse() : stopPulse()

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
    }

    private func updateInnerShape(animated: Bool) {
        let inset: CGFloat = isRecordingState ? bounds.width * 0.30 : bounds.width * 0.18
        let cornerRadius: CGFloat = isRecordingState ? 6 : (bounds.width - inset * 2) / 2
        let rect = bounds.insetBy(dx: inset, dy: inset)
        let newPath = UIBezierPath(roundedRect: rect, cornerRadius: cornerRadius).cgPath

        if animated {
            let anim = CABasicAnimation(keyPath: "path")
            anim.fromValue = innerShape.path
            anim.toValue = newPath
            anim.duration = 0.25
            anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            innerShape.add(anim, forKey: "morph")
        }
        innerShape.path = newPath
    }

    private func startPulse() {
        pulseLayer.opacity = 1
        let scale = CABasicAnimation(keyPath: "transform.scale")
        scale.fromValue = 1.0
        scale.toValue = 1.35
        scale.duration = 1.0
        scale.repeatCount = .infinity
        scale.autoreverses = false
        scale.timingFunction = CAMediaTimingFunction(name: .easeOut)

        let opacity = CABasicAnimation(keyPath: "opacity")
        opacity.fromValue = 0.6
        opacity.toValue = 0.0
        opacity.duration = 1.0
        opacity.repeatCount = .infinity

        pulseLayer.add(scale, forKey: "pulseScale")
        pulseLayer.add(opacity, forKey: "pulseOpacity")
    }

    private func stopPulse() {
        pulseLayer.removeAllAnimations()
        pulseLayer.opacity = 0
    }
}
