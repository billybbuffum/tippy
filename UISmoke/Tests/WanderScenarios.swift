import XCTest

/// The Wander: steps, the trail map, the nest and hatching. One scenario
/// per method; see SmokeSupport.swift.
final class WanderScenarios: SmokeScenario {
    /// The starter egg hatches on the first check-in: mark today drink-free,
    /// skip the reflection, keep the name, and the pondling is on Home.
    func testFirstHatch() {
        launch(seed: .eggReady)
        screen("egg", element("nest-view"))
        XCTAssertFalse(element("pet-view").exists, "no pet before the egg hatches")
        XCTAssertEqual(element("pet-name-label").label, "Sprout")
        XCTAssertEqual(element("nest-countdown-label").label, "Hatches in 1 check-in")
        element("drink-free-button").tap()
        screen("reflection", element("reflection-prompt-label"))
        element("reflection-skip-button").tap()
        screen("hatching", element("hatch-view"))
        XCTAssertEqual(element("hatch-name-field").value as? String, "Sprout")
        pause()
        pause()
        screen("hatched", element("hatch-done-button"))
        element("hatch-done-button").tap()
        screen("home", element("pet-view"))
        XCTAssertEqual(element("pet-name-label").label, "Sprout")
        XCTAssertFalse(element("nest-view").exists, "the nest is empty now")
        XCTAssertTrue(element("wander-next-label").label.hasPrefix("1 step"), element("wander-next-label").label)
    }

    /// Open the Wander part-way along: the shore found, the pet at step 9
    /// in the Reed Bed, the fox's landmark next at step 10.
    func testWanderMap() {
        launch(seed: .wanderMid)
        screen("home", element("wander-next-label"))
        XCTAssertEqual(element("wander-next-label").label, "1 step to the next landmark")
        XCTAssertEqual(element("nest-countdown-label").label, "Hatches in 1 check-in")
        element("wander-button").tap()
        screen("map", element("wander-pet"))
        XCTAssertEqual(element("wander-pet").value as? String, "Step 9")
        XCTAssertEqual(element("landmark-shore-pouch").value as? String, "found")
        XCTAssertEqual(element("landmark-reeds-egg-moth").value as? String, "found")
        XCTAssertEqual(element("landmark-reeds-fox").value as? String, "next")
        XCTAssertEqual(element("landmark-reeds-pouch").value as? String, "locked")
        pause()
        goBack(from: "The Wander")
        screen("home-again", app.navigationBars["Tippy"])
    }

    /// A check-in and a reflection are two steps: the pondling reaches the
    /// seashell on the shore, and Home shows the find card once.
    func testWanderFind() {
        launch(seed: .default, arguments: ["-ui-smoke-replay-wander"])
        screen("home", element("wander-next-label"))
        XCTAssertEqual(element("wander-next-label").label, "2 steps to the Pond Shore")
        element("drink-free-button").tap()
        screen("reflection", element("reflection-answer-field"))
        enter("Read by the window", into: element("reflection-answer-field"))
        element("reflection-save-button").tap()
        screen("found", element("find-card"))
        XCTAssertTrue(element("find-card-label").label.contains("seashell"), element("find-card-label").label)
        XCTAssertEqual(element("wander-next-label").label, "2 steps to the next landmark")
        element("find-card-dismiss-button").tap()
        XCTAssertTrue(element("find-card").waitForNonExistence(timeout: 5), "the card goes once dismissed")
        element("wander-button").tap()
        screen("map", element("wander-pet"))
        XCTAssertEqual(element("landmark-shore-shell").value as? String, "found")
        let caughtUp = NSPredicate(format: "value == %@", "Step 2")
        expectation(for: caughtUp, evaluatedWith: element("wander-pet"))
        waitForExpectations(timeout: 8)
        XCTAssertTrue(element("wander-skip-button").waitForNonExistence(timeout: 8), "wait through landmark reveal")
        XCTAssertFalse(element("find-card").exists, "a find dismissed on Home is not revealed again")
        goBack(from: "The Wander")
        element("wander-button").tap()
        screen("map-again", element("wander-pet"))
        XCTAssertFalse(element("find-card").exists, "reopening does not repeat an acknowledged find")
    }

    /// Unlike ordinary smoke mode, this runs the actual finite replay. Skipping
    /// must settle at the final step and scroll its pet back into the viewport.
    func testWanderSkipReplay() {
        launch(seed: .wanderMid, arguments: ["-ui-smoke-replay-wander"])
        screen("home", element("wander-button"))
        element("wander-button").tap()
        let skip = element("wander-skip-button")
        XCTAssertTrue(skip.waitForExistence(timeout: 5), "the real replay offers Skip")
        skip.tap()
        let pet = element("wander-pet")
        let atEnd = NSPredicate(format: "value == %@ AND hittable == true", "Step 9")
        expectation(for: atEnd, evaluatedWith: pet)
        waitForExpectations(timeout: 8)
        pause()
        screen("skipped", pet)
        XCTAssertEqual(pet.value as? String, "Step 9", "the cancelled task cannot move the pet back")
        XCTAssertTrue(pet.isHittable, "Skip scrolls to the final pet position")
        goBack(from: "The Wander")
        element("wander-button").tap()
        screen("final-position-kept", pet)
        XCTAssertEqual(pet.value as? String, "Step 9")
        XCTAssertFalse(element("wander-skip-button").exists, "completed movement is not replayed")
    }
}
