# Spec 03: The Wander, eggs and pets

**Goal:** checking in and reflecting move her pet along a trail out from the pond. Along the way it finds eggs,
decorations, coin pouches and a fox visitor. Eggs hatch in the camp's nest after a few more check-ins, and the
hatched pets join a collection she chooses from. This is the long-running reason to come back.

**Depends on:** `main`. **Parallel with:** 01, 02, 05. **Suggested split:**
- **03a:** the domain package, step sync, the trail map, the starter egg and its hatching.
- **03b:** found eggs, the collection, choosing the active pet, the fox visitor, and the cross-context finds.

**Read first:** [specs README](./README.md) contracts 1–7, [`architecture.md`](../architecture.md).

## Domain: `Modules/TippyWander` (Foundation only, Swift 6 mode, depends on `TippyModeration`)

### Bundled content (stable IDs)

```swift
public struct Species: Identifiable, Hashable, Sendable {
    public let id: String           // "pondling", "moth", "turtle", "seal", "fox"
    public let name: String         // "Pondling", "Lilac moth", "Leaf-shell turtle", "Spotted seal", "Cinnamon fox"
    public let spritePrefix: String // "" for pondling (Pet/happy), "moth-" (Pet/moth-happy), …
    public let hatchAfterCheckIns: Int // pondling 1, others 3
}

public enum LandmarkContent: Hashable, Sendable {
    case egg(speciesID: String)
    case decoration(itemID: String)   // a TippyRewards catalog ID, passed through the app coordinator
    case pouch(coins: Int)
    case visitor(id: String)          // "fox-at-dusk"
    case scenery                      // a named place with nothing to collect (keeps the path lively)
}

public struct Landmark: Identifiable, Hashable, Sendable {
    public let id: String       // "reeds-egg-moth"
    public let name: String     // "A speckled egg in the reeds"
    public let step: Int        // reached when the trail position >= step
    public let content: LandmarkContent
}

public struct Area: Identifiable, Hashable, Sendable {
    public let id: String       // "pond-shore"
    public let name: String     // "Pond Shore"
    public let landmarks: [Landmark]
}

public enum Trail { public static let areas: [Area]; public static var landmarks: [Landmark] }
```

**Trail v1.** Steps assume about 1–2 a day, so the first found egg arrives in roughly week one and then about one
a week:

| Area | Landmarks (step, ID, content) |
|---|---|
| Pond Shore | 2 `shore-shell` → decoration `seashell`* · 4 `shore-pouch` → pouch 5 · 6 `shore-bench` scenery |
| Reed Bed | 8 `reeds-egg-moth` → egg `moth` · 10 `reeds-fox` → visitor `fox-at-dusk` · 13 `reeds-pouch` → pouch 8 |
| Willow Grove | 17 `willow-lantern` → decoration `firefly-jar` · 21 `willow-egg-turtle` → egg `turtle` · 25 `willow-pouch` → pouch 10 |
| Mossy Woods | 30 `woods-egg-seal` → egg `seal` · 35 `woods-pouch` → pouch 10 · 40 `woods-mushrooms` scenery |
| Mushroom Glade | 46 `glade-egg-fox` → egg `fox` · 52 `glade-pouch` → pouch 10 |
| Meadow | 60 `meadow-end` scenery: "More of the Wander opens soon" |

*If she already owns the item a decoration find grants, the grant is a harmless no-op. In that case the find card
says "another seashell for your camp" and isn't wasted visually.

### Aggregate: `WanderState`

