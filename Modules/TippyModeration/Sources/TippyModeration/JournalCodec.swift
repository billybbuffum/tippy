import Foundation

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
