import XCTest
import TippyModeration
@testable import TippyRewards

final class CampTests: XCTestCase {
    let day = LocalDate("2026-11-19")!
    let noon = Date(timeIntervalSince1970: 1_763_553_600)

    /// A ledger worth `coins`, from synthetic pouches of 10.
    func ledger(coins: Int) -> RewardsLedger {
        let awards = (0..<(coins / 10)).map { Award(key: .pouch("test-\($0)"), coins: 10, earnedOn: day)! }
        return RewardsLedger(awards: awards)
    }

    // MARK: Catalog

    func testCatalogIsConsistent() {
        let ids = CampCatalog.items.map(\.id)
        XCTAssertEqual(Set(ids).count, ids.count, "item IDs are unique")
        XCTAssertEqual(Set(CampCatalog.slots.map(\.id)).count, CampCatalog.slots.count, "slot IDs are unique")
        XCTAssertEqual(CampCatalog.items.count, 16)
        XCTAssertEqual(CampCatalog.shopItems.count, 12, "the firefly jar and the three side-path finds are find-only")
        XCTAssertEqual(CampCatalog.shopItems.filter { $0.price <= 12 }.count, 3, "three starters")
        for item in CampCatalog.items {
            XCTAssertTrue(CampCatalog.slots.contains { $0.kind == item.kind }, "\(item.id) has somewhere to go")
            XCTAssertEqual(item.inShop, item.price > 0, "\(item.id): shop items have a price, finds don't")
        }
        XCTAssertFalse(CampCatalog.item("firefly-jar")!.inShop)
    }

    // MARK: Buying

    func testBuyingSpendsCoinsAndOwnsTheItem() throws {
        var ledger = ledger(coins: 30)
        try ledger.buy("lantern", at: noon)
        XCTAssertEqual(ledger.spent, 10)
        XCTAssertEqual(ledger.balance, 20)
        XCTAssertTrue(ledger.owns("lantern"))
        XCTAssertEqual(ledger.storedItems(), ["lantern"])
    }

    func testBuyingWithTheExactBalance() throws {
        var ledger = ledger(coins: 10)
        try ledger.buy("lantern", at: noon)
        XCTAssertEqual(ledger.balance, 0)
    }

    func testBuyingIsRefusedForEveryReason() throws {
        var ledger = ledger(coins: 20)
        XCTAssertThrowsError(try ledger.buy("nope", at: noon)) { XCTAssertEqual($0 as? RewardsLedger.Problem, .unknownItem) }
        XCTAssertThrowsError(try ledger.buy("firefly-jar", at: noon)) { XCTAssertEqual($0 as? RewardsLedger.Problem, .notForSale) }
        XCTAssertThrowsError(try ledger.buy("willow-arch", at: noon)) { XCTAssertEqual($0 as? RewardsLedger.Problem, .insufficientCoins) }
        try ledger.buy("lantern", at: noon)
        XCTAssertThrowsError(try ledger.buy("lantern", at: noon)) { XCTAssertEqual($0 as? RewardsLedger.Problem, .alreadyOwned) }
        XCTAssertEqual(ledger.purchases.count, 1, "a refused purchase records nothing")
        XCTAssertEqual(ledger.balance, 10)
    }

    // MARK: Grants

    func testGrantsAreFreeAndOncePerKey() {
        var ledger = RewardsLedger()
        XCTAssertTrue(ledger.grant("firefly-jar", key: .find("willow-lantern")))
        XCTAssertFalse(ledger.grant("firefly-jar", key: .find("willow-lantern")))
        XCTAssertFalse(ledger.grant("not-an-item", key: .find("elsewhere")))
        XCTAssertTrue(ledger.owns("firefly-jar"))
        XCTAssertEqual(ledger.balance, 0)
        XCTAssertEqual(ledger.grants.count, 1)
    }

    func testGrantingAnOwnedItemIsHarmless() throws {
        var ledger = ledger(coins: 20)
        try ledger.buy("seashell", at: noon)
        XCTAssertTrue(ledger.grant("seashell", key: .find("shore-shell")))
        XCTAssertEqual(ledger.storedItems(), ["seashell"], "still one seashell")
    }

