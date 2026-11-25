import Foundation
import TippyWander

/// The Wander as `wander.json` in Application Support, beside the journal:
/// written atomically and protected while the phone is locked. An
/// unreadable file is moved aside rather than overwritten.
final class FileWanderStore: WanderStore {
    let url: URL

    init(url: URL) {
        self.url = url
    }

    static func standard() -> FileWanderStore {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return FileWanderStore(url: base.appendingPathComponent("Tippy", isDirectory: true).appendingPathComponent("wander.json"))
    }

    func load() throws -> WanderState? {
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        let data = try Data(contentsOf: url)
        do {
            return try WanderCodec.decode(data)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let aside = url.deletingLastPathComponent().appendingPathComponent("wander-unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: aside)
            throw error
        }
    }

    func save(_ state: WanderState) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try WanderCodec.encode(state).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
