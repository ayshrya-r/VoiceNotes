import UIKit

final class RecordingsListViewController: UIViewController {

    // MARK: - UI

    private let waveformContainer = UIView()
    private let liveWaveformView = LiveWaveformView()
    private let timerLabel = UILabel()
    private let recordButton = RecordButton()
    private let hintLabel = UILabel()
    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private let emptyStateLabel = UILabel()

    private var waveformHeightConstraint: NSLayoutConstraint!

    // MARK: - State

    private let audioRecorder = AudioRecorderManager()
    private var recordings: [Recording] = []
    private var recordingStartTime: Date?
    private var displayTimer: Timer?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Voice Notes"
        view.backgroundColor = .systemGroupedBackground

        audioRecorder.delegate = self

        setupNavBar()
        setupRecordingArea()
        setupTableView()
        setupEmptyState()

        reloadRecordings()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        reloadRecordings()
    }

    // MARK: - Setup

    private func setupNavBar() {
        navigationController?.navigationBar.prefersLargeTitles = true
    }

    private func setupRecordingArea() {
        waveformContainer.backgroundColor = .secondarySystemGroupedBackground
        waveformContainer.layer.cornerRadius = 16
        waveformContainer.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(waveformContainer)

        liveWaveformView.translatesAutoresizingMaskIntoConstraints = false
        waveformContainer.addSubview(liveWaveformView)

        timerLabel.font = .monospacedDigitSystemFont(ofSize: 15, weight: .medium)
        timerLabel.textColor = .secondaryLabel
        timerLabel.text = "0:00"
        timerLabel.textAlignment = .center
        timerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(timerLabel)

        recordButton.translatesAutoresizingMaskIntoConstraints = false
        recordButton.addTarget(self, action: #selector(recordButtonTapped), for: .touchUpInside)
        view.addSubview(recordButton)

        hintLabel.font = .systemFont(ofSize: 13)
        hintLabel.textColor = .tertiaryLabel
        hintLabel.text = "Tap to record"
        hintLabel.textAlignment = .center
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hintLabel)

        waveformHeightConstraint = waveformContainer.heightAnchor.constraint(equalToConstant: 64)

        NSLayoutConstraint.activate([
            waveformContainer.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            waveformContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            waveformContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            waveformHeightConstraint,

            liveWaveformView.topAnchor.constraint(equalTo: waveformContainer.topAnchor, constant: 8),
            liveWaveformView.bottomAnchor.constraint(equalTo: waveformContainer.bottomAnchor, constant: -8),
            liveWaveformView.leadingAnchor.constraint(equalTo: waveformContainer.leadingAnchor, constant: 12),
            liveWaveformView.trailingAnchor.constraint(equalTo: waveformContainer.trailingAnchor, constant: -12),

            timerLabel.topAnchor.constraint(equalTo: waveformContainer.bottomAnchor, constant: 8),
            timerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            recordButton.topAnchor.constraint(equalTo: timerLabel.bottomAnchor, constant: 14),
            recordButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            recordButton.widthAnchor.constraint(equalToConstant: 72),
            recordButton.heightAnchor.constraint(equalToConstant: 72),

            hintLabel.topAnchor.constraint(equalTo: recordButton.bottomAnchor, constant: 8),
            hintLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
        ])
    }

    private func setupTableView() {
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.delegate = self
        tableView.dataSource = self
        tableView.register(RecordingCell.self, forCellReuseIdentifier: RecordingCell.reuseIdentifier)
        tableView.backgroundColor = .clear
        view.addSubview(tableView)

        NSLayoutConstraint.activate([
            tableView.topAnchor.constraint(equalTo: hintLabel.bottomAnchor, constant: 8),
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    private func setupEmptyState() {
        emptyStateLabel.text = "No recordings yet.\nTap the button above to start."
        emptyStateLabel.numberOfLines = 2
        emptyStateLabel.textAlignment = .center
        emptyStateLabel.textColor = .secondaryLabel
        emptyStateLabel.font = .systemFont(ofSize: 15)
        emptyStateLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(emptyStateLabel)

        NSLayoutConstraint.activate([
            emptyStateLabel.centerXAnchor.constraint(equalTo: tableView.centerXAnchor),
            emptyStateLabel.topAnchor.constraint(equalTo: tableView.topAnchor, constant: 60),
            emptyStateLabel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            emptyStateLabel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40),
        ])
    }

    // MARK: - Data

    private func reloadRecordings() {
        recordings = RecordingStore.shared.fetchAll()
        tableView.reloadData()
        emptyStateLabel.isHidden = !recordings.isEmpty
    }

    // MARK: - Recording flow

    @objc private func recordButtonTapped() {
        if audioRecorder.isRecording {
            stopRecording()
        } else {
            audioRecorder.requestPermission { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.startRecording()
                } else {
                    self.showMicPermissionAlert()
                }
            }
        }
    }

    private func startRecording() {
        liveWaveformView.reset()
        audioRecorder.startRecording()
        recordingStartTime = Date()

        recordButton.setRecording(true)
        hintLabel.text = "Tap to stop"
        animateWaveformExpansion(expanded: true)
        startDisplayTimer()

        // Keep new recordings from scrolling weirdly behind the active state.
        UIView.animate(withDuration: 0.25) {
            self.tableView.alpha = 0.4
        }
    }

    private func stopRecording() {
        audioRecorder.stopRecording()
        stopDisplayTimer()

        recordButton.setRecording(false)
        hintLabel.text = "Tap to record"
        animateWaveformExpansion(expanded: false)
        timerLabel.text = "0:00"
        liveWaveformView.reset()

        UIView.animate(withDuration: 0.25) {
            self.tableView.alpha = 1.0
        }
    }

    private func animateWaveformExpansion(expanded: Bool) {
        waveformHeightConstraint.constant = expanded ? 100 : 64
        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.85, initialSpringVelocity: 0.5, options: [.curveEaseInOut]) {
            self.view.layoutIfNeeded()
        }
    }

    private func startDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self, let start = self.recordingStartTime else { return }
            let elapsed = Int(Date().timeIntervalSince(start))
            self.timerLabel.text = String(format: "%d:%02d", elapsed / 60, elapsed % 60)
        }
    }

    private func stopDisplayTimer() {
        displayTimer?.invalidate()
        displayTimer = nil
    }

    private func showMicPermissionAlert() {
        let alert = UIAlertController(
            title: "Microphone Access Needed",
            message: "Please enable microphone access in Settings to record voice notes.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Open Settings", style: .default) { _ in
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }
        })
        present(alert, animated: true)
    }

    // MARK: - Saving

    private func saveRecording(at url: URL, duration: TimeInterval) {
        guard duration > 0.3 else {
            // Too short to be a meaningful recording — discard silently.
            try? FileManager.default.removeItem(at: url)
            return
        }
        let index = recordings.count + 1
        let recording = Recording(
            title: "Recording \(index)",
            fileName: url.lastPathComponent,
            duration: duration
        )
        RecordingStore.shared.add(recording)
        reloadRecordings()

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
    }
}

