import XCTest

/// First launch. One scenario per method; see SmokeSupport.swift.
final class OnboardingScenarios: SmokeScenario {
    /// Name the pet, answer the questions, skip the cost, land on the home screen.
    func testOnboarding() {
        launch(seed: .onboarding)
        screen("welcome", element("onboarding-pet-name-field"))
        enter("Pip", into: element("onboarding-pet-name-field"))
        element("onboarding-next-button").tap()
        screen("baseline", element("onboarding-baseline-stepper"))
        element("onboarding-next-button").tap()
        screen("goal", element("onboarding-goal-stepper"))
        element("onboarding-next-button").tap()
        screen("cost", element("onboarding-cost-stepper"))
        element("onboarding-skip-cost-button").tap()
        screen("home", app.navigationBars["Tippy"])
        XCTAssertEqual(element("pet-name-label").label, "Pip")
        XCTAssertTrue(element("week-total-label").label.hasSuffix("of 14 drinks this week"), element("week-total-label").label)
    }
}
