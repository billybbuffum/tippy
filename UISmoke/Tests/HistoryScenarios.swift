import XCTest

/// History and back-filling. One scenario per method; see SmokeSupport.swift.
final class HistoryScenarios: SmokeScenario {
    /// The week's days: drinks on Monday and Tuesday, Wednesday drink-free.
    func testHistory() {
        launch(seed: .midWeek)
        screen("home", app.navigationBars["Tippy"])
        element("history-button").tap()
        screen("history", app.navigationBars["History"])
        XCTAssertTrue(element("history-drink-free-row").exists)
        XCTAssertTrue(element("history-entry-row").exists)
        pause()
        goBack(from: "History")
        screen("home-again", app.navigationBars["Tippy"])
    }

    /// Mark a day drink-free from History.
    func testBackfillDrinkFree() {
        launch(seed: .default)
        screen("home", app.navigationBars["Tippy"])
        element("history-button").tap()
        screen("history-empty", app.navigationBars["History"])
        element("add-drink-free-day-button").tap()
        screen("pick-day", app.navigationBars["Drink-free day"])
        element("mark-drink-free-button").tap()
        screen("marked", element("history-drink-free-row"))
    }
}
