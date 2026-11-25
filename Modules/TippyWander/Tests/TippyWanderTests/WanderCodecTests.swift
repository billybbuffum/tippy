import XCTest
import TippyModeration
@testable import TippyWander

final class WanderCodecTests: XCTestCase {
    let today = LocalDate("2026-11-19")!

    func testRoundTrip() throws {
        var state = WanderState.starting(petName: "Pip")
        var settings = ModerationSettings()
        settings.petName = "Pip"
        let days = Set((-7...0).map { today.adding(days: $0) })
        let answers = (-1...0).map {
            Reflection(day: today.adding(days: $0), promptID: "what-helped", answer: "Tea", answeredAt: Date(timeIntervalSince1970: 0))
        }
        state.sync(journal: Journal(settings: settings, drinkFreeDays: days, reflections: answers), today: today).ignore()
        state.markVisitorSeen("fox-at-dusk")
        XCTAssertFalse(state.eggs.isEmpty)
        XCTAssertNotNil(state.pendingHatch)

        let data = try WanderCodec.encode(state)
        let decoded = try WanderCodec.decode(data)
        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.position, 10)
        let text = String(decoding: data, as: UTF8.self)
        XCTAssertTrue(text.contains("\"checkIn:2026-11-19\""), text)
        XCTAssertTrue(text.contains("\"version\" : 1"), text)
    }

    func testDecodesAnOldShapeWithMissingFields() throws {
        // No version, eggs, active pet, visitors or pending hatch; an egg
        // without a name.
        let json = """
        {
          "steps": [
            { "key": "checkIn:2026-11-18", "awardedOn": "2026-11-18" },
            { "key": "reflection:2026-11-18", "awardedOn": "2026-11-18" }
          ],
          "found": {},
          "pets": [
            { "id": "starter", "speciesID": "pondling", "name": "Sprout", "hatchedOn": "2026-11-11" }
          ]
        }
        """
        let state = try WanderCodec.decode(Data(json.utf8))
        XCTAssertEqual(state.position, 2)
        XCTAssertEqual(state.checkInCount, 1)
        XCTAssertEqual(state.activePetID, "starter")
        XCTAssertEqual(state.eggs, [])
        XCTAssertEqual(state.seenVisitors, [])
        XCTAssertNil(state.pendingHatch)

        let egg = try JSONDecoder().decode(Egg.self, from: Data(#"{ "id": "starter", "speciesID": "pondling" }"#.utf8))
        XCTAssertNil(egg.name)
        XCTAssertNil(egg.nestedAtCheckIn)
    }

    func testRefusesANewerVersion() {
        let json = #"{ "version": 2, "steps": [] }"#
        XCTAssertThrowsError(try WanderCodec.decode(Data(json.utf8)))
    }

    func testRefusesABadStepKey() {
        let json = #"{ "version": 1, "steps": [{ "key": "walk:2026-11-18", "awardedOn": "2026-11-18" }] }"#
        XCTAssertThrowsError(try WanderCodec.decode(Data(json.utf8)))
    }
}
