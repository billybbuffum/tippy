import XCTest
import TippyModeration
@testable import TippyRewards

final class RewardsLedgerTests: XCTestCase {
    let thursday = LocalDate("2026-11-19")!
    let seenAt = Date(timeIntervalSince1970: 1_763_553_600)

    var week: Week { Week(containing: thursday, firstWeekday: 2) }

    func award(_ key: AwardKey, _ coins: Int, on day: LocalDate? = nil) -> Award {
        Award(key: key, coins: coins, earnedOn: day ?? thursday)!
    }

    // MARK: Invariants

    func testAnAwardIsWorthSomething() {
        XCTAssertNil(Award(key: .checkIn(thursday), coins: 0, earnedOn: thursday))
        XCTAssertNil(Award(key: .checkIn(thursday), coins: -5, earnedOn: thursday))
    }

    func testRecordIsIdempotent() {
        var ledger = RewardsLedger()
        XCTAssertTrue(ledger.record(award(.checkIn(thursday), 5)))
        XCTAssertFalse(ledger.record(award(.checkIn(thursday), 50)), "a key that exists is a no-op")
        XCTAssertEqual(ledger.balance, 5)
        XCTAssertEqual(ledger.award(for: .checkIn(thursday))?.coins, 5)
        XCTAssertTrue(ledger.record(award(.pouch("reeds-pouch-1"), 12)))
        XCTAssertEqual(ledger.earned, 17)
        XCTAssertEqual(ledger.spent, 0)
        XCTAssertEqual(ledger.balance, 17)
    }

    func testCoinsEarnedInAWeek() {
        var ledger = RewardsLedger()
        ledger.record(award(.checkIn(week.start), 5, on: week.start))
        ledger.record(award(.weekGoal(week), 15, on: week.end))
        ledger.record(award(.checkIn(week.previous.end), 5, on: week.previous.end))
        XCTAssertEqual(ledger.coinsEarned(in: week), 20)
        XCTAssertEqual(ledger.coinsEarned(in: week.previous), 5)
    }

    func testOneRecapPerWeek() {
        var ledger = RewardsLedger()
        XCTAssertFalse(ledger.hasSeenRecap(for: week))
        ledger.markRecapSeen(week, at: seenAt, nextWeekIdea: "  Tea after dinner \n")
        XCTAssertTrue(ledger.hasSeenRecap(for: week))
        XCTAssertEqual(ledger.recap(for: week)?.nextWeekIdea, "Tea after dinner")

        ledger.markRecapSeen(week, at: seenAt.addingTimeInterval(3600), nextWeekIdea: "A walk")
        XCTAssertEqual(ledger.recaps.count, 1)
        XCTAssertEqual(ledger.recap(for: week)?.seenAt, seenAt, "seeing it again only updates the idea")
        XCTAssertEqual(ledger.recap(for: week)?.nextWeekIdea, "A walk")

        ledger.markRecapSeen(week, at: seenAt, nextWeekIdea: "   ")
        XCTAssertNil(ledger.recap(for: week)?.nextWeekIdea, "a blank idea is no idea")
    }

    // MARK: Codec

    func testCodecRoundTrip() throws {
        var ledger = RewardsLedger()
        ledger.record(award(.checkIn(thursday), 5))
        ledger.record(award(.drinkFree(thursday), 3))
        ledger.record(award(.weekGoal(week.previous), 15, on: week.previous.end))
        ledger.markRecapSeen(week.previous, at: seenAt, nextWeekIdea: "Sparkling water first")
        let data = try RewardsCodec.encode(ledger)
        XCTAssertEqual(try RewardsCodec.decode(data), ledger)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"checkIn:2026-11-19\""), text)
        XCTAssertTrue(text.contains("\"version\" : 1"), text)
    }

    func testDecodesAnOldShape() throws {
        let old = #"{"awards":[{"key":"checkIn:2026-11-19","coins":5,"earnedOn":"2026-11-19"}]}"#
        let ledger = try RewardsCodec.decode(Data(old.utf8))
        XCTAssertEqual(ledger.balance, 5)
        XCTAssertTrue(ledger.recaps.isEmpty)

        let empty = try RewardsCodec.decode(Data("{}".utf8))
        XCTAssertEqual(empty, RewardsLedger())

        let recapWithoutIdea = #"{"version":1,"recaps":[{"weekStart":"2026-11-09","seenAt":"2026-11-19T18:00:00Z"}]}"#
        let seen = try RewardsCodec.decode(Data(recapWithoutIdea.utf8))
        XCTAssertTrue(seen.hasSeenRecap(for: week.previous))
        XCTAssertNil(seen.recap(for: week.previous)?.nextWeekIdea)
    }

    func testRefusesANewerVersion() {
        let newer = #"{"version":2,"awards":[]}"#
        XCTAssertThrowsError(try RewardsCodec.decode(Data(newer.utf8)))
    }

    func testRefusesAWorthlessAward() {
        let bad = #"{"version":1,"awards":[{"key":"checkIn:2026-11-19","coins":0,"earnedOn":"2026-11-19"}]}"#
        XCTAssertThrowsError(try RewardsCodec.decode(Data(bad.utf8)))
    }
}
