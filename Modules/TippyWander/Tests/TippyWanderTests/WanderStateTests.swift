import XCTest
import TippyModeration
@testable import TippyWander

final class WanderStateTests: XCTestCase {
    let today = LocalDate("2026-11-19")!
    let noon = Date(timeIntervalSince1970: 1_763_553_600)

    func day(_ offset: Int, from base: LocalDate? = nil) -> LocalDate {
        (base ?? today).adding(days: offset)
    }

    /// A journal with the given days (offsets from `base`) drink-free and the
    /// given days reflected on.
    func journal(
        drinkFree offsets: [Int],
        reflections reflected: [Int] = [],
        from base: LocalDate? = nil,
        petName: String = "Sprout"
    ) -> Journal {
        var settings = ModerationSettings()
        settings.petName = petName
        let free = Set(offsets.map { day($0, from: base) })
        let answers = reflected.map {
            Reflection(day: day($0, from: base), promptID: "what-helped", answer: "A walk", answeredAt: noon)
        }
        return Journal(settings: settings, drinkFreeDays: free, reflections: answers)
    }

    var sprout: Pet { Pet(id: WanderState.starterEggID, speciesID: "pondling", name: "Sprout", hatchedOn: day(-30)) }

    /// A Wander whose pondling has already hatched, with no steps yet.
    func hatched() -> WanderState {
        WanderState(pets: [sprout], activePetID: sprout.id)
    }

    // MARK: Steps

    func testPositionAndStepsForASeededJournal() {
        var state = hatched()
        let events = state.sync(journal: journal(drinkFree: [-3, -2, -1, 0], reflections: [-1]), today: today)
        XCTAssertEqual(events.newSteps, 5)
        XCTAssertEqual(state.position, 5)
        XCTAssertEqual(state.checkInCount, 4)
        XCTAssertNotNil(state.steps[StepKey(.checkIn, today)])
        XCTAssertNotNil(state.steps[StepKey(.reflection, day(-1))])
        XCTAssertEqual(state.steps[StepKey(.checkIn, day(-3))]?.awardedOn, today)
        XCTAssertEqual(StepKey(.checkIn, today).description, "checkIn:2026-11-19")
        XCTAssertEqual(StepKey("reflection:2026-11-18"), StepKey(.reflection, day(-1)))
        XCTAssertNil(StepKey("walk:2026-11-18"))
    }

    func testDrinksCountAsACheckIn() {
        var state = hatched()
        var log = Journal()
        let beer = DrinkEntry(day: today, loggedAt: noon, kind: .beer, amount: 12, unit: .fluidOunce, abvPercent: 5)
        XCTAssertNoThrow(try log.log(beer, today: today))
        let events = state.sync(journal: log, today: today)
        XCTAssertEqual(events.newSteps, 1)
        XCTAssertEqual(state.checkInCount, 1)
    }

    func testBackFillWindowIsSevenDays() {
        var state = hatched()
        state.sync(journal: journal(drinkFree: [-9, -8, -7, -1]), today: today).ignore()
        XCTAssertEqual(state.position, 2, "only days on or after today - 7 earn")
        XCTAssertNil(state.steps[StepKey(.checkIn, day(-8))])
        XCTAssertNotNil(state.steps[StepKey(.checkIn, day(-7))])
        // A day back-filled later, still inside the window, earns then.
        let events = state.sync(journal: journal(drinkFree: [-9, -8, -7, -5, -1]), today: today)
        XCTAssertEqual(events.newSteps, 1)
        // Nothing in the future counts.
        XCTAssertEqual(StepPolicy.eligibleSteps(journal: journal(drinkFree: [0]), today: day(-1)), [])
    }

    func testReflectionsAddSteps() {
        var state = hatched()
        state.sync(journal: journal(drinkFree: [0]), today: today).ignore()
        XCTAssertEqual(state.position, 1)
        let events = state.sync(journal: journal(drinkFree: [0], reflections: [0]), today: today)
        XCTAssertEqual(events.newSteps, 1)
        XCTAssertEqual(state.position, 2)
        XCTAssertEqual(state.checkInCount, 1)
        XCTAssertNotNil(state.steps[StepKey(.reflection, today)])
    }

