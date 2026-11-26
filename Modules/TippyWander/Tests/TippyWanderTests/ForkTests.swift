import XCTest
import TippyModeration
@testable import TippyWander

/// Forks and side paths (spec 07): the pet waits at a fork with her steps
/// saved, a side path loops back to its fork, and a passed one stays open.
final class ForkTests: XCTestCase {
    let today = LocalDate("2026-11-19")!

    var sprout: Pet {
        Pet(id: WanderState.starterEggID, speciesID: "pondling", name: "Sprout", hatchedOn: today.adding(days: -200))
    }

    /// A hatched Wander with `count` steps from long ago (so later syncs can
    /// add more), caught up along `route`.
    func wander(steps count: Int, route: [RouteChoice] = []) -> WanderState {
        let old = (0..<count).map { offset -> StepAward in
            let day = today.adding(days: -150 + offset)
            return StepAward(key: StepKey(.checkIn, day), awardedOn: day)
        }
        var state = WanderState(steps: old, pets: [sprout], activePetID: sprout.id, route: route)
        _ = state.sync(journal: Journal(), today: today)
        return state
    }

    /// Earns `count` (1...8) new check-in steps, on days after every earlier call.
    private var nextDay = 0
    func earn(_ count: Int, _ state: inout WanderState) -> WanderEvents {
        nextDay += 10
        let end = today.adding(days: nextDay)
        let days = Set((0..<count).map { end.adding(days: -$0) })
        return state.sync(journal: Journal(drinkFreeDays: days), today: end)
    }

    // MARK: Content

    func testForksSitBetweenLandmarksWithUniqueIDs() {
        let all = Trail.allLandmarks
        XCTAssertEqual(Set(all.map(\.id)).count, all.count, "landmark IDs are unique across every path")
        XCTAssertEqual(all.count, Trail.landmarks.count + 8)
        XCTAssertEqual(Trail.forks.map(\.id), ["reeds-inlet", "willow-hollow", "woods-ferns", "glade-ring"])
        XCTAssertEqual(Trail.forks.map(\.mainStep), Trail.forks.map(\.mainStep).sorted())
        let mainSteps = Set(Trail.landmarks.map(\.step))
        for fork in Trail.forks {
            XCTAssertFalse(mainSteps.contains(fork.mainStep), "\(fork.id) is not on a landmark")
            XCTAssertNotNil(Trail.areas.first { $0.id == fork.areaID }, fork.id)
            XCTAssertTrue((4...7).contains(fork.sidePath.length), fork.id)
            for landmark in fork.sidePath.landmarks {
                XCTAssertTrue((1..<fork.sidePath.length).contains(landmark.step), landmark.id)
                XCTAssertEqual(Trail.fork(ofLandmark: landmark.id)?.id, fork.id)
                XCTAssertEqual(Trail.area(of: landmark.id)?.id, fork.areaID)
                XCTAssertEqual(Trail.landmark(id: landmark.id), landmark)
            }
        }
        // Side landmarks follow their fork in trail order.
        let ids = all.map(\.id)
        XCTAssertEqual(Array(ids[5...7]), ["inlet-pouch", "inlet-cairn", "reeds-pouch"])
    }

    // MARK: Waiting

    func testThePetWaitsAtAForkWithItsStepsSaved() {
        var state = wander(steps: 9)
        let events = earn(4, &state)
        XCTAssertEqual(events.newSteps, 4)
        XCTAssertEqual(events.newlyFound.map(\.id), ["reeds-fox"])
        XCTAssertEqual(events.reachedFork?.id, "reeds-inlet")
        let walk = state.walk
        XCTAssertEqual(walk.spot, .main(step: 11))
        XCTAssertEqual(walk.waitingAt?.id, "reeds-inlet")
        XCTAssertEqual(walk.stepsUsed, 11)
        XCTAssertEqual(walk.savedSteps, 2)
        XCTAssertNil(state.nextLandmark, "nothing ahead until she chooses")
        XCTAssertNil(state.found["reeds-pouch"])
        // More steps while waiting are saved too, and nothing is reported twice.
        let more = earn(1, &state)
        XCTAssertEqual(more.newSteps, 1)
        XCTAssertNil(more.reachedFork)
        XCTAssertEqual(state.walk.savedSteps, 3)
        XCTAssertTrue(state.sync(journal: Journal(), today: today).isEmpty, "re-syncing changes nothing")
    }

    func testNextForkIsAnnouncedBeforeTheWalkGetsThere() {
        let state = wander(steps: 10)
        XCTAssertEqual(state.nextFork?.fork.id, "reeds-inlet")
        XCTAssertEqual(state.nextFork?.steps, 1)
        XCTAssertNil(self.wander(steps: 9).nextFork, "the fox's landmark comes first")
    }