```swift
public struct Egg: Identifiable, Hashable, Codable, Sendable {
    public let id: String               // the landmark ID it came from, or "starter"
    public let speciesID: String
    public var nestedAtCheckIn: Int?    // the check-in count when it entered the nest
}

public struct Pet: Identifiable, Hashable, Codable, Sendable {
    public let id: String               // the egg's ID
    public let speciesID: String
    public var name: String
    public let hatchedOn: LocalDate
}

public struct WanderState: Hashable, Codable, Sendable {
    public static let currentVersion = 1
    public private(set) var steps: [StepKey: StepAward]  // "checkIn:<date>", "reflection:<date>"; once-only
    public private(set) var found: [String: LocalDate]   // landmark ID -> day found
    public private(set) var eggs: [Egg]                   // nest first (index 0 is nested), then the basket
    public private(set) var pets: [Pet]
    public private(set) var activePetID: String?
    public private(set) var seenVisitors: Set<String>
    public private(set) var pendingHatch: String?         // a pet ID waiting for its naming moment

    public static func starting(petName: String) -> WanderState // starter pondling egg in the nest
    public var position: Int                     // steps.count
    public var checkInCount: Int                 // number of checkIn step awards
    public var nextLandmark: Landmark?
    public mutating func sync(journal: Journal, today: LocalDate) -> WanderEvents
    public mutating func name(petID: String, _ name: String) throws
    public mutating func setActive(petID: String) throws
    public mutating func markVisitorSeen(_ id: String)
}

/// What a sync produced, so the app can celebrate it (once).
public struct WanderEvents: Equatable, Sendable {
    public var newSteps: Int
    public var newlyFound: [Landmark]
    public var hatched: [Pet]
}
```

What `sync` does, in order, all deterministically:
1. **Record new step awards** (`StepPolicy.eligibleSteps`, contract 3):
   - one `checkIn:<d>` for each logged day `d` within the 7-day back-fill window;
   - one `reflection:<d>` for each day in the window that has a reflection.
2. **Find landmarks.** Every landmark with `step <= position` that isn't in `found` is marked found today. An egg
   find adds an `Egg` to the end of `eggs`.
3. **Nest an egg.** If the nest is empty and an egg is waiting, the first waiting egg is nested with
   `nestedAtCheckIn = checkInCount`.
4. **Hatch.** If the nested egg has `checkInCount - nestedAtCheckIn >= species.hatchAfterCheckIns`, it hatches:
   - a `Pet` is created, named after the species (the starter is named with `petName`);
   - the egg is removed from the nest;
   - `pendingHatch` is set;
   - if there's no active pet, it becomes active;
   - the next waiting egg is nested, and step 4 repeats.

The starter egg exists from `starting(petName:)` with `nestedAtCheckIn = 0` and hatches after 1 check-in, so the
pondling appears on her first check-in. A newly nested egg starts its count from that moment, so at most one egg
hatches per sync.

Invariants:
- at most one nested egg;
- pet IDs are unique;
- `activePetID` is nil or names a pet;
- found landmarks are never un-found;
- steps are never removed (journal edits never rewind the trail).

Tests cover:
- the position and steps for a seeded journal;
- the back-fill window;
- reflections adding steps;
- finding landmarks at their exact step;
- the egg queue and the nest;
- hatch timing;
- the starter egg hatching on the first check-in;
- idempotent re-sync, which produces no events;
- `setActive` and `name` errors;
- the codec round-trip, an old shape, and refusing a newer version.

### Port

`WanderStore` (load and save) and `WanderCodec`. The adapter is `FileWanderStore` (`wander.json`), with
`InMemoryWanderStore` in `Demo/`.

## App layer

**`Model/WanderModel.swift`** (`@MainActor @Observable`):
- `state`;
- `activePet` and `activeSpecies`;
- `nextLandmark` and `stepsToNext`;
- `nest` (egg and check-ins left);
- `sync(journal:today:)`, which returns and keeps `WanderEvents` for the UI;
- `name(_:_:)`, `setActive(_:)` and `markVisitorSeen(_:)`;
- `message`.

**`Model/AppCoordinator.swift`** (contract 4) wires the journal hook to `rewards.sync` and `wander.sync`. After a
Wander sync it replays every found decoration or pouch into `RewardsModel.grant` or `award`, but only if a
`RewardsModel` exists; the coordinator takes it as an optional.

**Pet names:**
- On first run after this ships, if `wander.json` doesn't exist, `WanderState.starting(petName: journal.settings.petName)`.
- If the journal already has check-ins, the starter hatches on that first sync, with no waiting.
- From then on, the active pet's name comes from Wander. Settings' "Name" field renames the active pet.
- Onboarding writes `settings.petName`, and the first Wander sync uses it.

