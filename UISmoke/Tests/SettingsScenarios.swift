import XCTest

/// Settings. One scenario per method; see SmokeSupport.swift.
final class SettingsScenarios: SmokeScenario {
    /// Every section of Settings, top to bottom.
    func testSettingsTour() {
        launch(seed: .default)
        screen("home", app.navigationBars["Tippy"])
        element("settings-button").tap()
        screen("settings", app.navigationBars["Settings"])
        XCTAssertTrue(element("weekly-goal-stepper").exists)
        reveal(element("build-number-label"))
        screen("settings-bottom", element("build-number-label"))
        element("settings-done-button").tap()
        screen("home-again", app.navigationBars["Tippy"])
    }
}
