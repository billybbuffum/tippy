import XCTest

/// Forks and side paths on the Wander (spec 07). One scenario per method; see SmokeSupport.swift.
final class ForkScenarios: SmokeScenario {
    /// The pet waits at Heron's Inlet with 2 steps saved; exploring walks
    /// them down the side path to its first find.
    func testForkExplore() {
        launch(seed: .atFork)
        screen("home", element("wander-next-label"))
        XCTAssertEqual(element("wander-next-label").label, "At a fork: which way?")
        element("wander-next-label").tap()
        screen("which-way", element("fork-card"))
        XCTAssertTrue(element("fork-saved-label").label.hasPrefix("2 steps saved"), element("fork-saved-label").label)
        XCTAssertEqual(element("wander-pet").value as? String, "Step 11, at the Heron's Inlet fork")
        element("fork-explore-button").tap()
        let onPath = NSPredicate(format: "value == %@", "Heron's Inlet, step 2 of 5")
        expectation(for: onPath, evaluatedWith: element("wander-pet"))
        waitForExpectations(timeout: 8)
        screen("side-path", element("wander-pet"))
        XCTAssertEqual(element("landmark-inlet-pouch").value as? String, "found")
        XCTAssertEqual(element("landmark-inlet-cairn").value as? String, "next")
        XCTAssertFalse(element("fork-card").exists, "the choice is made")
        goBack(from: "The Wander")
        screen("home-exploring", element("wander-next-label"))
        XCTAssertEqual(element("wander-next-label").label, "Exploring Heron's Inlet")
    }

    /// Staying on the trail walks the saved steps on to the reed pouch, and
    /// the side path stays open.
    func testForkStay() {
        launch(seed: .atFork)
        screen("home", element("wander-next-label"))
        element("wander-next-label").tap()
        screen("which-way", element("fork-card"))
        element("fork-stay-button").tap()
        let onward = NSPredicate(format: "value == %@", "Step 13")
        expectation(for: onward, evaluatedWith: element("wander-pet"))
        waitForExpectations(timeout: 8)
        screen("stayed", element("wander-pet"))
        XCTAssertEqual(element("landmark-reeds-pouch").value as? String, "found")
        XCTAssertTrue(element("revisit-reeds-inlet-button").exists, "the side path stays open")
    }

    /// A passed side path, explored later from the map: the pet hops to the
    /// fork, and the next check-in walks it down the path.
    func testSidePathRevisit() {
        launch(seed: .forkPassed)
        screen("home", element("wander-next-label"))
        element("wander-next-label").tap()
        screen("map", element("wander-pet"))
        XCTAssertEqual(element("wander-pet").value as? String, "Step 15")
        let explore = element("revisit-reeds-inlet-button")
        XCTAssertTrue(explore.waitForExistence(timeout: 5))
        explore.tap()
        let atFork = NSPredicate(format: "value == %@", "Heron's Inlet, step 0 of 5")
        expectation(for: atFork, evaluatedWith: element("wander-pet"))
        waitForExpectations(timeout: 8)
        screen("off-to-the-inlet", element("wander-pet"))
        XCTAssertFalse(element("revisit-reeds-inlet-button").exists, "one visit at a time")
        goBack(from: "The Wander")
        screen("home", element("wander-next-label"))
        XCTAssertEqual(element("wander-next-label").label, "Exploring Heron's Inlet")
        element("drink-free-button").tap()
        screen("reflection", element("reflection-prompt-label"))
        element("reflection-skip-button").tap()
        screen("checked-in", element("home-screen"))
        element("wander-next-label").tap()
        let firstStep = NSPredicate(format: "value == %@", "Heron's Inlet, step 1 of 5")
        expectation(for: firstStep, evaluatedWith: element("wander-pet"))
        waitForExpectations(timeout: 8)
        screen("down-the-path", element("wander-pet"))
    }
}
