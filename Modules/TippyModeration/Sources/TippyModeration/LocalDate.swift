import Foundation

/// A calendar day with no time or time zone: the unit drinks and check-ins
/// are filed under. Converting from a `Date` takes the user's calendar
/// (where "today" is); day arithmetic itself is time-zone free.
public struct LocalDate: Hashable, Comparable, Sendable, CustomStringConvertible {
    public let year: Int
    public let month: Int
    public let day: Int

    /// Nil for a day that does not exist (February 30th).
    public init?(year: Int, month: Int, day: Int) {
        guard let date = LocalDate.utc.date(from: DateComponents(year: year, month: month, day: day)) else { return nil }
        let back = LocalDate.utc.dateComponents([.year, .month, .day], from: date)
        guard back.year == year, back.month == month, back.day == day else { return nil }
        self.year = year
        self.month = month
        self.day = day
    }

    /// The day `date` falls on in `calendar` (its time zone decides).
    public init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = parts.year ?? 1970
        self.month = parts.month ?? 1
        self.day = parts.day ?? 1
    }

    /// Parses `yyyy-MM-dd`.
    public init?(_ string: String) {
        let parts = string.split(separator: "-")
        guard parts.count == 3, let y = Int(parts[0]), let m = Int(parts[1]), let d = Int(parts[2]) else { return nil }
        self.init(year: y, month: m, day: d)
    }

    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    private var utcDate: Date {
        LocalDate.utc.date(from: DateComponents(year: year, month: month, day: day))!
    }

    public func adding(days: Int) -> LocalDate {
        LocalDate(LocalDate.utc.date(byAdding: .day, value: days, to: utcDate)!, calendar: LocalDate.utc)
    }

    /// Whole days from this day to `other` (negative when `other` is earlier).
    public func days(until other: LocalDate) -> Int {
        LocalDate.utc.dateComponents([.day], from: utcDate, to: other.utcDate).day ?? 0
    }

    /// 1 is Sunday ... 7 is Saturday, as `Calendar` numbers weekdays.
    public var weekday: Int { LocalDate.utc.component(.weekday, from: utcDate) }

    /// Midnight at the start of this day in `calendar`'s time zone.
    public func startDate(in calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? utcDate
    }

    public static func < (lhs: LocalDate, rhs: LocalDate) -> Bool {
        (lhs.year, lhs.month, lhs.day) < (rhs.year, rhs.month, rhs.day)
    }

    public var description: String { String(format: "%04d-%02d-%02d", year, month, day) }
}

extension LocalDate: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let text = try container.decode(String.self)
        guard let value = LocalDate(text) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Not a yyyy-MM-dd date: \(text)")
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(description)
    }
}

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
