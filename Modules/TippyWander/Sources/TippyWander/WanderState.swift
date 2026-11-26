import Foundation
import TippyModeration

/// The Wander aggregate: the step ledger, what has been found on the trail,
/// the eggs (nest first, then the basket), the pets and the active pet. All
/// changes go through its methods, which keep the invariants:
/// - at most one egg is nested, and it is `eggs[0]`;
/// - pet IDs are unique, and no egg shares an ID with a pet;
/// - `activePetID` is nil or names a pet; so does `pendingHatch`;
/// - found landmarks are never un-found, and steps are never removed, so
///   editing the journal never rewinds the trail or un-hatches anything;
/// - the route only grows (spec 07), so the pet never walks backwards.
/// The trail position (the number of steps) and the walk (where those steps
/// took the pet along her route) are derived, never stored.
public struct WanderState: Hashable, Sendable {
    /// 2 adds the route (forks and side paths, spec 07).
    public static let currentVersion = 2
    /// The egg every Wander starts with, and the pondling that hatches from it.
    public static let starterEggID = "starter"

    public enum Problem: Error, Equatable, Sendable {
        case unknownPet
        case emptyName
        /// A way can only be chosen at the fork the pet is waiting at.
        case notWaitingAtFork
        /// Only a passed side path not walked yet can be revisited.
        case pathNotOpen
        /// One side path at a time.
        case onExcursion
    }

    /// Once-only: `checkIn:<day>` and `reflection:<day>`.
    public private(set) var steps: [StepKey: StepAward]
    /// Landmark ID -> the day it was found.
    public private(set) var found: [String: LocalDate]
    /// The nest first (index 0, when nested), then the basket.
    public private(set) var eggs: [Egg]
    public private(set) var pets: [Pet]
    public private(set) var activePetID: String?
    /// Visitor IDs ("fox-at-dusk") whose visit she has seen.
    public private(set) var seenVisitors: Set<String>
    /// A pet waiting for its naming moment.
    public private(set) var pendingHatch: String?
    /// Her choices at forks and her revisits, in order; append-only.
    public private(set) var route: [RouteChoice]

