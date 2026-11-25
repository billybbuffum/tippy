import XCTest
@testable import TippyModeration

final class LocalDateTests: XCTestCase {
    func day(_ text: String) -> LocalDate { LocalDate(text)! }

    func testRejectsImpossibleDays() {
        XCTAssertNil(LocalDate(year: 2026, month: 2, day: 30))
        XCTAssertNil(LocalDate("2026-13-01"))
        XCTAssertNil(LocalDate("yesterday"))
        XCTAssertNotNil(LocalDate(year: 2028, month: 2, day: 29))
    }

    func testArithmeticAcrossMonthsAndYears() {
        XCTAssertEqual(day("2026-12-31").adding(days: 1), day("2027-01-01"))
        XCTAssertEqual(day("2026-03-01").adding(days: -1), day("2026-02-28"))
        XCTAssertEqual(day("2026-11-16").days(until: day("2026-11-19")), 3)
        XCTAssertEqual(day("2026-11-19").days(until: day("2026-11-16")), -3)
    }

    func testWeekdayAndOrdering() {
        XCTAssertEqual(day("2026-11-16").weekday, 2) // a Monday
        XCTAssertTrue(day("2026-11-16") < day("2026-11-17"))
        XCTAssertTrue(day("2025-12-31") < day("2026-01-01"))
    }

    func testFromDateUsesTheCalendarsTimeZone() {
        // 2026-11-19 03:00 UTC is still the 18th in Los Angeles.
        let instant = ISO8601DateFormatter().date(from: "2026-11-19T03:00:00Z")!
        var la = Calendar(identifier: .gregorian)
        la.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        XCTAssertEqual(LocalDate(instant, calendar: la), day("2026-11-18"))
    }

    func testCodableAsString() throws {
        let data = try JSONEncoder().encode([day("2026-01-05")])
        XCTAssertEqual(String(data: data, encoding: .utf8), "[\"2026-01-05\"]")
        XCTAssertEqual(try JSONDecoder().decode([LocalDate].self, from: data), [day("2026-01-05")])
    }

    func testWeekContainingStartsOnTheFirstWeekday() {
        let thursday = day("2026-11-19")
        XCTAssertEqual(Week(containing: thursday, firstWeekday: 2).start, day("2026-11-16")) // Monday
        XCTAssertEqual(Week(containing: thursday, firstWeekday: 1).start, day("2026-11-15")) // Sunday
        XCTAssertEqual(Week(containing: day("2026-11-16"), firstWeekday: 2).start, day("2026-11-16"))
        XCTAssertEqual(Week(containing: day("2026-11-22"), firstWeekday: 2).start, day("2026-11-16")) // Sunday, Monday-start
        let week = Week(start: day("2026-11-16"))
        XCTAssertEqual(week.days.count, 7)
        XCTAssertEqual(week.end, day("2026-11-22"))
        XCTAssertTrue(week.contains(day("2026-11-22")))
        XCTAssertFalse(week.contains(day("2026-11-23")))
    }
}
