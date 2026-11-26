import Foundation
import Observation
import TippyModeration
import TippyWander

/// The Wander's application model: the trail, the nest and the pets, kept in
/// step with the journal through its change hook (wired in the composition
/// root), and the one place the Wander is changed and saved. Domain rules
/// live in TippyWander; this only orchestrates.
@MainActor
@Observable
final class WanderModel {
    private(set) var state: WanderState
    /// What the latest sync that produced anything produced, for the UI to replay.
    private(set) var lastEvents = WanderEvents()
    /// Finds the find card hasn't shown yet, oldest first. Each find is
    /// reported by exactly one sync, so each card shows once.
    private(set) var unannouncedFinds: [Landmark] = []
    /// Something to tell the user (a refused name, a failed save).
    var message: String?

    private let store: any WanderStore
    /// Called after a choice on the map changed what's found, so the
    /// coordinator can pass the new finds to Rewards (as it does after a sync).
    private var findsChanged: [@MainActor () -> Void] = []

    /// `starterPetName` names the starter egg when there's no saved Wander
    /// yet (first run, or the first run after the Wander shipped).
    init(store: any WanderStore, starterPetName: String) {
        self.store = store
        var loaded = WanderState.starting(petName: starterPetName)
        var problem: String?
        do {
            if let saved = try store.load() { loaded = saved }
        } catch {
            problem = "Tippy couldn't read the Wander's saved data, so it started a new one. The unreadable file was kept aside."
        }
        self.state = loaded
        self.message = problem
    }

    // MARK: Derived state

    var position: Int { state.position }
    /// Where the pet is along her route (spec 07).
    var walk: Walk { state.walk }
    var activePet: Pet? { state.activePet }
    var activeSpecies: Species { activePet?.species ?? .pondling }

    /// The pet that waits for its hatch moment, if any.
    var hatchingPet: Pet? { state.pendingHatch.flatMap { state.pet(id: $0) } }

    /// The pet to show in the camp: the active pet, unless it hatched in a
    /// sync whose hatch moment hasn't played yet (it is still "in the egg"
    /// until then, so nothing spoils the moment).
    var shownPet: Pet? {
        guard let pet = activePet, pet.id != state.pendingHatch else { return nil }
        return pet
    }

    var nextLandmark: Landmark? { state.nextLandmark }
    var stepsToNext: Int? { state.stepsToNextLandmark }
    var currentArea: Area? { state.currentArea }

    /// The nested egg and the check-ins left before it hatches.
    var nest: NestStatus? {
        guard let egg = state.nestedEgg, let left = state.checkInsUntilHatch else { return nil }
        return NestStatus(egg: egg, species: egg.species ?? .pondling, checkInsLeft: left)
    }

    func isFound(_ landmark: Landmark) -> Bool { state.found[landmark.id] != nil }

    /// The first visitor found and not yet met, by visitor ID ("fox-at-dusk").
    var unseenVisitorID: String? {
        for landmark in state.unseenVisitors {
            if case .visitor(let id) = landmark.content { return id }
        }
        return nil
    }

    // MARK: Commands

    /// Catches up with the journal (the journal change hook calls this).
    /// Saves only when something changed.
    @discardableResult
    func sync(journal: Journal, today: LocalDate) -> WanderEvents {
        let events = mutate { $0.sync(journal: journal, today: today) } ?? WanderEvents()
        if !events.isEmpty {
            lastEvents = events
            unannouncedFinds.append(contentsOf: events.newlyFound)
        }
        return events
    }

    /// The coordinator subscribes here to hear about finds made outside a sync.
    func onFindsChanged(_ handler: @escaping @MainActor () -> Void) {
        findsChanged.append(handler)
    }

    /// Her choice at the fork the pet is waiting at.
    @discardableResult
    func choose(at forkID: String, explore: Bool, today: LocalDate) -> Bool {
        routeChanged(mutate { try $0.choose(at: forkID, explore: explore, today: today) })
    }

    /// Sends the pet down a passed side path.
    @discardableResult
    func revisit(_ forkID: String, today: LocalDate) -> Bool {
        routeChanged(mutate { try $0.revisit(forkID, today: today) })
    }

    private func routeChanged(_ events: WanderEvents?) -> Bool {
        guard let events else { return false }
        if !events.newlyFound.isEmpty {
            lastEvents = events
            unannouncedFinds.append(contentsOf: events.newlyFound)
            for handler in findsChanged { handler() }
        }
        return true
    }

    /// Names a pet; naming the hatching pet ends its hatch moment.
    @discardableResult
    func name(_ petID: String, _ name: String) -> Bool {
        mutate { try $0.name(petID: petID, name) } != nil
    }

    @discardableResult
    func setActive(_ petID: String) -> Bool {
        mutate { try $0.setActive(petID: petID) } != nil
    }

    func markVisitorSeen(_ id: String) {
        mutate { $0.markVisitorSeen(id) }
    }

    /// The find card for this landmark has been shown (on Home or the map).
    func announceFind(_ landmarkID: String) {
        unannouncedFinds.removeAll { $0.id == landmarkID }
    }

    // MARK: Restore

    /// Replaces the Wander wholesale (a restore). Saves first and throws if that
    /// fails. Nothing restored is news, so no find cards or replays.
    func replace(with state: WanderState) throws {
        try store.save(state)
        self.state = state
        lastEvents = WanderEvents()
        unannouncedFinds = []
    }

    // MARK: Plumbing

    /// The single path for every change: apply it to a copy through the
    /// aggregate, commit on success, and save if anything changed. Returns
    /// nil (with `message` set) when the change was refused.
    @discardableResult
    private func mutate<Result>(_ change: (inout WanderState) throws -> Result) -> Result? {
        var copy = state
        let result: Result
        do {
            result = try change(&copy)
        } catch let problem as WanderState.Problem {
            message = problem.message
            return nil
        } catch {
            message = error.localizedDescription
            return nil
        }
        guard copy != state else { return result }
        state = copy
        do {
            try store.save(copy)
        } catch {
            message = "Couldn't save the Wander: \(error.localizedDescription)"
        }
        return result
    }
}

/// The egg in the nest, for the nest view.
struct NestStatus: Equatable {
    let egg: Egg
    let species: Species
    /// At least 1: an egg hatches during the sync that reaches its count.
    let checkInsLeft: Int
}

extension WanderState.Problem {
    var message: String {
        switch self {
        case .unknownPet: return "That pet isn't in your collection."
        case .emptyName: return "Give your pet a name first."
        case .notWaitingAtFork: return "That fork isn't where your pet is waiting."
        case .pathNotOpen: return "That path isn't open to explore."
        case .onExcursion: return "Your pet is already exploring a side path."
        }
    }
}
