import Foundation

/// The Moderation aggregate: everything the user has logged, the weekly
/// goal as it stood each week, her reflections, and her settings. All
/// changes go through its methods, which keep the invariants:
/// - a day is drink-free, has drinks, or is not logged; never two at once;
/// - nothing is logged on a day that has not happened yet;
/// - every entry is a real serving; entries stay in chronological order;
/// - a reflection belongs to a logged day;
/// - a week's goal never changes after the week, only from a week onwards.
public struct Journal: Hashable, Sendable {
    public static let currentVersion = 1
    public static let defaultWeeklyGoal = 14.0
    public static let goalRange = 0.0...200.0

    public enum Problem: Error, Equatable, Sendable {
        case futureDay
        case dayHasDrinks
        case invalidEntry
        case unknownEntry
        case dayNotLogged
        case emptyAnswer
    }

    /// What happens to a day when its last drink is removed: she decides.
    public enum EmptyDayChoice: Sendable {
        case markDrinkFree
        case clear
    }

    /// The goal set from a given week onwards.
    public struct GoalChange: Hashable, Codable, Sendable {
        public let weekStart: LocalDate
        public let goal: Double

        public init(weekStart: LocalDate, goal: Double) {
            self.weekStart = weekStart
            self.goal = goal
        }
    }

    public var settings: ModerationSettings
    public private(set) var entries: [DrinkEntry]
    public private(set) var drinkFreeDays: Set<LocalDate>
    public private(set) var reflections: [LocalDate: Reflection]
    public private(set) var goalHistory: [GoalChange]

    public init(
        settings: ModerationSettings = ModerationSettings(),
        entries: [DrinkEntry] = [],
        drinkFreeDays: Set<LocalDate> = [],
        reflections: [Reflection] = [],
        goalHistory: [GoalChange] = []
    ) {
        self.settings = settings
        self.entries = entries.filter(\.isValid).sorted(by: Journal.chronological)
        let drinkDays = Set(self.entries.map(\.day))
        self.drinkFreeDays = drinkFreeDays.subtracting(drinkDays)
        let logged = drinkDays.union(self.drinkFreeDays)
        self.reflections = Dictionary(
            reflections.filter { logged.contains($0.day) }.map { ($0.day, $0) },
            uniquingKeysWith: { _, latest in latest }
        )
        self.goalHistory = goalHistory.sorted { $0.weekStart < $1.weekStart }
    }

    static func chronological(_ a: DrinkEntry, _ b: DrinkEntry) -> Bool {
        a.day != b.day ? a.day < b.day : a.loggedAt < b.loggedAt
    }

    // MARK: Drinks

    /// Adds a drink. Logging a drink on a drink-free day un-marks it.
    public mutating func log(_ entry: DrinkEntry, today: LocalDate) throws {
        guard entry.day <= today else { throw Problem.futureDay }
        guard entry.isValid else { throw Problem.invalidEntry }
        entries.append(entry)
        entries.sort(by: Journal.chronological)
        drinkFreeDays.remove(entry.day)
    }

    /// Replaces an entry (same ID) with an edited version. Moving it to
    /// another day leaves the old day as it is now; if that empties it, the
    /// day becomes unlogged, as if cleared.
    public mutating func update(_ entry: DrinkEntry, today: LocalDate) throws {
        guard let index = entries.firstIndex(where: { $0.id == entry.id }) else { throw Problem.unknownEntry }
        guard entry.day <= today else { throw Problem.futureDay }
        guard entry.isValid else { throw Problem.invalidEntry }
        let oldDay = entries[index].day
        entries[index] = entry
        entries.sort(by: Journal.chronological)
        drinkFreeDays.remove(entry.day)
        if !hasDrinks(on: oldDay) { reflections[oldDay] = nil }
    }

    /// Whether removing this entry would leave its day without drinks, so the
    /// app must ask what she wants the day to be.
    public func isOnlyEntryOnItsDay(_ id: UUID) -> Bool {
        guard let entry = entries.first(where: { $0.id == id }) else { return false }
        return entries.filter { $0.day == entry.day }.count == 1
    }

