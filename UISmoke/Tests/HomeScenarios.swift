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
    }

    /// Log a glass of wine: one standard drink on the week.
    func testLogDrink() {
        launch(seed: .default)
        screen("home", app.navigationBars["Tippy"])
        element("log-drink-button").tap()
        screen("log-sheet", app.navigationBars["Log a drink"])
        element("drink-kind-wine").tap()
        pause()
        screen("wine-chosen", element("drink-standard-label"))
        element("save-drink-button").tap()
        screen("logged", element("week-total-label"))
        XCTAssertTrue(element("week-total-label").label.hasPrefix("1.0 "), element("week-total-label").label)
        XCTAssertTrue(element("today-status-label").label.hasPrefix("Today: 1.0"), element("today-status-label").label)
    }

    /// "No drinks today" marks today drink-free.
    func testDrinkFreeToday() {
        launch(seed: .default)
        screen("home", app.navigationBars["Tippy"])
        element("drink-free-button").tap()
        pause()
        screen("drink-free", element("today-status-label"))
        XCTAssertTrue(element("today-status-label").label.contains("drink-free"), element("today-status-label").label)
        XCTAssertTrue(element("drink-free-count-label").label.hasPrefix("1 "), element("drink-free-count-label").label)
    }

    /// Thursday of a week under budget: the totals, the drink-free day and
    /// the streak.
    func testMidWeek() {
        launch(seed: .midWeek)
        screen("mid-week", app.navigationBars["Tippy"])
        XCTAssertTrue(element("week-total-label").label.hasPrefix("6.0 "), element("week-total-label").label)
        XCTAssertTrue(element("drink-free-count-label").label.hasPrefix("1 "), element("drink-free-count-label").label)
        XCTAssertTrue(element("streak-label").label.hasPrefix("3-day"), element("streak-label").label)
    }
}
