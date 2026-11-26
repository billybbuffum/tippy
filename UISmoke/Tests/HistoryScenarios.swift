import XCTest

/// History, editing and back-filling. One scenario per method; see SmokeSupport.swift.
final class HistoryScenarios: SmokeScenario {
    /// The week's days: drinks Monday and Tuesday, Wednesday drink-free with a reflection.
    func testHistory() {
        launch(seed: .midWeek)
        screen("home", element("home-screen"))
        element("history-button").tap()
        screen("history", app.navigationBars["History"])
        XCTAssertTrue(element("history-drink-free-row").exists)
        XCTAssertTrue(element("history-entry-row").exists)
        XCTAssertTrue(element("history-reflection-row").exists)
        pause()
        goBack(from: "History")
        screen("home-again", element("home-screen"))
    }

    /// Tap a drink to edit it: change it to wine.
    func testEditDrink() {
        launch(seed: .midWeek)
        screen("home", element("home-screen"))
        element("history-button").tap()
        screen("history", app.navigationBars["History"])
        element("history-entry-row").tap()
        screen("edit", element("edit-drink-sheet"))
        element("drink-kind-wine").tap()
        pause()
        element("save-drink-button").tap()
        screen("edited", app.navigationBars["History"])
    }

    /// Deleting a day's only drink asks what the day becomes: drink-free.
    func testDeleteLastDrink() {
        launch(seed: .oneDrink)
        screen("home", element("home-screen"))
        element("history-button").tap()
        screen("history", app.navigationBars["History"])
        element("history-entry-row").tap()
        screen("edit", element("edit-drink-sheet"))
        element("delete-drink-button").tap()
        tapDialogButton("empty-day-drink-free-button", title: "Mark the day drink-free")
        screen("now-drink-free", element("history-drink-free-row"))
        XCTAssertFalse(element("history-entry-row").exists)
    }

    /// Mark a day drink-free from History.
    func testBackfillDrinkFree() {
        launch(seed: .default)
        screen("home", element("home-screen"))
        element("history-button").tap()
        screen("history-empty", app.navigationBars["History"])
        element("add-drink-free-day-button").tap()
        screen("pick-day", app.navigationBars["Drink-free day"])
        element("mark-drink-free-button").tap()
        screen("marked", element("history-drink-free-row"))
    }
}
