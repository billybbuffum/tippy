import Foundation
import TippyModeration
import TippyRewards
import TippyWander

/// Everything a backup holds. Rewards and the Wander are optional: a v1 backup
/// (a bare journal) has neither, and the app rebuilds them from the journal.
public struct BackupBundle: Equatable, Sendable {
    public var journal: Journal
    public var rewards: RewardsLedger?
    public var wander: WanderState?

    public init(journal: Journal, rewards: RewardsLedger? = nil, wander: WanderState? = nil) {
        self.journal = journal
        self.rewards = rewards
        self.wander = wander
    }
}

/// The backup file.
///
/// v2:
/// `{"format": "tippy-backup", "version": 2, "exportedAt": …, "app": {…}, "journal": {…}, "rewards": {…}, "wander": {…}}`
/// where each context's part is exactly what its own codec writes, so the
/// backup can never drift from what the app stores.
///
/// v1 (what Tippy exported before spec 04): a bare journal, recognised by the
/// missing `format` key.
public enum BackupFormat {
    public static let formatName = "tippy-backup"
    public static let currentVersion = 2

    public enum Problem: Error, Equatable, Sendable {
        /// Not JSON, or JSON that isn't a Tippy backup.
        case notABackup
        /// Written by a newer Tippy.
        case newerVersion(Int)
    }

    public static func encode(_ bundle: BackupBundle, exportedAt: Date, appVersion: String, build: String) throws -> Data {
        var root: [String: Any] = [
            "format": formatName,
            "version": currentVersion,
            "exportedAt": ISO8601DateFormatter().string(from: exportedAt),
            "app": ["version": appVersion, "build": build],
            "journal": try object(JournalCodec.encode(bundle.journal)),
        ]
        if let rewards = bundle.rewards { root["rewards"] = try object(RewardsCodec.encode(rewards)) }
        if let wander = bundle.wander { root["wander"] = try object(WanderCodec.encode(wander)) }
        return try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    public static func decode(_ data: Data) throws -> BackupBundle {
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Problem.notABackup
        }
        guard root["format"] != nil else {
            // v1: the whole file is a journal.
            do { return BackupBundle(journal: try JournalCodec.decode(data)) } catch let error as DecodingError {
                throw isNewerVersion(error) ? error : Problem.notABackup
            }
        }
        guard root["format"] as? String == formatName else { throw Problem.notABackup }
        let version = root["version"] as? Int ?? 0
        guard version <= currentVersion else { throw Problem.newerVersion(version) }
        guard let journal = root["journal"] else { throw Problem.notABackup }
        return BackupBundle(
            journal: try JournalCodec.decode(jsonData(journal)),
            rewards: try root["rewards"].map { try RewardsCodec.decode(jsonData($0)) },
            wander: try root["wander"].map { try WanderCodec.decode(jsonData($0)) }
        )
    }

    private static func object(_ data: Data) throws -> Any {
        try JSONSerialization.jsonObject(with: data)
    }

    private static func jsonData(_ object: Any) throws -> Data {
        try JSONSerialization.data(withJSONObject: object)
    }

    private static func isNewerVersion(_ error: DecodingError) -> Bool {
        if case .dataCorrupted(let context) = error { return context.debugDescription.contains("newer Tippy") }
        return false
    }
}

/// A side-by-side summary of this phone and a backup, shown before anything
/// changes, so she knows what a restore would replace.
public struct RestorePreview: Equatable, Sendable {
    public struct Side: Equatable, Sendable {
        public var daysLogged: Int
        public var drinks: Int
        public var reflections: Int
        public var coins: Int
        public var decorations: Int
        public var pets: Int
        public var firstDay: LocalDate?
        public var lastDay: LocalDate?

        public init(_ bundle: BackupBundle) {
            let days = bundle.journal.loggedDays
            daysLogged = days.count
            drinks = bundle.journal.entries.count
            reflections = bundle.journal.reflections.count
            coins = bundle.rewards?.balance ?? 0
            decorations = bundle.rewards?.owned.count ?? 0
            pets = bundle.wander?.pets.count ?? 0
            firstDay = days.min()
            lastDay = days.max()
        }
    }

    public var current: Side
    public var backup: Side

    public init(current: BackupBundle, backup: BackupBundle) {
        self.current = Side(current)
        self.backup = Side(backup)
    }
}