    // MARK: Choosing

    func testExploreWalksTheLoopAndComesBack() throws {
        var state = wander(steps: 13)
        let explored = try state.choose(at: "reeds-inlet", explore: true, today: today)
        XCTAssertEqual(explored.newlyFound.map(\.id), ["inlet-pouch"])
        XCTAssertEqual(state.walk.spot, .side(forkID: "reeds-inlet", step: 2))
        XCTAssertEqual(state.walk.excursion?.id, "reeds-inlet")
        XCTAssertNil(state.walk.waitingAt)
        XCTAssertEqual(state.nextLandmark?.id, "inlet-cairn")
        XCTAssertEqual(state.stepsToNextLandmark, 2)
        XCTAssertEqual(state.currentArea?.id, "reed-bed")

        // Three more: the cairn, then the step back to the fork.
        let back = earn(3, &state)
        XCTAssertEqual(back.newlyFound.map(\.id), ["inlet-cairn"])
        XCTAssertEqual(back.excursionDone?.id, "reeds-inlet")
        XCTAssertEqual(state.walk.spot, .main(step: 11))
        XCTAssertNil(state.walk.excursion)
        XCTAssertNil(state.walk.waitingAt, "a fork is chosen at once")
        XCTAssertEqual(state.walk.openForks, [])

        // On along the main trail.
        let onward = earn(2, &state)
        XCTAssertEqual(onward.newlyFound.map(\.id), ["reeds-pouch"])
        XCTAssertEqual(state.walk.mainStep, 13)
        XCTAssertEqual(state.route, [.explore(forkID: "reeds-inlet")])
    }

    func testPassContinuesAndKeepsThePathOpen() throws {
        var state = wander(steps: 13)
        let passed = try state.choose(at: "reeds-inlet", explore: false, today: today)
        XCTAssertEqual(passed.newlyFound.map(\.id), ["reeds-pouch"])
        XCTAssertEqual(state.walk.spot, .main(step: 13))
        XCTAssertEqual(state.walk.openForks.map(\.id), ["reeds-inlet"])
        XCTAssertNil(state.found["inlet-pouch"], "a passed path's finds wait for a visit")
    }

    func testChoosingOnlyAtTheForkThePetIsWaitingAt() {
        var walking = wander(steps: 5)
        XCTAssertThrowsError(try walking.choose(at: "reeds-inlet", explore: true, today: today)) {
            XCTAssertEqual($0 as? WanderState.Problem, .notWaitingAtFork)
        }
        var waiting = wander(steps: 12)
        XCTAssertThrowsError(try waiting.choose(at: "willow-hollow", explore: true, today: today)) {
            XCTAssertEqual($0 as? WanderState.Problem, .notWaitingAtFork)
        }
        XCTAssertNoThrow(try waiting.choose(at: "reeds-inlet", explore: true, today: today))
        XCTAssertThrowsError(try waiting.choose(at: "reeds-inlet", explore: false, today: today), "a choice stands")
    }

    func testChoosingLaterGivesTheSameWalk() throws {
        // Choose with two steps saved...
        var later = wander(steps: 13)
        _ = try later.choose(at: "reeds-inlet", explore: true, today: today)
        // ...or as soon as the pet arrives, then earn the same two.
        var atOnce = wander(steps: 11)
        _ = try atOnce.choose(at: "reeds-inlet", explore: true, today: today)
        XCTAssertEqual(atOnce.walk.spot, .side(forkID: "reeds-inlet", step: 0))
        _ = earn(2, &atOnce)
        XCTAssertEqual(later.walk.spot, atOnce.walk.spot)
        XCTAssertEqual(Set(later.found.keys), Set(atOnce.found.keys))
    }

    // MARK: Revisiting

    func testRevisitWalksAPassedPathAndReturns() throws {
        var state = wander(steps: 15, route: [.pass(forkID: "reeds-inlet")])
        XCTAssertEqual(state.walk.mainStep, 15)
        XCTAssertEqual(state.walk.openForks.map(\.id), ["reeds-inlet"])

        let started = try state.revisit("reeds-inlet", today: today)
        XCTAssertTrue(started.newlyFound.isEmpty, "no saved steps: it waits for the next ones")
        XCTAssertEqual(state.walk.spot, .side(forkID: "reeds-inlet", step: 0))
        XCTAssertEqual(state.walk.excursion?.id, "reeds-inlet")
        XCTAssertEqual(state.walk.mainStep, 15, "its place on the main trail is kept")
        XCTAssertEqual(state.route.last, .revisit(forkID: "reeds-inlet", afterSteps: 15))

        let loop = earn(5, &state)
        XCTAssertEqual(loop.newlyFound.map(\.id), ["inlet-pouch", "inlet-cairn"])
        XCTAssertEqual(state.walk.spot, .main(step: 15), "and it hops back where it was")
        XCTAssertEqual(state.walk.openForks, [])
        XCTAssertThrowsError(try state.revisit("reeds-inlet", today: today)) {
            XCTAssertEqual($0 as? WanderState.Problem, .pathNotOpen)
        }
        XCTAssertEqual(earn(1, &state).newlyFound.map(\.id), [], "then on along the trail")
        XCTAssertEqual(state.walk.mainStep, 16)
    }

