import XCTest
import TippyModeration
import TippyRewards
import TippyWander
@testable import TippyBackup

final class BackupFormatTests: XCTestCase {
    let monday = LocalDate("2026-11-16")!
    let thursday = LocalDate("2026-11-19")!
    let noon = Date(timeIntervalSince1970: 1_763_553_600)

    func sampleBundle() throws -> BackupBundle {
        var journal = Journal()
        journal.settings.petName = "Pip"
        journal.setWeeklyGoal(12, from: journal.week(containing: thursday))
        try journal.log(DrinkEntry(day: monday, loggedAt: noon, kind: .wine, amount: 5, unit: .fluidOunce, abvPercent: 12), today: thursday)
        try journal.markDrinkFree(thursday, today: thursday)
        try journal.reflect(on: thursday, prompt: ReflectionPrompts.afterDrinkFree[0], answer: "A walk", at: noon, today: thursday)
        var rewards = RewardsLedger(awards: AwardPolicy.eligibleAwards(journal: journal, today: thursday))
        try rewards.buy("lantern", at: noon)
        try rewards.place("lantern", in: "light-1")
        var wander = WanderState.starting(petName: "Pip")
        _ = wander.sync(journal: journal, today: thursday)
        return BackupBundle(journal: journal, rewards: rewards, wander: wander)
    }

    func testVersion2RoundTrip() throws {
        let bundle = try sampleBundle()
        let data = try BackupFormat.encode(bundle, exportedAt: noon, appVersion: "0.2.0", build: "57")
        XCTAssertEqual(try BackupFormat.decode(data), bundle)
        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(root?["format"] as? String, "tippy-backup")
        XCTAssertEqual(root?["version"] as? Int, 2)
    }

    func testDecodesAVersion1BareJournal() throws {
        let bundle = try sampleBundle()
        let v1 = try JournalCodec.encode(bundle.journal)
        let decoded = try BackupFormat.decode(v1)
        XCTAssertEqual(decoded.journal, bundle.journal)
        XCTAssertNil(decoded.rewards)
        XCTAssertNil(decoded.wander)
    }

    func testMissingContextsAreNil() throws {
        let bundle = BackupBundle(journal: try sampleBundle().journal)
        let decoded = try BackupFormat.decode(BackupFormat.encode(bundle, exportedAt: noon, appVersion: "0.2.0", build: "1"))
        XCTAssertEqual(decoded, bundle)
    }

    func testRefusesNewerVersionsAndNonBackups() {
        let newer = Data(#"{"format": "tippy-backup", "version": 9, "journal": {}}"#.utf8)
        XCTAssertThrowsError(try BackupFormat.decode(newer)) {
            XCTAssertEqual($0 as? BackupFormat.Problem, .newerVersion(9))
        }
        XCTAssertThrowsError(try BackupFormat.decode(Data("not json".utf8))) {
            XCTAssertEqual($0 as? BackupFormat.Problem, .notABackup)
        }
        XCTAssertThrowsError(try BackupFormat.decode(Data(#"{"format": "something-else", "version": 1}"#.utf8))) {
            XCTAssertEqual($0 as? BackupFormat.Problem, .notABackup)
        }
        XCTAssertThrowsError(try BackupFormat.decode(Data(#"{"version": 99}"#.utf8)), "a v1 journal from a newer Tippy is refused")
    }

    func testPreviewCountsBothSides() throws {
        let backup = try sampleBundle()
        let preview = RestorePreview(current: BackupBundle(journal: Journal()), backup: backup)
        XCTAssertEqual(preview.current.daysLogged, 0)
        XCTAssertNil(preview.current.firstDay)
        XCTAssertEqual(preview.backup.daysLogged, 2)
        XCTAssertEqual(preview.backup.drinks, 1)
        XCTAssertEqual(preview.backup.reflections, 1)
        XCTAssertEqual(preview.backup.decorations, 1)
        XCTAssertEqual(preview.backup.pets, 1, "the starter hatched on the first check-in")
        XCTAssertEqual(preview.backup.coins, backup.rewards!.balance)
        XCTAssertEqual(preview.backup.firstDay, monday)
        XCTAssertEqual(preview.backup.lastDay, thursday)
    }
}
