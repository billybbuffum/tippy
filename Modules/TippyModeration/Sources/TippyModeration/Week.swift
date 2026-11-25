import Foundation

/// Seven consecutive days starting on the user's first weekday.
public struct Week: Hashable, Sendable, Codable {
    public let start: LocalDate

    public init(start: LocalDate) {
        self.start = start
    }

    /// The week holding `day`, for weeks that begin on `firstWeekday`
    /// (1 Sunday ... 7 Saturday; 2 is Monday).
    public init(containing day: LocalDate, firstWeekday: Int) {
        let offset = ((day.weekday - firstWeekday) % 7 + 7) % 7
        self.start = day.adding(days: -offset)
    }

    public var end: LocalDate { start.adding(days: 6) }
    public var days: [LocalDate] { (0..<7).map { start.adding(days: $0) } }
    public var previous: Week { Week(start: start.adding(days: -7)) }
    public var next: Week { Week(start: start.adding(days: 7)) }

    public func contains(_ day: LocalDate) -> Bool { day >= start && day <= end }
}
