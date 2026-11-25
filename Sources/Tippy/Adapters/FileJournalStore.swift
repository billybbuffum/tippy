import Foundation
import TippyModeration

/// The journal as one JSON file in Application Support, written atomically
/// and protected while the phone is locked. An unreadable file is moved
/// aside rather than overwritten, so nothing is lost silently.
final class FileJournalStore: JournalStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    static func standard() -> FileJournalStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FileJournalStore(url: base.appendingPathComponent("Tippy", isDirectory: true).appendingPathComponent("journal.json"))
    }

    func load() throws -> Journal? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        do {
            return try JournalCodec.decode(data)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let aside = url.deletingLastPathComponent().appendingPathComponent("journal-unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: aside)
            throw error
        }
    }

    func save(_ journal: Journal) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JournalCodec.encode(journal).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
