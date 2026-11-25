import XCTest
@testable import TippyModeration

final class JournalTests: XCTestCase {
    let monday = LocalDate("2026-11-16")!
    let thursday = LocalDate("2026-11-19")!
    let noon = Date(timeIntervalSince1970: 1_763_553_600)

    func beer(on day: LocalDate, at offset: TimeInterval = 0) -> DrinkEntry {
        DrinkEntry(day: day, loggedAt: noon.addingTimeInterval(offset), kind: .beer, amount: 12, unit: .fluidOunce, abvPercent: 5)
    }

    // MARK: Drinks

    func testLoggingKeepsOrderAndUnmarksDrinkFree() throws {
        var journal = Journal()
        try journal.markDrinkFree(monday, today: thursday)
        try journal.log(beer(on: thursday), today: thursday)
        try journal.log(beer(on: monday), today: thursday)
        XCTAssertEqual(journal.entries.map(\.day), [monday, thursday])
        XCTAssertFalse(journal.isDrinkFree(monday))
        XCTAssertTrue(journal.isCheckedIn(monday))
    }

    func testCannotLogTheFutureOrAnImpossibleDrink() {
        var journal = Journal()
        XCTAssertThrowsError(try journal.log(beer(on: thursday.adding(days: 1)), today: thursday)) {
            XCTAssertEqual($0 as? Journal.Problem, .futureDay)
        }
        var impossible = beer(on: thursday)
        impossible.abvPercent = 120
        XCTAssertThrowsError(try journal.log(impossible, today: thursday)) {
            XCTAssertEqual($0 as? Journal.Problem, .invalidEntry)
        }
        XCTAssertThrowsError(try journal.markDrinkFree(thursday.adding(days: 1), today: thursday))
    }

    func testEnteredUnitsAndOverride() {
        var entry = DrinkEntry(day: thursday, loggedAt: noon, kind: .wine, amount: 148, unit: .milliliter, abvPercent: 12)
        XCTAssertEqual(entry.standardDrinks, 1.0, accuracy: 0.01)
        entry.standardDrinksOverride = 2
        XCTAssertEqual(entry.standardDrinks, 2)
        entry.standardDrinksOverride = -1
        XCTAssertFalse(entry.isValid)
    }

    func testUpdateEditsInPlaceAndCanMoveDays() throws {
        var journal = Journal()
        var entry = beer(on: thursday)
        try journal.log(entry, today: thursday)
        entry.kind = .wine
        entry.day = monday
        try journal.update(entry, today: thursday)
        XCTAssertEqual(journal.entries.count, 1)
        XCTAssertEqual(journal.entry(id: entry.id)?.kind, .wine)
        XCTAssertFalse(journal.isCheckedIn(thursday))
        XCTAssertTrue(journal.hasDrinks(on: monday))
        XCTAssertThrowsError(try journal.update(beer(on: monday), today: thursday)) {
            XCTAssertEqual($0 as? Journal.Problem, .unknownEntry)
        }
    }

    func testRemovingTheLastDrinkAsksWhatTheDayBecomes() throws {
        var journal = Journal()
        let first = beer(on: thursday)
        let second = beer(on: thursday, at: 60)
        try journal.log(first, today: thursday)
        try journal.log(second, today: thursday)
        XCTAssertFalse(journal.isOnlyEntryOnItsDay(first.id))
        try journal.removeEntry(id: first.id, ifDayEmpties: .clear)
        XCTAssertTrue(journal.hasDrinks(on: thursday))
        XCTAssertTrue(journal.isOnlyEntryOnItsDay(second.id))
        try journal.removeEntry(id: second.id, ifDayEmpties: .markDrinkFree)
        XCTAssertTrue(journal.isDrinkFree(thursday))

        var other = Journal()
        let only = beer(on: monday)
        try other.log(only, today: thursday)
        try other.removeEntry(id: only.id, ifDayEmpties: .clear)
        XCTAssertFalse(other.isCheckedIn(monday))
    }

    func testDayWithDrinksCannotBeDrinkFree() throws {
        var journal = Journal()
        try journal.log(beer(on: thursday), today: thursday)
        XCTAssertThrowsError(try journal.markDrinkFree(thursday, today: thursday)) {
            XCTAssertEqual($0 as? Journal.Problem, .dayHasDrinks)
        }
    }

    func testClearDayRemovesEverything() throws {
        var journal = Journal()
        try journal.log(beer(on: thursday), today: thursday)
        try journal.reflect(on: thursday, prompt: ReflectionPrompts.afterDrinks[0], answer: "The first one", at: noon, today: thursday)
        journal.clearDay(thursday)
        XCTAssertFalse(journal.isCheckedIn(thursday))
        XCTAssertNil(journal.reflection(on: thursday))
    }

    // MARK: Reflections

    func testReflectionsBelongToLoggedDays() throws {
        var journal = Journal()
        let prompt = ReflectionPrompts.afterDrinkFree[0]
        XCTAssertThrowsError(try journal.reflect(on: thursday, prompt: prompt, answer: "A walk", at: noon, today: thursday)) {
            XCTAssertEqual($0 as? Journal.Problem, .dayNotLogged)
        }
        try journal.markDrinkFree(thursday, today: thursday)
        XCTAssertThrowsError(try journal.reflect(on: thursday, prompt: prompt, answer: "   ", at: noon, today: thursday)) {
            XCTAssertEqual($0 as? Journal.Problem, .emptyAnswer)
        }
        try journal.reflect(on: thursday, prompt: prompt, answer: "  A walk ", at: noon, today: thursday)
        XCTAssertEqual(journal.reflection(on: thursday)?.answer, "A walk")
        XCTAssertEqual(journal.reflection(on: thursday)?.promptID, prompt.id)
    }