**Mood poses for other species:** `PetView(mood:species:)` uses `"Pet/\(prefix)\(mood)"`. When that sprite is
missing, it falls back to the same species' `happy` pose, then to the pondling's pose. The alternates have only
`happy` and `thriving` today; spec 05 adds the rest.

## UI

| Element | Where | Identifier | Behaviour |
|---|---|---|---|
| Next-landmark chip | Home, under the pet's name | `wander-next-label` | "4 steps to the Reed Bed" (area name). Tapping it opens the Wander. |
| Wander button | Home, next to the chip | `wander-button` | Pushes the trail map. |
| Trail map | `Views/Wander/TrailMapView.swift`, title "The Wander" | `wander-map` | A vertical scroll through the areas, each with a banner (`Wander/area-<id>` sprite or a coloured placeholder). Each landmark is a node (`landmark-<id>`), drawn found / next / locked, with a short caption. The active pet's sprite sits at its position. Opens scrolled to the pet. |
| Nest | In the camp scene's nest spot (spec 02), or under the pet until 02 lands | `nest-view`, `nest-countdown-label` | The nested egg's sprite, wiggling when 1 check-in from hatching; "Hatches in 2 check-ins". Hidden when empty. |
| Find card | Home, after a sync with finds | `find-card` | "Sprout found a speckled egg in the reeds!" (or a decoration or pouch). Dismissible, once per find. |
| Hatch moment | Full-screen cover when `pendingHatch != nil` | `hatch-view`, `hatch-name-field`, `hatch-done-button` | The egg cracks (the `hatch` strip, or a scale-and-fade placeholder), the new pet appears, and a name field is pre-filled with the species name. Under Reduce Motion, a fade. |
| Pets | Home button `pets-button` pushes `Views/Wander/PetsView.swift`, title "Pets" | `pet-<id>-row`, `choose-pet-<id>-button` | Every hatched pet with sprite, name, species and hatch date, the active one marked, and eggs in the basket shown as "waiting for the nest". |
| Fox visitor | A one-time sheet the first time `reeds-fox` is found and not seen | `visitor-dialog`, `visitor-done-button` | The fox (`Pet/fox-happy`, or a dusk pose from spec 05) with two or three lines of original, kind dialogue about the pond. Never mentions drinking. |

The active pet replaces the hard-coded pondling everywhere: Home, the reflection sheet's little pet, the recap and
the camp.

## Demo seeds and smoke scenarios

| Seed | State |
|---|---|
| `egg-ready` | Onboarded, no check-ins; `wander.json` absent, so the starter egg is in the nest. |
| `wander-mid` | 9 steps (Nov 11–18 logged, 1 reflection), moth egg found and nested with 1 check-in to go, pondling active, `shore-pouch` found. |
| `two-pets` | Like `wander-mid` but the moth has hatched (named "Dot"); pondling active; nest empty. |

| Scenario | Seed | Shows |
|---|---|---|
| `first-hatch` | `egg-ready` | Mark today drink-free, skip the reflection; the hatch view; keep the name; Home shows the pondling. |
| `wander-map` | `wander-mid` | Open the Wander: found nodes, the pet at step 9, next `reeds-fox` at 10. |
| `hatch-moth` | `wander-mid` | Log today, skip; the moth hatches; rename it "Dot"; Pets lists two. |
| `choose-pet` | `two-pets` | Open Pets, choose Dot; Home shows the moth and `pet-name-label` reads "Dot". |

## Acceptance

- The same journal always produces the same trail, finds and hatches, and re-syncing produces nothing new.
- Editing or deleting history never moves the pet backwards or un-hatches anything.
- A found egg in week one hatches on schedule. Everything found survives relaunch.
- With spec 01 present, pouches add coins once. With spec 02 present, the firefly jar appears in storage after
  `willow-lantern`.
- Glossary: the Wander, step, trail, area, landmark, find, egg, nest, basket, hatch, species, pet, active pet,
  visitor.
