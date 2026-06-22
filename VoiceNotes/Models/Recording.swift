import Foundation

/// Represents a single saved voice recording.
/// Persisted as a JSON-encoded array via `RecordingStore`.
struct Recording: Codable, Equatable, Identifiable {
    let id: UUID
    var title: String
    let fileName: String      // file stored in Documents directory
    let createdAt: Date
    let duration: TimeInterval

    init(id: UUID = UUID(), title: String, fileName: String, createdAt: Date = Date(), duration: TimeInterval) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.createdAt = createdAt
        self.duration = duration
    }

    /// Full URL to the audio file on disk.
    var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(fileName)
    }

    var formattedDuration: String {
        let totalSeconds = Int(duration.rounded())
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        if Calendar.current.isDateInToday(createdAt) {
            formatter.dateFormat = "'Today,' h:mm a"
        } else if Calendar.current.isDateInYesterday(createdAt) {
            formatter.dateFormat = "'Yesterday,' h:mm a"
        } else {
            formatter.dateFormat = "MMM d, h:mm a"
        }
        return formatter.string(from: createdAt)
    }
}
