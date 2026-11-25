import XCTest
import TippyModeration
@testable import TippyRewards

final class AwardPolicyTests: XCTestCase {
    /// Thursday; weeks start on Monday 16 November, last week is 9–15 November.
    let today = LocalDate("2026-11-19")!
    let noon = Date(timeIntervalSince1970: 1_763_553_600)

    var thisWeek: Week { Week(containing: today, firstWeekday: 2) }
    var lastWeek: Week { thisWeek.previous }

    func drinks(_ count: Double, on day: LocalDate) -> DrinkEntry {
        DrinkEntry(day: day, loggedAt: noon, kind: .beer, amount: 12, unit: .fluidOunce, abvPercent: 5,
                   standardDrinksOverride: count)
    }

    func keys(_ awards: [Award]) -> Set<String> { Set(awards.map(\.key.rawValue)) }

    // MARK: Days

    func testAmounts() {
        let yesterday = today.adding(days: -1)
        let journal = Journal(entries: [drinks(1, on: today)], drinkFreeDays: [yesterday])
        let awards = AwardPolicy.eligibleAwards(journal: journal, today: today)
        XCTAssertEqual(keys(awards), ["checkIn:2026-11-19", "checkIn:2026-11-18", "drinkFree:2026-11-18"])
        XCTAssertEqual(awards.first { $0.key == .checkIn(today) }?.coins, 5)
        XCTAssertEqual(awards.first { $0.key == .drinkFree(yesterday) }?.coins, 3)
        XCTAssertEqual(awards.first { $0.key == .drinkFree(yesterday) }?.earnedOn, yesterday)
        XCTAssertEqual(awards.reduce(0) { $0 + $1.coins }, 13)
    }

    func testBackfillWindowEdges() {
        let sevenAgo = today.adding(days: -7)
        let eightAgo = today.adding(days: -8)
        let journal = Journal(drinkFreeDays: [sevenAgo, eightAgo])
        let awards = keys(AwardPolicy.eligibleAwards(journal: journal, today: today))
        XCTAssertTrue(awards.contains("checkIn:2026-11-12"), "7 days back still earns")
        XCTAssertTrue(awards.contains("drinkFree:2026-11-12"))
        XCTAssertFalse(awards.contains("checkIn:2026-11-11"), "8 days back is outside the window")
        XCTAssertFalse(awards.contains("drinkFree:2026-11-11"))
    }

    func testAwardsAreNeverRevoked() throws {
        let day = today.adding(days: -2)
        var journal = Journal(drinkFreeDays: [day])
        var ledger = RewardsLedger()
        for award in AwardPolicy.eligibleAwards(journal: journal, today: today) { ledger.record(award) }
        XCTAssertEqual(ledger.balance, 8)

        // The drink-free day becomes a drink day: the bonus stays.
        try journal.log(drinks(2, on: day), today: today)
        let recorded = AwardPolicy.eligibleAwards(journal: journal, today: today).filter { ledger.record($0) }
        XCTAssertTrue(recorded.isEmpty)
        XCTAssertEqual(ledger.balance, 8)
        XCTAssertTrue(ledger.hasAward(.drinkFree(day)))

        // Clearing the day takes nothing back either.
        journal.clearDay(day)
        for award in AwardPolicy.eligibleAwards(journal: journal, today: today) { ledger.record(award) }
        XCTAssertEqual(ledger.balance, 8)
    }

    // MARK: Week goal

    func testGoalBonusNeedsFiveLoggedDays() {
        let four = Journal(drinkFreeDays: Set(lastWeek.days.prefix(4)))
        XCTAssertFalse(keys(AwardPolicy.eligibleAwards(journal: four, today: today)).contains("weekGoal:2026-11-09"))

        let five = Journal(drinkFreeDays: Set(lastWeek.days.prefix(5)))
        let bonus = AwardPolicy.eligibleAwards(journal: five, today: today).first { $0.key == .weekGoal(lastWeek) }
        XCTAssertEqual(bonus?.coins, 15)
        XCTAssertEqual(bonus?.earnedOn, lastWeek.end)
        XCTAssertEqual(AwardKey.weekGoal(lastWeek).rawValue, "weekGoal:2026-11-09")
    }

    func testGoalBonusUsesThatWeeksOwnGoal() {
        let earlier = lastWeek.previous
        // 12 drinks against 14 the week before last; 10 against 7 last week.
        let entries = earlier.days.prefix(5).map { drinks(2.4, on: $0) } + lastWeek.days.prefix(5).map { drinks(2, on: $0) }
        let goals = [
            Journal.GoalChange(weekStart: earlier.start, goal: 14),
            Journal.GoalChange(weekStart: lastWeek.start, goal: 7),
        ]
        let journal = Journal(entries: entries, goalHistory: goals)
        let awards = keys(AwardPolicy.eligibleAwards(journal: journal, today: today))
        XCTAssertTrue(awards.contains("weekGoal:\(earlier.start)"), "within the 14 that week had, though over today's 7")
        XCTAssertFalse(awards.contains("weekGoal:\(lastWeek.start)"), "over the 7 that week had, though under 14")
    }

    func testGoalBonusOnlyForTheLastFourFinishedWeeks() {
        var weeks: [Week] = []
        var week = thisWeek
        for _ in 0..<5 {
            week = week.previous
            weeks.append(week)
        }
        let fourBack = weeks[3]
        let fiveBack = weeks[4]
        let journal = Journal(drinkFreeDays: Set(fourBack.days + fiveBack.days + thisWeek.days.prefix(4)))
        let awards = keys(AwardPolicy.eligibleAwards(journal: journal, today: today))
        XCTAssertTrue(awards.contains("weekGoal:\(fourBack.start)"))
        XCTAssertFalse(awards.contains("weekGoal:\(fiveBack.start)"))
        XCTAssertFalse(awards.contains("weekGoal:\(thisWeek.start)"), "the current week isn't finished")
    }

    func testSyncingTwiceChangesNothing() {
        let journal = Journal(entries: [drinks(1, on: today)], drinkFreeDays: Set(lastWeek.days))
        var ledger = RewardsLedger()
        let first = AwardPolicy.eligibleAwards(journal: journal, today: today).filter { ledger.record($0) }
        let balance = ledger.balance
        let second = AwardPolicy.eligibleAwards(journal: journal, today: today).filter { ledger.record($0) }
        XCTAssertFalse(first.isEmpty)
        XCTAssertTrue(second.isEmpty)
        XCTAssertEqual(ledger.balance, balance)
    }
}