    /// A state from saved or seeded parts, repaired to keep the invariants
    /// (as `Journal.init` does): duplicates dropped, only the first egg may
    /// be nested, eggs of unknown species or already hatched are dropped, and
    /// an unknown active pet falls back to the first pet.
    public init(
        steps: [StepAward] = [],
        found: [String: LocalDate] = [:],
        eggs: [Egg] = [],
        pets: [Pet] = [],
        activePetID: String? = nil,
        seenVisitors: Set<String> = [],
        pendingHatch: String? = nil,
        route: [RouteChoice] = []
    ) {
        var petIDs = Set<String>()
        var uniquePets: [Pet] = []
        for pet in pets where !petIDs.contains(pet.id) {
            petIDs.insert(pet.id)
            uniquePets.append(pet)
        }
        var eggIDs = petIDs
        var kept: [Egg] = []
        for egg in eggs where egg.species != nil && !eggIDs.contains(egg.id) {
            eggIDs.insert(egg.id)
            var copy = egg
            if !kept.isEmpty { copy.nestedAtCheckIn = nil }
            kept.append(copy)
        }
        let active: String?
        if let activePetID, petIDs.contains(activePetID) {
            active = activePetID
        } else {
            active = uniquePets.first?.id
        }
        var pending: String? = nil
        if let pendingHatch, petIDs.contains(pendingHatch) { pending = pendingHatch }

        self.steps = Dictionary(steps.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        self.found = found
        self.eggs = kept
        self.pets = uniquePets
        self.activePetID = active
        self.seenVisitors = seenVisitors
        self.pendingHatch = pending
        self.route = route.filter { Trail.fork(id: $0.forkID) != nil }
    }

    /// A new Wander: the starter pondling egg in the nest, to be named
    /// `petName` (her answer in onboarding) when it hatches.
    public static func starting(petName: String) -> WanderState {
        let name = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        let starter = Egg(
            id: starterEggID,
            speciesID: Species.pondling.id,
            nestedAtCheckIn: 0,
            name: name.isEmpty ? nil : name
        )
        return WanderState(eggs: [starter])
    }

    // MARK: Derived

    /// The trail position: one per step, never stored. Where those steps
    /// took the pet is `walk`.
    public var position: Int { steps.count }

    /// Where the pet is along her route, and whether it waits at a fork.
    public var walk: Walk { RoutePolicy.walk(steps: position, route: route) }

    /// Every spot walked, in order, one per step used.
    public var walkedPath: [TrailSpot] { RoutePolicy.path(steps: position, route: route) }

    public var checkInCount: Int { steps.keys.filter { $0.kind == .checkIn }.count }

    /// The next landmark ahead of the pet that isn't found yet: on the side
    /// path it's walking, else on the main trail. Nil while it waits at a
    /// fork (see `walk.waitingAt`) and at the trail's end.
    public var nextLandmark: Landmark? {
        let walk = self.walk
        if walk.waitingAt != nil { return nil }
        if let fork = walk.excursion, case .side(_, let at) = walk.spot,
           let next = fork.sidePath.landmarks.first(where: { $0.step > at && found[$0.id] == nil }) {
            return next
        }
        return Trail.landmarks.first { $0.step > walk.mainStep && found[$0.id] == nil }
    }

    /// Steps still to walk to `nextLandmark`.
    public var stepsToNextLandmark: Int? {
        guard let next = nextLandmark else { return nil }
        let walk = self.walk
        if let fork = walk.excursion, case .side(_, let at) = walk.spot {
            if Trail.fork(ofLandmark: next.id)?.id == fork.id { return max(next.step - at, 0) }
            return (fork.sidePath.length - at) + max(next.step - walk.mainStep, 0)
        }
        return max(next.step - walk.mainStep, 0)
    }

    /// The next fork ahead on the main trail that she hasn't chosen at yet,
    /// and the steps to it, when it comes before the next landmark.
    public var nextFork: (fork: Fork, steps: Int)? {
        let walk = self.walk
        guard walk.waitingAt == nil, walk.excursion == nil,
              let fork = Trail.forks.first(where: { $0.mainStep > walk.mainStep }),
              !route.contains(where: { $0.forkID == fork.id }) else { return nil }
        if let next = nextLandmark, Trail.fork(ofLandmark: next.id) == nil, next.step < fork.mainStep { return nil }
        return (fork, fork.mainStep - walk.mainStep)
    }

    /// Everything found so far, main trail and side paths, in trail order.
    /// The app layer replays the decorations and pouches among them into
    /// Rewards (idempotently).
    public var foundLandmarks: [Landmark] {
        Trail.allLandmarks.filter { found[$0.id] != nil }
    }

    /// The area the pet is in: of the side path it's walking, else of the
    /// latest main-trail landmark found; nil before the first find, while the
    /// pet is still at the pond.
    public var currentArea: Area? {
        if let fork = walk.excursion { return Trail.areas.first { $0.id == fork.areaID } }
        return Trail.landmarks.last(where: { found[$0.id] != nil }).flatMap { Trail.area(of: $0.id) }
    }

    /// The egg in the nest, if any.
    public var nestedEgg: Egg? {
        guard let first = eggs.first, first.nestedAtCheckIn != nil else { return nil }
        return first
    }

    /// Eggs waiting for the nest, in the order they were found.
    public var basket: [Egg] {
        nestedEgg == nil ? eggs : Array(eggs.dropFirst())
    }

    /// Check-ins until the nested egg hatches (at least 1); nil with an empty nest.
    public var checkInsUntilHatch: Int? {
        guard let egg = nestedEgg, let nestedAt = egg.nestedAtCheckIn, let species = egg.species else { return nil }
        return max(species.hatchAfterCheckIns - (checkInCount - nestedAt), 1)
    }

    public func pet(id: String) -> Pet? { pets.first { $0.id == id } }

    public var activePet: Pet? { activePetID.flatMap { pet(id: $0) } }

    /// Visitors found on the trail whose visit she hasn't seen yet.
    public var unseenVisitors: [Landmark] {
        foundLandmarks.filter { landmark in
            if case .visitor(let id) = landmark.content { return !seenVisitors.contains(id) }
            return false
        }
    }

    // MARK: Sync

    /// Catches the Wander up with the journal, deterministically:
    /// 1. records new step awards (`StepPolicy`, once each);
    /// 2. walks them along her route (`RoutePolicy`), marking every landmark
    ///    on the way found today; an egg find joins the end of the egg queue.
    ///    At a fork she hasn't chosen at, the pet waits and the rest are saved;
    /// 3. nests the first waiting egg if the nest is empty;
    /// 4. hatches the nested egg once enough check-ins have passed since it
    ///    was nested, then nests the next (which starts its own count, so at
    ///    most one egg hatches per sync).
    /// Syncing the same journal again produces no events.
    public mutating func sync(journal: Journal, today: LocalDate) -> WanderEvents {
        var events = WanderEvents()
        nameStarterEgg(journal.settings.petName)

        let before = walk
        for key in StepPolicy.eligibleSteps(journal: journal, today: today) where steps[key] == nil {
            steps[key] = StepAward(key: key, awardedOn: today)
            events.newSteps += 1
        }
        events.newlyFound = markFinds(today: today)
        noteWalkChanges(from: before, into: &events)

        nestNextEgg()
        while let egg = nestedEgg, let nestedAt = egg.nestedAtCheckIn, let species = egg.species,
              checkInCount - nestedAt >= species.hatchAfterCheckIns {
            if let pet = hatchNestedEgg(species: species, on: today) { events.hatched.append(pet) }
            nestNextEgg()
        }
        return events
    }

    // MARK: Forks (spec 07)

    /// Her choice at the fork the pet is waiting at: down the side path, or
    /// on along the trail. Saved steps are walked at once, so the finds they
    /// reach are reported here.
    public mutating func choose(at forkID: String, explore: Bool, today: LocalDate) throws -> WanderEvents {
        let before = walk
        guard before.waitingAt?.id == forkID else { throw Problem.notWaitingAtFork }
        route.append(explore ? .explore(forkID: forkID) : .pass(forkID: forkID))
        return afterRouteChange(from: before, today: today)
    }

    /// Sends the pet down a passed side path from the map. It hops to the
    /// fork, walks the loop with saved or future steps, and hops back.
    public mutating func revisit(_ forkID: String, today: LocalDate) throws -> WanderEvents {
        let before = walk
        guard before.excursion == nil else { throw Problem.onExcursion }
        guard before.openForks.contains(where: { $0.id == forkID }) else { throw Problem.pathNotOpen }
        route.append(.revisit(forkID: forkID, afterSteps: before.stepsUsed))
        return afterRouteChange(from: before, today: today)
    }

    private mutating func afterRouteChange(from before: Walk, today: LocalDate) -> WanderEvents {
        var events = WanderEvents()
        events.newlyFound = markFinds(today: today)
        noteWalkChanges(from: before, into: &events)
        nestNextEgg()
        return events
    }

    /// Marks every landmark on the walked path that isn't found yet, in walk
    /// order; an egg joins the end of the egg queue.
    private mutating func markFinds(today: LocalDate) -> [Landmark] {
        var newlyFound: [Landmark] = []
        for spot in walkedPath {
            guard let landmark = Trail.landmark(at: spot), found[landmark.id] == nil else { continue }
            found[landmark.id] = today
            newlyFound.append(landmark)
            if case .egg(let speciesID) = landmark.content, Species.with(id: speciesID) != nil,
               !eggs.contains(where: { $0.id == landmark.id }), pet(id: landmark.id) == nil {
                eggs.append(Egg(id: landmark.id, speciesID: speciesID))
            }
        }
        return newlyFound
    }

    private func noteWalkChanges(from before: Walk, into events: inout WanderEvents) {
        let after = walk
        if let fork = after.waitingAt, before.waitingAt?.id != fork.id { events.reachedFork = fork }
        if let fork = before.excursion, after.excursion?.id != fork.id { events.excursionDone = fork }
    }

    /// The unhatched starter takes the pet name from the journal's settings,
    /// so the name she chose in onboarding is the one it hatches with.
    private mutating func nameStarterEgg(_ petName: String) {
        let name = petName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, let index = eggs.firstIndex(where: { $0.id == WanderState.starterEggID }) else { return }
        if eggs[index].name != name { eggs[index].name = name }
    }

    private mutating func nestNextEgg() {
        guard nestedEgg == nil, !eggs.isEmpty else { return }
        eggs[0].nestedAtCheckIn = checkInCount
    }

    private mutating func hatchNestedEgg(species: Species, on day: LocalDate) -> Pet? {
        let egg = eggs.removeFirst()
        guard pet(id: egg.id) == nil else { return nil }
        let given = egg.name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let pet = Pet(id: egg.id, speciesID: species.id, name: given.isEmpty ? species.name : given, hatchedOn: day)
        pets.append(pet)
        pendingHatch = pet.id
        if activePetID == nil { activePetID = pet.id }
        return pet
    }

    // MARK: Pets

    /// Names (or renames) a pet. Naming the pet waiting for its hatch moment
    /// completes that moment.
    public mutating func name(petID: String, _ name: String) throws {
        guard let index = pets.firstIndex(where: { $0.id == petID }) else { throw Problem.unknownPet }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw Problem.emptyName }
        pets[index].name = trimmed
        if pendingHatch == petID { pendingHatch = nil }
    }