    /// Removes a drink. If it was the day's last, `ifDayEmpties` decides
    /// whether the day becomes drink-free or unlogged.
    @discardableResult
    public mutating func removeEntry(id: UUID, ifDayEmpties choice: EmptyDayChoice) throws -> DrinkEntry {
        guard let index = entries.firstIndex(where: { $0.id == id }) else { throw Problem.unknownEntry }
        let removed = entries.remove(at: index)
        if !hasDrinks(on: removed.day) {
            switch choice {
            case .markDrinkFree: drinkFreeDays.insert(removed.day)
            case .clear: reflections[removed.day] = nil
            }
        }
        return removed
    }

    // MARK: Days

    public mutating func markDrinkFree(_ day: LocalDate, today: LocalDate) throws {
        guard day <= today else { throw Problem.futureDay }
        guard !hasDrinks(on: day) else { throw Problem.dayHasDrinks }
        drinkFreeDays.insert(day)
    }

    /// Un-logs a day completely: its drinks, drink-free mark and reflection.
    public mutating func clearDay(_ day: LocalDate) {
        entries.removeAll { $0.day == day }
        drinkFreeDays.remove(day)
        reflections[day] = nil
    }

    // MARK: Reflections

    public mutating func reflect(on day: LocalDate, prompt: ReflectionPrompt, answer: String, at instant: Date, today: LocalDate) throws {
        guard day <= today else { throw Problem.futureDay }
        guard isCheckedIn(day) else { throw Problem.dayNotLogged }
        let text = answer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw Problem.emptyAnswer }
        reflections[day] = Reflection(day: day, promptID: prompt.id, answer: text, answeredAt: instant)
    }

    public func reflection(on day: LocalDate) -> Reflection? { reflections[day] }

    // MARK: Goals

    /// Sets the weekly goal from `week` onwards. Earlier weeks keep theirs.
    public mutating func setWeeklyGoal(_ goal: Double, from week: Week) {
        let clamped = min(max(goal, Journal.goalRange.lowerBound), Journal.goalRange.upperBound)
        goalHistory.removeAll { $0.weekStart >= week.start }
        goalHistory.append(GoalChange(weekStart: week.start, goal: clamped))
        goalHistory.sort { $0.weekStart < $1.weekStart }
    }

    /// The goal that applied to `week`: the latest change at or before it.
    /// Weeks before the first change use the first goal ever set.
    public func goal(for week: Week) -> Double {
        if let change = goalHistory.last(where: { $0.weekStart <= week.start }) { return change.goal }
        return goalHistory.first?.goal ?? Journal.defaultWeeklyGoal
    }

    // MARK: Queries

    public func entries(on day: LocalDate) -> [DrinkEntry] { entries.filter { $0.day == day } }
    public func entry(id: UUID) -> DrinkEntry? { entries.first { $0.id == id } }
    public func hasDrinks(on day: LocalDate) -> Bool { entries.contains { $0.day == day } }
    public func isDrinkFree(_ day: LocalDate) -> Bool { drinkFreeDays.contains(day) }
    public func isCheckedIn(_ day: LocalDate) -> Bool { isDrinkFree(day) || hasDrinks(on: day) }

    public func standardDrinks(on day: LocalDate) -> Double {
        entries(on: day).reduce(0.0) { $0 + $1.standardDrinks }
    }

    /// Every logged day, newest first.
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
            weeklyGoal: goal(for: week),
            drinkFreeDays: freeInWeek.count,
            checkedInDays: Set(inWeek.map(\.day)).union(freeInWeek).count,
            daysElapsed: elapsed
        )
    }
}

extension Journal: Codable {
    enum CodingKeys: String, CodingKey {
        case version, settings, entries, drinkFreeDays, reflections, goalHistory
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
        let reflections = try c.decodeIfPresent([Reflection].self, forKey: .reflections) ?? []
        let goals = try c.decodeIfPresent([GoalChange].self, forKey: .goalHistory) ?? []
        self.init(settings: settings, entries: entries, drinkFreeDays: Set(free), reflections: reflections, goalHistory: goals)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(Journal.currentVersion, forKey: .version)
        try c.encode(settings, forKey: .settings)
        try c.encode(entries, forKey: .entries)
        try c.encode(drinkFreeDays.sorted(), forKey: .drinkFreeDays)
        try c.encode(reflections.values.sorted { $0.day < $1.day }, forKey: .reflections)
        try c.encode(goalHistory, forKey: .goalHistory)
    }
}
