import Foundation
import TippyModeration

/// The fact an award was earned for, as `"<kind>:<id>"` with days in `yyyy-MM-dd`:
/// `checkIn:2026-11-19`, `drinkFree:2026-11-19`, `weekGoal:2026-11-16` (the week's
/// start), `pouch:<landmark>`, `find:<landmark>`. The ledger keeps one award per key,
/// so the same fact can never pay twice. Saved files hold the raw value: never change
/// the format of an existing kind.
public struct AwardKey: Hashable, Comparable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    /// A logged day (drinks or drink-free).
    public static func checkIn(_ day: LocalDate) -> AwardKey { AwardKey(rawValue: "checkIn:\(day)") }
    /// A drink-free day's bonus.
    public static func drinkFree(_ day: LocalDate) -> AwardKey { AwardKey(rawValue: "drinkFree:\(day)") }
    /// A finished week within its goal, keyed by the week's start.
    public static func weekGoal(_ week: Week) -> AwardKey { AwardKey(rawValue: "weekGoal:\(week.start)") }
    /// A coin pouch found on the Wander (granted by the app's coordinator).
    public static func pouch(_ landmarkID: String) -> AwardKey { AwardKey(rawValue: "pouch:\(landmarkID)") }
    /// A decoration found on the Wander (spec 02 records these as grants).
    public static func find(_ landmarkID: String) -> AwardKey { AwardKey(rawValue: "find:\(landmarkID)") }

    public var description: String { rawValue }

    public static func < (lhs: AwardKey, rhs: AwardKey) -> Bool { lhs.rawValue < rhs.rawValue }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        rawValue = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
