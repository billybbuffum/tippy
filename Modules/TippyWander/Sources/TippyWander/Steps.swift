import Foundation
import TippyModeration

/// The fact a step was earned for, and the step ledger's key:
/// `checkIn:2026-11-19` or `reflection:2026-11-19` (specs README, contract 3).
public struct StepKey: Hashable, Comparable, Sendable, CustomStringConvertible {
    public enum Kind: String, Sendable, CaseIterable {
        case checkIn
        case reflection
    }

    public let kind: Kind
    public let day: LocalDate

    public init(_ kind: Kind, _ day: LocalDate) {
        self.kind = kind
        self.day = day
    }

    /// Parses `<kind>:yyyy-MM-dd`; nil for anything else.
    public init?(_ string: String) {
        let parts = string.split(separator: ":", maxSplits: 1).map(String.init)
        guard parts.count == 2, let kind = Kind(rawValue: parts[0]), let day = LocalDate(parts[1]) else { return nil }
        self.init(kind, day)
    }

    public var description: String { "\(kind.rawValue):\(day)" }

    /// Chronological, a day's check-in before its reflection.
    public static func < (lhs: StepKey, rhs: StepKey) -> Bool {
        if lhs.day != rhs.day { return lhs.day < rhs.day }
        let order = Kind.allCases
        return (order.firstIndex(of: lhs.kind) ?? 0) < (order.firstIndex(of: rhs.kind) ?? 0)
    }
}

extension StepKey: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let key = StepKey(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a step key: \(text)")
        }
        self = key
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

/// One step on the Wander, recorded once and never taken back.
public struct StepAward: Hashable, Codable, Sendable {
    public let key: StepKey
    /// The day the sync that recorded it ran.
    public let awardedOn: LocalDate

    public init(key: StepKey, awardedOn: LocalDate) {
        self.key = key
        self.awardedOn = awardedOn
    }
}

/// Which steps a journal has earned. A domain service: pure, no clock.
public enum StepPolicy {
    /// A day earns only within this many days of today, so remembering a
    /// missed day counts but old history can't be farmed.
    public static let backFillDays = 7

    /// One `checkIn:<d>` per logged day and one `reflection:<d>` per
    /// reflected day, for days from `today - 7` to `today`, in order.
    public static func eligibleSteps(journal: Journal, today: LocalDate) -> [StepKey] {
        var keys: [StepKey] = []
        for offset in stride(from: -backFillDays, through: 0, by: 1) {
            let day = today.adding(days: offset)
            if journal.isCheckedIn(day) { keys.append(StepKey(.checkIn, day)) }
            if journal.reflection(on: day) != nil { keys.append(StepKey(.reflection, day)) }
        }
        return keys
    }
}
