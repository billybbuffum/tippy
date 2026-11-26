import XCTest

/// Coins and the weekly recap. One scenario per method; see SmokeSupport.swift.
final class RewardsScenarios: SmokeScenario {
    /// Mark today drink-free and skip the reflection: the toast, and 8 coins
    /// (5 for the check-in, 3 for drink-free).
    func testEarnCoins() {
        launch(seed: .default)
        screen("home", element("coin-balance-label"))
        XCTAssertEqual(element("coin-balance-label").label, "0 coins")
        element("drink-free-button").tap()
        screen("reflection", element("reflection-prompt-label"))
        element("reflection-skip-button").tap()
        screen("toast", element("coins-earned-toast"))
        XCTAssertTrue(element("coins-earned-toast").label.contains("+8 coins"), element("coins-earned-toast").label)
        XCTAssertEqual(element("coin-balance-label").label, "8 coins")
    }

    /// Last week's recap opens on launch with its total, days and coins, the
    /// +15 goal bonus included. An idea for this week, Done: it's on Home.
    func testWeeklyRecap() {
        launch(seed: .lastWeekDone)
        screen("recap", element("weekly-recap-view"))
        XCTAssertTrue(element("recap-title-label").label.contains("Nov 9"), element("recap-title-label").label)
        XCTAssertTrue(element("recap-total-label").label.hasPrefix("10.0 of 14"), element("recap-total-label").label)
        XCTAssertTrue(element("recap-days-label").label.hasPrefix("6 of 7 days logged"), element("recap-days-label").label)
        XCTAssertEqual(element("recap-coins-label").label, "48 coins earned")
        XCTAssertTrue(element("recap-goal-bonus-label").exists, "the goal bonus line")
        XCTAssertTrue(element("recap-reflection-row").exists, "last week's reflection")
        enter("Sparkling water before dinner", into: element("recap-idea-field"))
        screen("idea", element("recap-done-button"))
        element("recap-done-button").tap()
        screen("home-idea", element("recap-idea-card"))
        XCTAssertTrue(element("weekly-recap-view").waitForNonExistence(timeout: 5), "the recap closes")
        XCTAssertEqual(element("recap-idea-label").label, "Sparkling water before dinner")
        XCTAssertEqual(element("coin-balance-label").label, "48 coins")
        element("settings-button").tap()
        screen("settings", element("settings-done-button"))
        element("settings-done-button").tap()
        screen("idea-kept", element("recap-idea-label"))
        XCTAssertEqual(element("recap-idea-label").label, "Sparkling water before dinner")
        XCTAssertFalse(element("weekly-recap-view").exists, "Done preserves the idea and consumes only its recap")
    }

    /// Back-fill Monday (three days ago) as drink-free from History: 8 more coins.
    func testBackfillEarns() {
        launch(seed: .default)
        screen("home", element("coin-balance-label"))
        XCTAssertEqual(element("coin-balance-label").label, "0 coins")
        element("history-button").tap()
        screen("history", element("history-screen"))
        element("add-drink-free-day-button").tap()
        screen("pick-day", element("drink-free-day-sheet"))
        // The calendar's day cells are system buttons with no identifiers, so
        // Monday 16 November is found by its date.
        let monday = app.buttons
            .matching(NSPredicate(format: "label CONTAINS 'November 16' OR label CONTAINS '16 November'"))
            .firstMatch
        XCTAssertTrue(monday.waitForExistence(timeout: 5), "the calendar shows 16 November")
        monday.tap()
        pause()
        screen("monday-picked", element("mark-drink-free-button"))
        element("mark-drink-free-button").tap()
        screen("marked", element("history-drink-free-row"))
        goBack(from: "History")
        screen("toast", element("coins-earned-toast"))
        XCTAssertEqual(element("coin-balance-label").label, "8 coins")
    }
}
