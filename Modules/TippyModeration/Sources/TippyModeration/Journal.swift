import Foundation

/// The aggregate: everything the user has logged, and their settings. All
/// changes go through its methods, which keep the invariants:
/// - a day is either drink-free or has drinks, never both;
/// - nothing is logged on a day that has not happened yet;
/// - entries stay in chronological order.
public struct Journal: Hashable, Sendable {
    public static let currentVersion = 1

    public enum Problem: Error, Equatable, Sendable {
        case futureDay
        case dayHasDrinks
    }

    public var settings: ModerationSettings
    public private(set) var entries: [DrinkEntry]
    public private(set) var drinkFreeDays: Set<LocalDate>

    public init(settings: ModerationSettings = ModerationSettings(), entries: [DrinkEntry] = [], drinkFreeDays: Set<LocalDate> = []) {
        self.settings = settings
        self.entries = entries.sorted(by: Journal.chronological)
        let drinkDays = Set(entries.map(\.day))
        self.drinkFreeDays = drinkFreeDays.subtracting(drinkDays)
    }

    static func chronological(_ a: DrinkEntry, _ b: DrinkEntry) -> Bool {
        a.day != b.day ? a.day < b.day : a.loggedAt < b.loggedAt
    }

    // MARK: Commands

    /// Adds a drink. Logging a drink on a drink-free day un-marks it.
    public mutating func log(_ entry: DrinkEntry, today: LocalDate) throws {
        guard entry.day <= today else { throw Problem.futureDay }
        entries.append(entry)
        entries.sort(by: Journal.chronological)
        drinkFreeDays.remove(entry.day)
    }

    @discardableResult
    public mutating func removeEntry(id: UUID) -> DrinkEntry? {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { return nil }
        return entries.remove(at: index)
    }

    public mutating func markDrinkFree(_ day: LocalDate, today: LocalDate) throws {
        guard day <= today else { throw Problem.futureDay }
        guard !hasDrinks(on: day) else { throw Problem.dayHasDrinks }
        drinkFreeDays.insert(day)
    }

    public mutating func clearDrinkFree(_ day: LocalDate) {
        drinkFreeDays.remove(day)
    }

    // MARK: Queries

    public func entries(on day: LocalDate) -> [DrinkEntry] { entries.filter { $0.day == day } }
    public func hasDrinks(on day: LocalDate) -> Bool { entries.contains { $0.day == day } }
    public func isDrinkFree(_ day: LocalDate) -> Bool { drinkFreeDays.contains(day) }
    public func isCheckedIn(_ day: LocalDate) -> Bool { isDrinkFree(day) || hasDrinks(on: day) }

    public func standardDrinks(on day: LocalDate) -> Double {
        entries(on: day).reduce(0.0) { $0 + $1.standardDrinks }
    }

    /// Every day with a drink or marked drink-free, newest first.
    public var loggedDays: [LocalDate] {
        Set(entries.map(\.day)).union(drinkFreeDays).sorted(by: >)
    }

    public func week(containing day: LocalDate) -> Week {
        Week(containing: day, firstWeekday: settings.firstWeekday)
    }

    public func summary(of week: Week, today: LocalDate) -> WeekSummary {
        let inWeek = entries.filter { week.contains($0.day) }
        let freeInWeek = drinkFreeDays.filter { week.contains($0) }
        let elapsed: Int
        if today < week.start {
            elapsed = 0
        } else if today > week.end {
            elapsed = 7
        } else {
            elapsed = week.start.days(until: today) + 1
        }
        return WeekSummary(
            week: week,
            standardDrinks: inWeek.reduce(0.0) { $0 + $1.standardDrinks },
            weeklyGoal: settings.weeklyGoal,
            drinkFreeDays: freeInWeek.count,
            checkedInDays: Set(inWeek.map(\.day)).union(freeInWeek).count,
            daysElapsed: elapsed
        )
    }

    /// Consecutive checked-in days up to today, or up to yesterday while
    /// today is still open (an unlogged today does not break the streak).
    public func streak(today: LocalDate) -> Int {
        let checkedIn = Set(entries.map(\.day)).union(drinkFreeDays)
        var day = checkedIn.contains(today) ? today : today.adding(days: -1)
        var count = 0
        while checkedIn.contains(day) {
            count += 1
            day = day.adding(days: -1)
        }
        return count
    }
}

extension Journal: Codable {
    enum CodingKeys: String, CodingKey {
        case version, settings, entries, drinkFreeDays
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard version <= Journal.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: c,
                debugDescription: "Saved by a newer Tippy (format \(version)); update the app first."
            )
        }
        let settings = try c.decodeIfPresent(ModerationSettings.self, forKey: .settings) ?? ModerationSettings()
        let entries = try c.decodeIfPresent([DrinkEntry].self, forKey: .entries) ?? []
        let free = try c.decodeIfPresent([LocalDate].self, forKey: .drinkFreeDays) ?? []
        self.init(settings: settings, entries: entries, drinkFreeDays: Set(free))
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Journal.currentVersion, forKey: .version)
        try c.encode(settings, forKey: .settings)
        try c.encode(entries, forKey: .entries)
        try c.encode(drinkFreeDays.sorted(), forKey: .drinkFreeDays)
    }
}

/// How one week is going (or went).
public struct WeekSummary: Equatable, Sendable {
    public let week: Week
    public let standardDrinks: Double
    public let weeklyGoal: Double
    public let drinkFreeDays: Int
    public let checkedInDays: Int
    /// Days of the week up to and including today: 0 before it starts, 7 once it is over.
    public let daysElapsed: Int

    public var remaining: Double { max(weeklyGoal - standardDrinks, 0) }
    public var isOver: Bool { daysElapsed >= 7 }
    public var metGoal: Bool { standardDrinks <= weeklyGoal + 0.0001 }

    /// 0...1 share of the weekly goal used, for a progress ring.
    public var progress: Double {
        guard weeklyGoal > 0 else { return standardDrinks > 0 ? 1 : 0 }
        return min(standardDrinks / weeklyGoal, 1)
    }

    public var pace: Double {
        MoodPolicy.pace(drinksSoFar: standardDrinks, weeklyGoal: weeklyGoal, daysElapsed: daysElapsed)
    }
}