    func testOneSidePathAtATime() throws {
        var state = wander(steps: 21, route: [.pass(forkID: "reeds-inlet"), .pass(forkID: "willow-hollow")])
        XCTAssertEqual(state.walk.openForks.map(\.id), ["reeds-inlet", "willow-hollow"])
        _ = try state.revisit("willow-hollow", today: today)
        XCTAssertThrowsError(try state.revisit("reeds-inlet", today: today)) {
            XCTAssertEqual($0 as? WanderState.Problem, .onExcursion)
        }
        XCTAssertThrowsError(try state.revisit("woods-ferns", today: today), "not reached yet")
    }

    func testARevisitCanUseStepsSavedAtAFork() throws {
        // Waiting at the Hollow Willow with 3 saved; the inlet was passed.
        var state = wander(steps: 22, route: [.pass(forkID: "reeds-inlet")])
        XCTAssertEqual(state.walk.waitingAt?.id, "willow-hollow")
        XCTAssertEqual(state.walk.savedSteps, 3)
        let events = try state.revisit("reeds-inlet", today: today)
        XCTAssertEqual(events.newlyFound.map(\.id), ["inlet-pouch"])
        XCTAssertEqual(state.walk.spot, .side(forkID: "reeds-inlet", step: 3))
        _ = earn(2, &state)
        XCTAssertEqual(state.walk.spot, .main(step: 19))
        XCTAssertEqual(state.walk.waitingAt?.id, "willow-hollow", "back at the fork it was waiting at")
    }

    // MARK: Finds reach Rewards

    func testSideFindsAreFoundOnceAndListedInTrailOrder() throws {
        var state = wander(steps: 16)
        _ = try state.choose(at: "reeds-inlet", explore: true, today: today)
        XCTAssertEqual(state.foundLandmarks.suffix(3).map(\.id), ["reeds-fox", "inlet-pouch", "inlet-cairn"])
        XCTAssertTrue(state.sync(journal: Journal(), today: today).isEmpty)
        let pouches = state.foundLandmarks.filter { if case .pouch = $0.content { return true } else { return false } }
        XCTAssertEqual(pouches.map(\.id), ["shore-pouch", "inlet-pouch"])
    }

    // MARK: Saving

    func testRouteRoundTrips() throws {
        var state = wander(steps: 15, route: [.pass(forkID: "reeds-inlet")])
        _ = try state.revisit("reeds-inlet", today: today)
        let decoded = try WanderCodec.decode(WanderCodec.encode(state))
        XCTAssertEqual(decoded, state)
        XCTAssertEqual(decoded.walk, state.walk)
    }

    func testVersionOneNeverMovesThePetBack() throws {
        func v1(steps count: Int) -> Data {
            let steps = (0..<count).map { offset -> String in
                let day = today.adding(days: -30 + offset)
                return #"{ "key": "checkIn:\#(day)", "awardedOn": "\#(day)" }"#
            }
            return Data(#"{ "version": 1, "steps": [\#(steps.joined(separator: ","))], "found": {} }"#.utf8)
        }
        let past = try WanderCodec.decode(v1(steps: 20))
        XCTAssertEqual(past.route, [.pass(forkID: "reeds-inlet"), .pass(forkID: "willow-hollow")])
        XCTAssertEqual(past.walk.spot, .main(step: 20))
        XCTAssertEqual(past.walk.openForks.map(\.id), ["reeds-inlet", "willow-hollow"])

        let atFork = try WanderCodec.decode(v1(steps: 11))
        XCTAssertEqual(atFork.route, [], "standing on the fork: it waits there")
        XCTAssertEqual(atFork.walk.waitingAt?.id, "reeds-inlet")

        // A version 2 file keeps exactly the route it saved.
        let current = try WanderCodec.decode(WanderCodec.encode(atFork))
        XCTAssertEqual(current.route, [])
    }

    func testUnknownForksInARouteAreDropped() {
        let state = WanderState(route: [.pass(forkID: "nowhere"), .pass(forkID: "reeds-inlet")])
        XCTAssertEqual(state.route, [.pass(forkID: "reeds-inlet")])
    }
}