    func testPromptsVaryByDayButAreStable() {
        let a = ReflectionPrompts.prompt(for: monday, hadDrinks: true)
        XCTAssertEqual(a, ReflectionPrompts.prompt(for: monday, hadDrinks: true))
        XCTAssertNotEqual(a, ReflectionPrompts.prompt(for: monday.adding(days: 1), hadDrinks: true))
        XCTAssertTrue(ReflectionPrompts.afterDrinkFree.contains(ReflectionPrompts.prompt(for: monday, hadDrinks: false)))
        XCTAssertEqual(ReflectionPrompts.prompt(id: a.id), a)
        let ids = (ReflectionPrompts.afterDrinks + ReflectionPrompts.afterDrinkFree).map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "prompt IDs must be unique")
    }

    // MARK: Goals

    func testGoalChangesApplyFromAWeekOnwards() {
        var journal = Journal()
        let thisWeek = journal.week(containing: thursday)
        XCTAssertEqual(journal.goal(for: thisWeek), Journal.defaultWeeklyGoal)
        journal.setWeeklyGoal(12, from: thisWeek.previous)
        journal.setWeeklyGoal(10, from: thisWeek)
        XCTAssertEqual(journal.goal(for: thisWeek.previous), 12)
        XCTAssertEqual(journal.goal(for: thisWeek.previous.previous), 12, "weeks before the first change use the first goal")
        XCTAssertEqual(journal.goal(for: thisWeek), 10)
        XCTAssertEqual(journal.goal(for: thisWeek.next), 10)
        journal.setWeeklyGoal(8, from: thisWeek)
        XCTAssertEqual(journal.goalHistory.count, 2, "a second change in the same week replaces the first")
        journal.setWeeklyGoal(999, from: thisWeek)
        XCTAssertEqual(journal.goal(for: thisWeek), Journal.goalRange.upperBound)
    }

    // MARK: Summaries

    func testWeekSummary() throws {
        var journal = Journal()
        let week = journal.week(containing: thursday)
        journal.setWeeklyGoal(14, from: week)
        for offset in 0..<3 { try journal.log(beer(on: monday, at: Double(offset)), today: thursday) }
        try journal.log(beer(on: monday.adding(days: -1)), today: thursday) // previous week
        try journal.markDrinkFree(monday.adding(days: 1), today: thursday)
        let summary = journal.summary(of: week, today: thursday)
        XCTAssertEqual(summary.week.start, monday)
        XCTAssertEqual(summary.standardDrinks, 3, accuracy: 0.01)
        XCTAssertEqual(summary.weeklyGoal, 14)
        XCTAssertEqual(summary.drinkFreeDays, 1)
        XCTAssertEqual(summary.checkedInDays, 2)
        XCTAssertEqual(summary.daysElapsed, 4)
        XCTAssertEqual(summary.remaining, 11, accuracy: 0.01)
        XCTAssertTrue(summary.metGoal)
        XCTAssertFalse(summary.isOver)
        XCTAssertEqual(journal.summary(of: week.previous, today: thursday).daysElapsed, 7)
    }

    // MARK: Persistence

    func testCodecRoundTrip() throws {
        var journal = Journal()
        journal.settings.petName = "Pip"
        journal.settings.costPerDrink = 7.5
        journal.setWeeklyGoal(10, from: journal.week(containing: thursday))
        var entry = beer(on: monday)
        entry.standardDrinksOverride = 1.5
        try journal.log(entry, today: thursday)
        try journal.markDrinkFree(thursday, today: thursday)
        try journal.reflect(on: thursday, prompt: ReflectionPrompts.afterDrinkFree[1], answer: "Quiet", at: noon, today: thursday)
        let data = try JournalCodec.encode(journal)
        XCTAssertEqual(try JournalCodec.decode(data), journal)
    }

    func testDecodesAnOlderFileWithMissingFields() throws {
        let json = #"{"settings": {"petName": "Pip"}, "drinkFreeDays": ["2026-11-16"]}"#
        let journal = try JournalCodec.decode(Data(json.utf8))
        XCTAssertEqual(journal.settings.petName, "Pip")
        XCTAssertNil(journal.settings.costPerDrink)
        XCTAssertFalse(journal.settings.reminderOffered)
        XCTAssertTrue(journal.isDrinkFree(monday))
        XCTAssertTrue(journal.entries.isEmpty)
        XCTAssertEqual(journal.goal(for: journal.week(containing: monday)), Journal.defaultWeeklyGoal)
    }

    func testLoadingRepairsBrokenInvariants() {
        let entry = beer(on: monday)
        let stray = Reflection(day: thursday, promptID: "what-helped", answer: "x", answeredAt: noon)
        let journal = Journal(entries: [entry], drinkFreeDays: [monday], reflections: [stray])
        XCTAssertFalse(journal.isDrinkFree(monday), "a day with drinks is not drink-free")
        XCTAssertNil(journal.reflection(on: thursday), "a reflection needs a logged day")
    }

    func testRefusesAFileFromANewerVersion() {
        XCTAssertThrowsError(try JournalCodec.decode(Data(#"{"version": 99}"#.utf8)))
    }

    func testReminderDaysSkipLoggedDaysAndAPassedToday() {
        let logged: Set<LocalDate> = [thursday.adding(days: 1)]
        let days = ReminderPlanner.reminderDays(today: thursday, reminderPassedToday: true, horizon: 4) { logged.contains($0) }
        XCTAssertEqual(days, [thursday.adding(days: 2), thursday.adding(days: 3)])
        let fresh = ReminderPlanner.reminderDays(today: thursday, reminderPassedToday: false, horizon: 2) { _ in false }
        XCTAssertEqual(fresh, [thursday, thursday.adding(days: 1)])
    }
}
