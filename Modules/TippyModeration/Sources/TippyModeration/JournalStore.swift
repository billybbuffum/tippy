import Foundation

/// Port: where the journal is kept. The app supplies the adapter (a file in
/// Application Support on the phone, memory in UI tests).
public protocol JournalStore {
    /// Nil when nothing has been saved yet.
    func load() throws -> Journal?
    func save(_ journal: Journal) throws
}

/// The journal's file format, also used for backups: pretty-printed JSON
/// with ISO 8601 timestamps and `yyyy-MM-dd` days.
public enum JournalCodec {
    public static func encode(_ journal: Journal) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(journal)
    }

    public static func decode(_ data: Data) throws -> Journal {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(Journal.self, from: data)
    }
}

/// Which days get an evening reminder: every day in the horizon that is not
/// already logged, skipping today once its reminder time has passed.
public enum ReminderPlanner {
    public static func reminderDays(
        today: LocalDate,
        reminderPassedToday: Bool,
        horizon: Int = 28,
        isCheckedIn: (LocalDate) -> Bool
    ) -> [LocalDate] {
        var days: [LocalDate] = []
        for offset in 0..<max(horizon, 0) {
            if offset == 0 && reminderPassedToday { continue }
            let day = today.adding(days: offset)
            if !isCheckedIn(day) { days.append(day) }
        }
        return days
    }
}
