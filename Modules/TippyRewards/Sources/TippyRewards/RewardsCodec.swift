import Foundation

/// The rewards file format, also used for backups (spec 04): pretty-printed JSON
/// with ISO 8601 timestamps and `yyyy-MM-dd` days, like `JournalCodec`.
public enum RewardsCodec {
    public static func encode(_ ledger: RewardsLedger) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(ledger)
    }

    public static func decode(_ data: Data) throws -> RewardsLedger {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(RewardsLedger.self, from: data)
    }
}