    func testEditsNeverRewindTheTrail() {
        var state = hatched()
        state.sync(journal: journal(drinkFree: [-2, -1, 0], reflections: [0]), today: today).ignore()
        let before = state
        let events = state.sync(journal: Journal(), today: today)
        XCTAssertTrue(events.isEmpty)
        XCTAssertEqual(state, before)
        XCTAssertEqual(state.position, 4)
        XCTAssertNotNil(state.found["shore-pouch"])
    }

    func testResyncIsIdempotent() {
        var state = WanderState.starting(petName: "Sprout")
        let log = journal(drinkFree: [-6, -5, -4, -3, -2, -1, 0], reflections: [-1, 0])
        let first = state.sync(journal: log, today: today)
        XCTAssertFalse(first.isEmpty)
        let afterFirst = state
        let second = state.sync(journal: log, today: today)
        XCTAssertEqual(second, WanderEvents())
        XCTAssertEqual(state, afterFirst)
    }

    // MARK: Landmarks

    func testLandmarksAreFoundAtTheirExactStep() {
        var state = hatched()
        state.sync(journal: journal(drinkFree: [-1]), today: day(-1)).ignore()
        XCTAssertEqual(state.position, 1)
        XCTAssertNil(state.found["shore-shell"])
        XCTAssertEqual(state.nextLandmark?.id, "shore-shell")
        XCTAssertEqual(state.stepsToNextLandmark, 1)
        XCTAssertNil(state.currentArea, "still at the pond")

        let events = state.sync(journal: journal(drinkFree: [-1, 0]), today: today)
        XCTAssertEqual(events.newlyFound.map(\.id), ["shore-shell"])
        XCTAssertEqual(state.found["shore-shell"], today)
        XCTAssertEqual(state.nextLandmark?.id, "shore-pouch")
        XCTAssertEqual(state.stepsToNextLandmark, 2)
        XCTAssertEqual(state.currentArea?.id, "pond-shore")
        XCTAssertEqual(state.foundLandmarks.map(\.id), ["shore-shell"])
    }

    func testTrailIsOrderedWithUniqueIDs() {
        let landmarks = Trail.landmarks
        XCTAssertEqual(Set(landmarks.map(\.id)).count, landmarks.count)
        XCTAssertEqual(landmarks.map(\.step), landmarks.map(\.step).sorted())
        XCTAssertEqual(Trail.areas.map(\.id), ["pond-shore", "reed-bed", "willow-grove", "mossy-woods", "mushroom-glade", "meadow"])
        XCTAssertEqual(Trail.length, 60)
        XCTAssertEqual(Trail.area(of: "reeds-fox")?.name, "Reed Bed")
        for landmark in landmarks {
            if case .egg(let speciesID) = landmark.content { XCTAssertNotNil(Species.with(id: speciesID), landmark.id) }
        }
    }

    func testVisitorsWaitUntilSeen() {
        var state = hatched()
        let base = day(-20)
        for n in 0..<10 {
            state.sync(journal: journal(drinkFree: Array(0...n), from: base), today: day(n, from: base)).ignore()
        }
        XCTAssertEqual(state.position, 10)
        XCTAssertEqual(state.unseenVisitors.map(\.id), ["reeds-fox"])
        state.markVisitorSeen("fox-at-dusk")
        XCTAssertEqual(state.unseenVisitors, [])
    }

    // MARK: Eggs, nest and hatching

    func testStarterEggHatchesOnTheFirstCheckIn() {
        var state = WanderState.starting(petName: "Sprout")
        XCTAssertEqual(state.nestedEgg?.id, WanderState.starterEggID)
        XCTAssertEqual(state.checkInsUntilHatch, 1)
        XCTAssertNil(state.activePet)

        // Nothing logged: nothing hatches. Onboarding's name is picked up.
        XCTAssertTrue(state.sync(journal: journal(drinkFree: [], petName: "Pip"), today: today).isEmpty)
        XCTAssertEqual(state.nestedEgg?.name, "Pip")

        let events = state.sync(journal: journal(drinkFree: [0], petName: "Pip"), today: today)
        XCTAssertEqual(events.hatched.map(\.name), ["Pip"])
        XCTAssertEqual(events.hatched.first?.speciesID, "pondling")
        XCTAssertEqual(events.hatched.first?.hatchedOn, today)
        XCTAssertEqual(state.pendingHatch, WanderState.starterEggID)
        XCTAssertEqual(state.activePetID, WanderState.starterEggID)
        XCTAssertNil(state.nestedEgg)
        XCTAssertEqual(state.eggs, [])
    }