    // MARK: Placing

    func testPlacingMovingSwappingAndStoring() throws {
        var ledger = ledger(coins: 60)
        try ledger.buy("sprout", at: noon)
        try ledger.buy("seashell", at: noon)
        try ledger.place("sprout", in: "ground-1")
        XCTAssertEqual(ledger.item(in: "ground-1"), "sprout")

        // Moving: the sprout leaves ground-1.
        try ledger.place("sprout", in: "ground-2")
        XCTAssertNil(ledger.item(in: "ground-1"))
        XCTAssertEqual(ledger.item(in: "ground-2"), "sprout")

        // Swapping: the seashell takes ground-2, the sprout goes back to storage.
        try ledger.place("seashell", in: "ground-2")
        XCTAssertEqual(ledger.item(in: "ground-2"), "seashell")
        XCTAssertEqual(ledger.storedItems(), ["sprout"])

        // Storing.
        ledger.store(slotID: "ground-2")
        XCTAssertEqual(Set(ledger.storedItems()), ["sprout", "seashell"])
        XCTAssertEqual(ledger.balance, 60 - 24, "moving and storing are free")
    }

    func testPlacingIsRefusedForEveryReason() throws {
        var ledger = ledger(coins: 20)
        try ledger.buy("lantern", at: noon)
        XCTAssertThrowsError(try ledger.place("lantern", in: "roof")) { XCTAssertEqual($0 as? RewardsLedger.Problem, .unknownSlot) }
        XCTAssertThrowsError(try ledger.place("nope", in: "light-1")) { XCTAssertEqual($0 as? RewardsLedger.Problem, .unknownItem) }
        XCTAssertThrowsError(try ledger.place("sprout", in: "ground-1")) { XCTAssertEqual($0 as? RewardsLedger.Problem, .notOwned) }
        XCTAssertThrowsError(try ledger.place("lantern", in: "ground-1")) { XCTAssertEqual($0 as? RewardsLedger.Problem, .wrongSlotKind) }
        XCTAssertTrue(ledger.placements.isEmpty)
    }

    // MARK: Persistence

    func testCodecRoundTripWithCamp() throws {
        var ledger = ledger(coins: 60)
        try ledger.buy("lantern", at: noon)
        ledger.grant("firefly-jar", key: .find("willow-lantern"))
        try ledger.place("lantern", in: "light-1")
        try ledger.place("firefly-jar", in: "light-2")
        let decoded = try RewardsCodec.decode(RewardsCodec.encode(ledger))
        XCTAssertEqual(decoded, ledger)
        XCTAssertEqual(decoded.item(in: "light-2"), "firefly-jar")
    }

    func testDecodesAFileFromBeforeTheCamp() throws {
        let json = #"{"version": 1, "awards": [{"key": "checkIn:2026-11-19", "coins": 5, "earnedOn": "2026-11-19"}], "recaps": []}"#
        let ledger = try RewardsCodec.decode(Data(json.utf8))
        XCTAssertEqual(ledger.balance, 5)
        XCTAssertTrue(ledger.purchases.isEmpty)
        XCTAssertTrue(ledger.placements.isEmpty)
        XCTAssertTrue(ledger.owned.isEmpty)
    }

    func testLoadingRepairsPlacements() {
        let purchases = [Purchase(itemID: "lantern", price: 10, at: noon), Purchase(itemID: "sprout", price: 12, at: noon)]
        let ledger = RewardsLedger(
            awards: [Award(key: .pouch("a"), coins: 50, earnedOn: day)!],
            purchases: purchases,
            placements: [
                "light-1": "lantern",      // fine
                "light-2": "lantern",      // the same item twice: dropped
                "ground-1": "mushroom",    // not owned: dropped
                "water-1": "sprout",       // wrong kind: dropped
                "attic": "sprout",         // unknown spot: dropped
            ]
        )
        XCTAssertEqual(ledger.placements, ["light-1": "lantern"])
        XCTAssertEqual(ledger.balance, 28, "purchases stay as history")
    }
}
