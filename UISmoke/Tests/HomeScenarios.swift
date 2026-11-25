import XCTest

/// The home screen: the pet, the week, and logging today. One scenario
/// per method; see SmokeSupport.swift.
final class HomeScenarios: SmokeScenario {
    /// A fresh week: the pet, the week card and today not logged.
    func testHome() {
        launch(seed: .default)
        screen("home", app.navigationBars["Tippy"])
        XCTAssertTrue(element("pet-view").exists)
        XCTAssertTrue(element("week-total-label").label.hasPrefix("0.0 "), element("week-total-label").label)
        XCTAssertTrue(element("today-status-label").label.contains("isn't logged"), element("today-status-label").label)
        XCTAssertFalse(element("reminder-offer-card").exists, "no reminder offer before the first check-in")
    }

    /// Log a glass of wine, skip the reflection: one standard drink on the week.
    func testLogDrink() {
        launch(seed: .default)
        screen("home", app.navigationBars["Tippy"])
        element("log-drink-button").tap()
        screen("log-sheet", app.navigationBars["Log a drink"])
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
        screen("home", app.navigationBars["Tippy"])
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
        screen("home", app.navigationBars["Tippy"])
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
        screen("mid-week", app.navigationBars["Tippy"])
        XCTAssertTrue(element("week-total-label").label.hasPrefix("6.0 "), element("week-total-label").label)
        XCTAssertTrue(element("drink-free-count-label").label.hasPrefix("1 "), element("drink-free-count-label").label)
        XCTAssertTrue(element("days-logged-label").label.hasPrefix("3 of 4"), element("days-logged-label").label)
    }

    /// After the first check-in, the reminder is offered once.
    func testReminderOffer() {
        launch(seed: .midWeek)
        screen("offer", element("reminder-offer-card"))
        element("reminder-offer-accept-button").tap()
        XCTAssertTrue(element("reminder-offer-card").waitForNonExistence(timeout: 5), "the offer goes away once answered")
        screen("accepted", app.navigationBars["Tippy"])
    }
}
