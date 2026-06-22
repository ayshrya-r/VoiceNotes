import Foundation

/// Handles persistence of `Recording` metadata to disk as JSON.
/// The actual audio files live separately in the Documents directory;
/// this store only tracks the metadata describing them.
final class RecordingStore {

    static let shared = RecordingStore()

    private let indexFileName = "recordings_index.json"
    private let queue = DispatchQueue(label: "com.voicerecorder.store", attributes: .concurrent)

    private var indexURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(indexFileName)
    }

    private init() {}

    // MARK: - Public API

    func fetchAll() -> [Recording] {
        queue.sync {
            guard let data = try? Data(contentsOf: indexURL) else { return [] }
            let decoded = try? JSONDecoder().decode([Recording].self, from: data)
            return (decoded ?? []).sorted { $0.createdAt > $1.createdAt }
        }
    }

    func add(_ recording: Recording) {
        queue.sync(flags: .barrier) {
            var all = loadUnsafe()
            all.append(recording)
            saveUnsafe(all)
        }
    }

    func rename(id: UUID, newTitle: String) {
        queue.sync(flags: .barrier) {
            var all = loadUnsafe()
            guard let idx = all.firstIndex(where: { $0.id == id }) else { return }
            all[idx].title = newTitle
            saveUnsafe(all)
        }
    }

    func delete(id: UUID) {
        queue.sync(flags: .barrier) {
            var all = loadUnsafe()
            guard let idx = all.firstIndex(where: { $0.id == id }) else { return }
            let recording = all[idx]
            try? FileManager.default.removeItem(at: recording.fileURL)
            all.remove(at: idx)
            saveUnsafe(all)
        }
    }

    // MARK: - Private helpers (must be called within `queue`)

    private func loadUnsafe() -> [Recording] {
        guard let data = try? Data(contentsOf: indexURL) else { return [] }
        return (try? JSONDecoder().decode([Recording].self, from: data)) ?? []
    }

    private func saveUnsafe(_ recordings: [Recording]) {
        guard let data = try? JSONEncoder().encode(recordings) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }
}
