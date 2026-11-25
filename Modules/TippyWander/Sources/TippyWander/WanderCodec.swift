import Foundation

/// The Wander's file format (`wander.json`), also what a backup holds:
/// pretty-printed JSON with `yyyy-MM-dd` days, versioned by `WanderState`.
public enum WanderCodec {
    public static func encode(_ state: WanderState) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(state)
    }

    public static func decode(_ data: Data) throws -> WanderState {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(WanderState.self, from: data)
    }
}
