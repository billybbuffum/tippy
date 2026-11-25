import XCTest
import TippyModeration
@testable import TippyRewards

final class RecapPolicyTests: XCTestCase {
    let today = LocalDate("2026-11-19")!
    let seenAt = Date(timeIntervalSince1970: 1_763_553_600)

    var lastWeek: Week { Week(containing: today, firstWeekday: 2).previous }

    func testLastWeekWithACheckInIsRecapped() {
        let journal = Journal(drinkFreeDays: [lastWeek.start.adding(days: 2)])
        XCTAssertEqual(RecapPolicy.weekToRecap(journal: journal, ledger: RewardsLedger(), today: today), lastWeek)
    }

    func testNeedsACheckIn() {
        let journal = Journal(drinkFreeDays: [today])
        XCTAssertNil(RecapPolicy.weekToRecap(journal: journal, ledger: RewardsLedger(), today: today))
    }

    func testNotOnceSeen() {
        let journal = Journal(drinkFreeDays: [lastWeek.start])
        var ledger = RewardsLedger()
        ledger.markRecapSeen(lastWeek, at: seenAt, nextWeekIdea: nil)
        XCTAssertNil(RecapPolicy.weekToRecap(journal: journal, ledger: ledger, today: today))
    }

    func testNoQueueOfOlderWeeks() throws {
        // Three weeks away: the week of 9 November had check-ins, the weeks since none.
        let later = today.adding(days: 21)
        let journal = Journal(drinkFreeDays: Set(lastWeek.days))
        XCTAssertNil(RecapPolicy.weekToRecap(journal: journal, ledger: RewardsLedger(), today: later))

        // One check-in in the week just before `later` brings that week's recap only.
        let laterLastWeek = Week(containing: later, firstWeekday: 2).previous
        var back = journal
        try back.markDrinkFree(laterLastWeek.end, today: later)
        XCTAssertEqual(RecapPolicy.weekToRecap(journal: back, ledger: RewardsLedger(), today: later), laterLastWeek)
    }
}
