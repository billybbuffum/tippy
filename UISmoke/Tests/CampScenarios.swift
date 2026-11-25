import XCTest

/// The camp: the shop and decorating (spec 02). One scenario per method; see SmokeSupport.swift.
final class CampScenarios: SmokeScenario {
    /// Open the shop from the coin badge, buy the lantern, place it straight away.
    func testBuyAndPlace() {
        launch(seed: .coins)
        screen("home", element("camp-scene"))
        XCTAssertEqual(element("coin-balance-label").label, "120 coins")
        element("coin-badge-button").tap()
        screen("shop", app.navigationBars["Shop"])
        element("buy-lantern-button").tap()
        tapDialogButton("confirm-buy-button", title: "Buy it")
        screen("bought", element("bought-label"))
        XCTAssertEqual(element("shop-balance-label").label, "110 coins")
        element("place-now-button").tap()
        screen("choose-spot", element("camp-slot-light-1"))
        element("camp-slot-light-1").tap()
        pause()
        element("decorate-done-button").tap()
        screen("placed", element("camp-item-lantern"))
        XCTAssertEqual(element("coin-balance-label").label, "110 coins")
    }

    /// The showpiece is out of reach with 120 coins; the starters aren't.
    func testShopNotEnough() {
        launch(seed: .coins)
        screen("home", element("camp-scene"))
        element("coin-badge-button").tap()
        screen("shop", app.navigationBars["Shop"])
        XCTAssertTrue(element("buy-lantern-button").isEnabled)
        reveal(element("buy-willow-arch-button"))
        screen("showpiece", element("buy-willow-arch-button"))
        XCTAssertFalse(element("buy-willow-arch-button").isEnabled, "150 coins is more than 120")
        element("shop-done-button").tap()
        screen("home-again", element("camp-scene"))
    }

    /// Decorate: move the sprout, put the seashell away, place the mushroom from storage.
    func testDecorateMoveStore() {
        launch(seed: .furnishedCamp)
        screen("camp", element("camp-item-sprout"))
        element("decorate-button").tap()
        screen("decorating", element("camp-slot-ground-1"))

        element("camp-slot-ground-1").tap()
        screen("sprout-spot", element("move-item-button"))
        element("move-item-button").tap()
        screen("choose-new-spot", element("decorate-hint-label"))
        element("camp-slot-ground-5").tap()
        pause()

        element("camp-slot-ground-4").tap()
        screen("seashell-spot", element("store-item-button"))
        element("store-item-button").tap()
        pause()

        element("camp-slot-ground-2").tap()
        screen("empty-spot", element("place-mushroom-button"))
        element("place-mushroom-button").tap()
        pause()

        element("decorate-done-button").tap()
        screen("rearranged", element("camp-item-mushroom"))
        XCTAssertTrue(element("camp-item-sprout").exists)
        XCTAssertFalse(element("camp-item-seashell").exists, "the seashell is in storage")
        XCTAssertEqual(element("coin-balance-label").label, "60 coins", "moving and storing are free")
    }
}
