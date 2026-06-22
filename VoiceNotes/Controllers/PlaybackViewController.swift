import UIKit

final class PlaybackViewController: UIViewController {

    private let recording: Recording
    private let player = AudioPlayerManager()

    private let titleLabel = UILabel()
    private let dateLabel = UILabel()
    private let waveformView = PlaybackWaveformView()
    private let currentTimeLabel = UILabel()
    private let durationLabel = UILabel()
    private let playButton = UIButton(type: .system)
    private var isScrubbing = false

    init(recording: Recording) {
        self.recording = recording
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemGroupedBackground
        title = "Playback"

        player.delegate = self
        player.load(url: recording.fileURL)

        setupNavBar()
        setupUI()
        waveformView.loadWaveform(from: recording.fileURL)
        durationLabel.text = recording.formattedDuration
    }

    deinit {
        player.stop()
    }

    // MARK: - Setup

    private func setupNavBar() {
        let menu = UIMenu(children: [
            UIAction(title: "Rename", image: UIImage(systemName: "pencil")) { [weak self] _ in
                self?.promptRename()
            },
            UIAction(title: "Delete", image: UIImage(systemName: "trash"), attributes: .destructive) { [weak self] _ in
                self?.confirmDelete()
            }
        ])
        navigationItem.rightBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "ellipsis.circle"), menu: menu)
    }

    private func setupUI() {
        titleLabel.text = recording.title
        titleLabel.font = .systemFont(ofSize: 22, weight: .bold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false

        dateLabel.text = recording.formattedDate
        dateLabel.font = .systemFont(ofSize: 14)
        dateLabel.textColor = .secondaryLabel
        dateLabel.textAlignment = .center
        dateLabel.translatesAutoresizingMaskIntoConstraints = false

        waveformView.translatesAutoresizingMaskIntoConstraints = false
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(waveformTapped(_:)))
        waveformView.addGestureRecognizer(tapGesture)
        waveformView.isUserInteractionEnabled = true

        let panGesture = UIPanGestureRecognizer(target: self, action: #selector(waveformPanned(_:)))
        waveformView.addGestureRecognizer(panGesture)

        currentTimeLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        currentTimeLabel.textColor = .secondaryLabel
        currentTimeLabel.text = "0:00"
        currentTimeLabel.translatesAutoresizingMaskIntoConstraints = false

        durationLabel.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        durationLabel.textColor = .secondaryLabel
        durationLabel.translatesAutoresizingMaskIntoConstraints = false

        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = .systemRed
        config.baseForegroundColor = .white
        config.image = UIImage(systemName: "play.fill")
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 18, leading: 18, bottom: 18, trailing: 18)
        playButton.configuration = config
        playButton.translatesAutoresizingMaskIntoConstraints = false
        playButton.addTarget(self, action: #selector(playTapped), for: .touchUpInside)

        [titleLabel, dateLabel, waveformView, currentTimeLabel, durationLabel, playButton].forEach { view.addSubview($0) }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 40),
            titleLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            titleLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            dateLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 6),
            dateLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            waveformView.topAnchor.constraint(equalTo: dateLabel.bottomAnchor, constant: 50),
            waveformView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            waveformView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            waveformView.heightAnchor.constraint(equalToConstant: 80),

            currentTimeLabel.topAnchor.constraint(equalTo: waveformView.bottomAnchor, constant: 8),
            currentTimeLabel.leadingAnchor.constraint(equalTo: waveformView.leadingAnchor),

            durationLabel.topAnchor.constraint(equalTo: waveformView.bottomAnchor, constant: 8),
            durationLabel.trailingAnchor.constraint(equalTo: waveformView.trailingAnchor),

            playButton.topAnchor.constraint(equalTo: currentTimeLabel.bottomAnchor, constant: 50),
            playButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            playButton.widthAnchor.constraint(equalToConstant: 76),
            playButton.heightAnchor.constraint(equalToConstant: 76),
        ])
    }

    // MARK: - Actions

    @objc private func playTapped() {
        player.togglePlayPause()
        updatePlayButtonIcon()
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    @objc private func waveformTapped(_ gesture: UITapGestureRecognizer) {
        let location = gesture.location(in: waveformView)
        let progress = location.x / waveformView.bounds.width
        seek(to: progress)
    }

    @objc private func waveformPanned(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: waveformView)
        let progress = max(0, min(1, location.x / waveformView.bounds.width))

        switch gesture.state {
        case .began:
            isScrubbing = true
        case .changed:
            waveformView.progress = progress
            currentTimeLabel.text = formatTime(progress * player.duration)
        case .ended, .cancelled:
            isScrubbing = false
            seek(to: progress)
        default:
            break
        }
    }

    private func seek(to progress: Double) {
        player.seek(to: progress)
        waveformView.progress = progress
        currentTimeLabel.text = formatTime(progress * player.duration)
    }

    private func updatePlayButtonIcon() {
        let imageName = player.isPlaying ? "pause.fill" : "play.fill"
        playButton.configuration?.image = UIImage(systemName: imageName)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        guard time.isFinite, !time.isNaN else { return "0:00" }
        let total = Int(time)
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    // MARK: - Rename / Delete

    private func promptRename() {
        let alert = UIAlertController(title: "Rename Recording", message: nil, preferredStyle: .alert)
        alert.addTextField { $0.text = self.recording.title }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let self, let newName = alert.textFields?.first?.text,
                  !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            RecordingStore.shared.rename(id: self.recording.id, newTitle: newName)
            self.titleLabel.text = newName
        })
        present(alert, animated: true)
    }

    private func confirmDelete() {
        let alert = UIAlertController(title: "Delete Recording?", message: "This action cannot be undone.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            guard let self else { return }
            RecordingStore.shared.delete(id: self.recording.id)
            self.navigationController?.popViewController(animated: true)
        })
        present(alert, animated: true)
    }
}

// MARK: - AudioPlayerManagerDelegate

extension PlaybackViewController: AudioPlayerManagerDelegate {
    func audioPlayerManager(_ manager: AudioPlayerManager, didUpdateProgress progress: Double, currentTime: TimeInterval) {
        guard !isScrubbing else { return }
        waveformView.progress = CGFloat(progress)
        currentTimeLabel.text = formatTime(currentTime)
    }

    func audioPlayerManagerDidFinishPlaying(_ manager: AudioPlayerManager) {
        updatePlayButtonIcon()
        waveformView.progress = 0
        currentTimeLabel.text = "0:00"
    }
}
