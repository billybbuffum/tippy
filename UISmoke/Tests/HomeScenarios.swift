import XCTest

/// The home screen: the pet, the week, and logging today. One scenario
/// per method; see SmokeSupport.swift.
final class HomeScenarios: SmokeScenario {
    /// A fresh week: the pet, the week card and today not logged.
    func testHome() {
        launch(seed: .default)
        screen("home", element("home-screen"))
        XCTAssertTrue(element("pet-view").exists)
        XCTAssertTrue(element("week-total-label").label.hasPrefix("0.0 "), element("week-total-label").label)
        XCTAssertTrue(element("today-status-label").label.contains("isn't logged"), element("today-status-label").label)
        XCTAssertFalse(element("reminder-offer-card").exists, "no reminder offer before the first check-in")
    }

    /// The immersive Home (spec 06): the world fills the screen with no
    /// navigation bar; the HUD, the pet's bubble and the dock sit on it, and
    /// decorate mode swaps the dock.
    func testHomeWorld() {
        launch(seed: .furnishedCamp)
        screen("world", element("home-screen"))
        XCTAssertFalse(app.navigationBars.firstMatch.exists, "Home has no navigation bar")
        XCTAssertTrue(element("camp-item-lantern").exists)
        XCTAssertEqual(element("pet-name-label").label, "Sprout")
        XCTAssertEqual(element("coin-balance-label").label, "60 coins")
        XCTAssertTrue(element("today-status-label").label.contains("isn't logged"), element("today-status-label").label)
        element("decorate-button").tap()
        screen("decorating", element("decorate-done-button"))
        XCTAssertFalse(element("log-drink-button").exists, "the dock swaps in decorate mode")
        element("decorate-done-button").tap()
        screen("dock-back", element("log-drink-button"))
    }

    /// Log a glass of wine, skip the reflection: one standard drink on the week.
    func testLogDrink() {
        launch(seed: .default)
        screen("home", element("home-screen"))
        element("log-drink-button").tap()
        screen("log-sheet", element("log-drink-sheet"))
        element("drink-kind-wine").tap()
        pause()
        screen("wine-chosen", element("drink-standard-label"))
        element("save-drink-button").tap()
        screen("reflection", element("reflection-prompt-label"))
        element("reflection-skip-button").tap()
        screen("logged", element("week-total-label"))
        XCTAssertTrue(element("week-total-label").label.hasPrefix("1.0 "), element("week-total-label").label)
        XCTAssertTrue(element("today-status-label").label.hasPrefix("Today: 1.0"), element("today-status-label").label)
    }

    /// "No drinks today" marks today drink-free, then offers the reflection.
    func testDrinkFreeToday() {
        launch(seed: .default)
        screen("home", element("home-screen"))
        element("drink-free-button").tap()
        screen("reflection", element("reflection-prompt-label"))
        element("reflection-skip-button").tap()
        screen("drink-free", element("today-status-label"))
        XCTAssertTrue(element("today-status-label").label.contains("drink-free"), element("today-status-label").label)
        XCTAssertTrue(element("drink-free-count-label").label.hasPrefix("1 "), element("drink-free-count-label").label)
    }

    /// Answer the reflection after a drink-free day; it shows in History.
    func testReflect() {
        launch(seed: .default)
        screen("home", element("home-screen"))
        element("drink-free-button").tap()
        screen("reflection", element("reflection-answer-field"))
        enter("Tea and a good book", into: element("reflection-answer-field"))
        element("reflection-save-button").tap()
        screen("home-after", element("today-status-label"))
        element("history-button").tap()
        screen("history", element("history-reflection-row"))
    }

    /// Thursday of a week under budget: the totals and the days logged.
    func testMidWeek() {
        launch(seed: .midWeek)
        screen("mid-week", element("home-screen"))
        XCTAssertTrue(element("week-total-label").label.hasPrefix("6.0 "), element("week-total-label").label)
        XCTAssertTrue(element("drink-free-count-label").label.hasPrefix("1 "), element("drink-free-count-label").label)
        XCTAssertTrue(element("days-logged-label").label.hasPrefix("3 of 4"), element("days-logged-label").label)
    }

    /// After the first check-in, the reminder is offered once.
    func testReminderOffer() {
        launch(seed: .midWeek)
        screen("offer", element("reminder-offer-card"))
        XCTAssertFalse(element("history-drink-free-row").exists)
        element("reminder-offer-accept-button").tap()
        XCTAssertTrue(element("reminder-offer-card").waitForNonExistence(timeout: 5), "the offer goes away once answered")
        screen("accepted", element("home-screen"))
        XCTAssertTrue(element("today-status-label").label.contains("isn't logged"), "the tap reached the offer, not the bar below it")
    }
}