    /// Chooses the pet that is out in the camp.
    public mutating func setActive(petID: String) throws {
        guard pet(id: petID) != nil else { throw Problem.unknownPet }
        activePetID = petID
    }

    public mutating func markVisitorSeen(_ id: String) {
        seenVisitors.insert(id)
    }
}

extension WanderState: Codable {
    enum CodingKeys: String, CodingKey {
        case version, steps, found, eggs, pets, activePetID, seenVisitors, pendingHatch, route
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard version <= WanderState.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: c,
                debugDescription: "Saved by a newer Tippy (format \(version)); update the app first."
            )
        }
        let steps = try c.decodeIfPresent([StepAward].self, forKey: .steps) ?? []
        let found = try c.decodeIfPresent([String: LocalDate].self, forKey: .found) ?? [:]
        let eggs = try c.decodeIfPresent([Egg].self, forKey: .eggs) ?? []
        let pets = try c.decodeIfPresent([Pet].self, forKey: .pets) ?? []
        let active = try c.decodeIfPresent(String.self, forKey: .activePetID)
        let seen = try c.decodeIfPresent([String].self, forKey: .seenVisitors) ?? []
        let pending = try c.decodeIfPresent(String.self, forKey: .pendingHatch)
        var route = try c.decodeIfPresent([RouteChoice].self, forKey: .route) ?? []
        if version < 2 {
            // Before forks, the pet walked straight past them. Record those as
            // passed, so it never jumps back, and their side paths stay open.
            let position = Set(steps.map(\.key)).count
            route = Trail.forks.filter { $0.mainStep < position }.map { .pass(forkID: $0.id) }
        }
        self.init(
            steps: steps, found: found, eggs: eggs, pets: pets,
            activePetID: active, seenVisitors: Set(seen), pendingHatch: pending, route: route
        )
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(WanderState.currentVersion, forKey: .version)
        try c.encode(steps.values.sorted { $0.key < $1.key }, forKey: .steps)
        try c.encode(found, forKey: .found)
        try c.encode(eggs, forKey: .eggs)
        try c.encode(pets, forKey: .pets)
        try c.encodeIfPresent(activePetID, forKey: .activePetID)
        try c.encode(seenVisitors.sorted(), forKey: .seenVisitors)
        try c.encodeIfPresent(pendingHatch, forKey: .pendingHatch)
        try c.encode(route, forKey: .route)
    }
}
