import XCTest
@testable import TippyModeration

final class JournalTests: XCTestCase {
    let monday = LocalDate("2026-11-16")!
    let thursday = LocalDate("2026-11-19")!
    let noon = Date(timeIntervalSince1970: 1_763_553_600)

    func beer(on day: LocalDate, at offset: TimeInterval = 0) -> DrinkEntry {
        DrinkEntry(day: day, loggedAt: noon.addingTimeInterval(offset), kind: .beer, serving: .beer)
    }

    func testLoggingKeepsOrderAndUnmarksDrinkFree() throws {
        var journal = Journal()
        try journal.markDrinkFree(monday, today: thursday)
        try journal.log(beer(on: thursday), today: thursday)
        try journal.log(beer(on: monday), today: thursday)
        XCTAssertEqual(journal.entries.map(\.day), [monday, thursday])
        XCTAssertFalse(journal.isDrinkFree(monday))
        XCTAssertTrue(journal.isCheckedIn(monday))
    }

    func testCannotLogTheFuture() {
        var journal = Journal()
        XCTAssertThrowsError(try journal.log(beer(on: thursday.adding(days: 1)), today: thursday)) {
            XCTAssertEqual($0 as? Journal.Problem, .futureDay)
        }
        XCTAssertThrowsError(try journal.markDrinkFree(thursday.adding(days: 1), today: thursday))
    }

    func testDayWithDrinksCannotBeDrinkFree() throws {
        var journal = Journal()
        try journal.log(beer(on: thursday), today: thursday)
        XCTAssertThrowsError(try journal.markDrinkFree(thursday, today: thursday)) {
            XCTAssertEqual($0 as? Journal.Problem, .dayHasDrinks)
        }
    }

    func testRemoveEntry() throws {
        var journal = Journal()
        let entry = beer(on: thursday)
        try journal.log(entry, today: thursday)
        XCTAssertEqual(journal.removeEntry(id: entry.id), entry)
        XCTAssertNil(journal.removeEntry(id: entry.id))
        XCTAssertFalse(journal.isCheckedIn(thursday))
    }

    func testWeekSummary() throws {
        var journal = Journal()
        journal.settings.weeklyGoal = 14
        for offset in 0..<3 { try journal.log(beer(on: monday, at: Double(offset)), today: thursday) }
        try journal.log(beer(on: monday.adding(days: -1)), today: thursday) // previous week
        try journal.markDrinkFree(monday.adding(days: 1), today: thursday)
        let summary = journal.summary(of: journal.week(containing: thursday), today: thursday)
        XCTAssertEqual(summary.week.start, monday)
        XCTAssertEqual(summary.standardDrinks, 3, accuracy: 0.01)
        XCTAssertEqual(summary.drinkFreeDays, 1)
        XCTAssertEqual(summary.checkedInDays, 2)
        XCTAssertEqual(summary.daysElapsed, 4)
        XCTAssertEqual(summary.remaining, 11, accuracy: 0.01)
        XCTAssertTrue(summary.metGoal)
        XCTAssertFalse(summary.isOver)
        XCTAssertEqual(journal.summary(of: summary.week.previous, today: thursday).daysElapsed, 7)
    }

    func testStreakToleratesAnOpenToday() throws {
        var journal = Journal()
        try journal.markDrinkFree(monday, today: thursday)
        try journal.log(beer(on: monday.adding(days: 1)), today: thursday)
        try journal.markDrinkFree(monday.adding(days: 2), today: thursday)
        XCTAssertEqual(journal.streak(today: thursday), 3) // Mon-Wed; Thursday still open
        try journal.markDrinkFree(thursday, today: thursday)
        XCTAssertEqual(journal.streak(today: thursday), 4)
        XCTAssertEqual(journal.streak(today: thursday.adding(days: 2)), 0) // Friday missed
    }

    func testCodecRoundTrip() throws {
        var journal = Journal()
        journal.settings.petName = "Pip"
        try journal.log(beer(on: monday), today: thursday)
        try journal.markDrinkFree(thursday, today: thursday)
        let data = try JournalCodec.encode(journal)
        XCTAssertEqual(try JournalCodec.decode(data), journal)
    }

    func testDecodesAnOlderFileWithMissingFields() throws {
        let json = #"{"settings": {"petName": "Pip"}, "drinkFreeDays": ["2026-11-16"]}"#
        let journal = try JournalCodec.decode(Data(json.utf8))
        XCTAssertEqual(journal.settings.petName, "Pip")
        XCTAssertEqual(journal.settings.weeklyGoal, 14)
        XCTAssertTrue(journal.isDrinkFree(monday))
        XCTAssertTrue(journal.entries.isEmpty)
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