    func testStarterHatchesAtOnceWhenTheJournalAlreadyHasCheckIns() {
        var state = WanderState.starting(petName: "Sprout")
        let events = state.sync(journal: journal(drinkFree: [-3, -2]), today: today)
        XCTAssertEqual(events.hatched.map(\.id), [WanderState.starterEggID])
        XCTAssertEqual(state.activePet?.name, "Sprout")
    }

    func testHatchTiming() {
        let moth = Egg(id: "reeds-egg-moth", speciesID: "moth", nestedAtCheckIn: 0)
        var state = WanderState(eggs: [moth], pets: [sprout], activePetID: sprout.id)
        XCTAssertEqual(state.checkInsUntilHatch, 3)
        let base = day(-10)
        var hatchedEachDay: [[String]] = []
        for n in 0..<3 {
            let events = state.sync(journal: journal(drinkFree: Array(0...n), from: base), today: day(n, from: base))
            hatchedEachDay.append(events.hatched.map(\.id))
            if n < 2 { XCTAssertEqual(state.checkInsUntilHatch, 2 - n) }
        }
        XCTAssertEqual(hatchedEachDay, [[], [], ["reeds-egg-moth"]])
        XCTAssertEqual(state.pet(id: "reeds-egg-moth")?.name, "Lilac moth", "named after its species")
        XCTAssertEqual(state.pendingHatch, "reeds-egg-moth")
        XCTAssertEqual(state.activePetID, sprout.id, "the active pet stays")
        XCTAssertNil(state.checkInsUntilHatch)
    }

    func testEggQueueAndNest() throws {
        var state = WanderState.starting(petName: "Sprout")
        // A week of check-ins and reflections: 16 steps in one sync. The pet
        // stops at the Heron's Inlet fork (step 11) with 5 steps saved.
        let first = state.sync(journal: journal(drinkFree: Array(-7...0), reflections: Array(-7...0)), today: today)
        XCTAssertEqual(first.newSteps, 16)
        XCTAssertEqual(first.newlyFound.map(\.id), [
            "shore-shell", "shore-pouch", "shore-bench", "reeds-egg-moth", "reeds-fox",
        ])
        XCTAssertEqual(first.reachedFork?.id, "reeds-inlet")
        XCTAssertEqual(state.walk.savedSteps, 5)
        XCTAssertEqual(first.hatched.map(\.id), [WanderState.starterEggID])
        XCTAssertEqual(state.nestedEgg?.id, "reeds-egg-moth", "the next egg moves into the nest")
        XCTAssertEqual(state.nestedEgg?.nestedAtCheckIn, 8, "and starts its count now")
        XCTAssertEqual(state.checkInsUntilHatch, 3)
        XCTAssertNoThrow(try state.name(petID: WanderState.starterEggID, "Sprout"))

        // Staying on the trail walks the saved steps at once.
        let passed = try state.choose(at: "reeds-inlet", explore: false, today: today)
        XCTAssertEqual(passed.newlyFound.map(\.id), ["reeds-pouch"])
        XCTAssertEqual(state.walk.mainStep, 16)

        // The next week: 16 more. The moth hatches; the pet waits at the
        // Hollow Willow fork; passing it reaches the turtle and the seal: the
        // turtle takes the nest and the seal waits in the basket.
        let nextWeek = day(8)
        let second = state.sync(
            journal: journal(drinkFree: Array(-7...0), reflections: Array(-7...0), from: nextWeek),
            today: nextWeek
        )
        XCTAssertEqual(second.newSteps, 16)
        XCTAssertEqual(state.position, 32)
        XCTAssertEqual(second.newlyFound.map(\.id), ["willow-lantern"])
        XCTAssertEqual(second.reachedFork?.id, "willow-hollow")
        XCTAssertEqual(second.hatched.map(\.id), ["reeds-egg-moth"], "at most one egg hatches per sync")
        let onward = try state.choose(at: "willow-hollow", explore: false, today: nextWeek)
        XCTAssertEqual(onward.newlyFound.map(\.id), ["willow-egg-turtle", "willow-pouch", "woods-egg-seal"])
        XCTAssertEqual(state.walk.mainStep, 32)
        XCTAssertEqual(state.eggs.map(\.id), ["willow-egg-turtle", "woods-egg-seal"])
        XCTAssertEqual(state.nestedEgg?.nestedAtCheckIn, 16)
        XCTAssertEqual(state.basket.map(\.id), ["woods-egg-seal"])
        XCTAssertNil(state.basket.first?.nestedAtCheckIn)
        XCTAssertEqual(state.pets.map(\.id), [WanderState.starterEggID, "reeds-egg-moth"])
        XCTAssertEqual(state.activePetID, WanderState.starterEggID)
    }

