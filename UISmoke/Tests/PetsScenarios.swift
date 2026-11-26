import XCTest

/// Pets and visitors on the Wander (spec 03b). One scenario per method; see SmokeSupport.swift.
final class PetsScenarios: SmokeScenario {
    /// A check-in hatches the nested moth: name it Dot, meet the fox it walked
    /// into, and find both pets in the collection.
    func testHatchMoth() {
        launch(seed: .wanderMid)
        screen("home", element("camp-scene"))
        element("drink-free-button").tap()
        screen("reflection", element("reflection-prompt-label"))
        element("reflection-skip-button").tap()
        screen("hatching", element("hatch-name-field"), timeout: 15)
        replaceText("Dot", in: element("hatch-name-field"))
        element("hatch-done-button").tap()
        // Today's step also reached the fox at dusk, who visits next.
        screen("visitor", element("visitor-done-button"), timeout: 15)
        element("visitor-done-button").tap()
        XCTAssertTrue(element("visitor-dialog").waitForNonExistence(timeout: 5))
        element("pets-button").tap()
        screen("pets", element("pets-screen"))
        XCTAssertTrue(element("pet-reeds-egg-moth-row").exists, "the moth joined the collection")
        XCTAssertTrue(element("pet-starter-row").exists)
    }

    /// Choose Dot: the moth goes out into the camp and Home names her.
    func testChoosePet() {
        launch(seed: .twoPets)
        screen("home", element("camp-scene"))
        element("pets-button").tap()
        screen("pets", element("pets-screen"))
        element("choose-pet-reeds-egg-moth-button").tap()
        pause()
        screen("chosen", element("active-pet-label"))
        goBack(from: "Pets")
        screen("home-with-dot", element("pet-name-label"))
        XCTAssertEqual(element("pet-name-label").label, "Dot")
    }

    /// The fox at dusk visits once, then is gone for good.
    func testFoxVisitor() {
        launch(seed: .foxVisit)
        screen("visitor", element("visitor-dialog"), timeout: 15)
        XCTAssertTrue(element("visitor-title-label").exists)
        element("visitor-done-button").tap()
        XCTAssertTrue(element("visitor-dialog").waitForNonExistence(timeout: 5))
        screen("home", element("camp-scene"))
        element("history-button").tap()
        screen("history", element("history-screen"))
        goBack(from: "History")
        pause()
        XCTAssertFalse(element("visitor-dialog").exists, "the visit happens once")
    }
}
