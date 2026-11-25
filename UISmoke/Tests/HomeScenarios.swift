import XCTest

/// The home screen: the pet, this week's total, and logging. One scenario
/// per method; see SmokeSupport.swift.
final class HomeScenarios: SmokeScenario {
    /// A fresh week: the pet, the total and the two log buttons.
    func testHome() {
        launch(seed: .default)
        screen("home", app.navigationBars["Tippy"])
        XCTAssertTrue(element("pet-view").exists)
        XCTAssertTrue(element("log-drink-button").exists)
        XCTAssertTrue(element("drink-free-button").exists)
    }

    /// Logging a beer adds one standard drink to the week.
    func testLogDrink() {
        launch(seed: .default)
        screen("home", app.navigationBars["Tippy"])
        XCTAssertTrue(element("week-total-label").label.hasPrefix("0.0 "))
        element("log-drink-button").tap()
        pause()
        screen("logged", element("week-total-label"))
        XCTAssertTrue(element("week-total-label").label.hasPrefix("1.0 "), element("week-total-label").label)
    }

    /// Midway through a week under budget, the pet is thriving.
    func testMidWeek() {
        launch(seed: .midWeek)
        screen("mid-week", app.navigationBars["Tippy"])
        XCTAssertTrue(element("week-total-label").label.hasPrefix("6.0 "))
        element("drink-free-button").tap()
        pause()
        screen("drink-free", element("pet-mood-label"))
    }
}