    // MARK: Pets

    func testNamingAndChoosingPets() throws {
        var state = WanderState.starting(petName: "Sprout")
        state.sync(journal: journal(drinkFree: [0]), today: today).ignore()
        XCTAssertEqual(state.pendingHatch, WanderState.starterEggID)

        XCTAssertThrowsError(try state.name(petID: "nobody", "Dot")) {
            XCTAssertEqual($0 as? WanderState.Problem, .unknownPet)
        }
        XCTAssertThrowsError(try state.name(petID: WanderState.starterEggID, "   ")) {
            XCTAssertEqual($0 as? WanderState.Problem, .emptyName)
        }
        XCTAssertEqual(state.pendingHatch, WanderState.starterEggID, "a refused name leaves the moment waiting")

        try state.name(petID: WanderState.starterEggID, "  Pip ")
        XCTAssertEqual(state.activePet?.name, "Pip")
        XCTAssertNil(state.pendingHatch)

        XCTAssertThrowsError(try state.setActive(petID: "reeds-egg-moth")) {
            XCTAssertEqual($0 as? WanderState.Problem, .unknownPet)
        }
        XCTAssertEqual(state.activePetID, WanderState.starterEggID)
    }

    func testSetActiveChoosesAnotherPet() throws {
        let dot = Pet(id: "reeds-egg-moth", speciesID: "moth", name: "Dot", hatchedOn: today)
        var state = WanderState(pets: [sprout, dot], activePetID: sprout.id)
        try state.setActive(petID: dot.id)
        XCTAssertEqual(state.activePet, dot)
        XCTAssertEqual(state.activePet?.species, Species.moth)
    }

    func testInitKeepsTheInvariants() {
        let dot = Pet(id: "reeds-egg-moth", speciesID: "moth", name: "Dot", hatchedOn: today)
        let state = WanderState(
            eggs: [
                Egg(id: "willow-egg-turtle", speciesID: "turtle", nestedAtCheckIn: 3),
                Egg(id: "woods-egg-seal", speciesID: "seal", nestedAtCheckIn: 4),
                Egg(id: "reeds-egg-moth", speciesID: "moth"),
                Egg(id: "mystery", speciesID: "dragon"),
            ],
            pets: [sprout, dot, sprout],
            activePetID: "gone",
            pendingHatch: "gone"
        )
        XCTAssertEqual(state.pets.map(\.id), [sprout.id, dot.id])
        XCTAssertEqual(state.eggs.map(\.id), ["willow-egg-turtle", "woods-egg-seal"], "hatched and unknown eggs dropped")
        XCTAssertNil(state.eggs[1].nestedAtCheckIn, "only one egg in the nest")
        XCTAssertEqual(state.activePetID, sprout.id)
        XCTAssertNil(state.pendingHatch)
        XCTAssertNil(WanderState().activePetID)
    }
}

extension WanderEvents {
    /// Marks a sync whose events a test doesn't look at.
    func ignore() {}
}
