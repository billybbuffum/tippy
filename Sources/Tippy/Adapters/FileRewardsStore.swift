import Foundation
import TippyRewards

/// The rewards ledger as one JSON file (`rewards.json`) next to the journal in
/// Application Support, written atomically and protected while the phone is
/// locked. An unreadable file is moved aside rather than overwritten, exactly
/// like `FileJournalStore`.
final class FileRewardsStore: RewardsStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    static func standard() -> FileRewardsStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FileRewardsStore(url: base.appendingPathComponent("Tippy", isDirectory: true).appendingPathComponent("rewards.json"))
    }

    func load() throws -> RewardsLedger? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        do {
            return try RewardsCodec.decode(data)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let aside = url.deletingLastPathComponent().appendingPathComponent("rewards-unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: aside)
            throw error
        }
    }

    func save(_ ledger: RewardsLedger) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try RewardsCodec.encode(ledger).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