// MARK: - AudioRecorderManagerDelegate

extension RecordingsListViewController: AudioRecorderManagerDelegate {
    func audioRecorderManager(_ manager: AudioRecorderManager, didUpdatePower level: Float) {
        liveWaveformView.addSample(level)
    }

    func audioRecorderManager(_ manager: AudioRecorderManager, didFinishRecordingTo url: URL, duration: TimeInterval) {
        saveRecording(at: url, duration: duration)
    }

    func audioRecorderManager(_ manager: AudioRecorderManager, didFailWithError error: Error) {
        let alert = UIAlertController(title: "Recording Failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)
        recordButton.setRecording(false)
        hintLabel.text = "Tap to record"
        animateWaveformExpansion(expanded: false)
    }
}

// MARK: - UITableViewDataSource / Delegate

extension RecordingsListViewController: UITableViewDataSource, UITableViewDelegate {
    func numberOfSections(in tableView: UITableView) -> Int { 1 }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        recordings.count
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        recordings.isEmpty ? nil : "Recordings"
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: RecordingCell.reuseIdentifier, for: indexPath) as! RecordingCell
        cell.configure(with: recordings[indexPath.row])
        return cell
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        let recording = recordings[indexPath.row]
        let playerVC = PlaybackViewController(recording: recording)
        navigationController?.pushViewController(playerVC, animated: true)
    }

    func tableView(_ tableView: UITableView, trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath) -> UISwipeActionsConfiguration? {
        let recording = recordings[indexPath.row]

        let delete = UIContextualAction(style: .destructive, title: "Delete") { [weak self] _, _, completion in
            self?.confirmDelete(recording, at: indexPath)
            completion(true)
        }
        delete.image = UIImage(systemName: "trash")

        let rename = UIContextualAction(style: .normal, title: "Rename") { [weak self] _, _, completion in
            self?.promptRename(recording)
            completion(true)
        }
        rename.image = UIImage(systemName: "pencil")
        rename.backgroundColor = .systemBlue

        return UISwipeActionsConfiguration(actions: [delete, rename])
    }

    private func confirmDelete(_ recording: Recording, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: "Delete Recording?",
            message: "This action cannot be undone.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
            RecordingStore.shared.delete(id: recording.id)
            self?.reloadRecordings()
        })
        present(alert, animated: true)
    }

    private func promptRename(_ recording: Recording) {
        let alert = UIAlertController(title: "Rename Recording", message: nil, preferredStyle: .alert)
        alert.addTextField { textField in
            textField.text = recording.title
            textField.clearButtonMode = .whileEditing
        }
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        alert.addAction(UIAlertAction(title: "Save", style: .default) { [weak self] _ in
            guard let newName = alert.textFields?.first?.text, !newName.trimmingCharacters(in: .whitespaces).isEmpty else { return }
            RecordingStore.shared.rename(id: recording.id, newTitle: newName)
            self?.reloadRecordings()
        })
        present(alert, animated: true)
    }
}
