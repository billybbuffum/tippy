# Spec 07: Forks and side paths on the Wander

**Goal:** the Wander stops being one line. At a few forks, a signposted side path loops off the trail and back.
When the pet reaches a fork it waits there, saving her steps, until she chooses: explore the side path or stay on the
trail. A path she passes stays open, and she can send the pet down it later from the map. Side paths hold their own
finds, so wandering off is worth it, but nothing on the main trail is ever skipped.

**Decided with her** (26 November 2026):
- **She picks** at each fork. The pet waits there, and steps earned meanwhile are saved, never lost.
- **Side paths loop back** to the fork they left from, 8 or 9 steps long (the last step is the one back).
- **Each side path is a place of its own** (asked for on 27 November): a winding route through a habitat that isn't
  on the main trail (a marsh, an ancient willow, a fern gully, a fairy ring), with its own discoveries: scenery,
  coins, a decoration found nowhere else, and a creature who lives there and visits.
- **Nothing is missed forever.** A passed side path stays open, and she can explore it any time.

**Depends on:** `main` (specs 03 and 06). **Builds with:** the continuous Wander (spec 06, later screen 2), so the
trail painting is drawn once with its branches. **Art:** [spec 05 §7](./05-art-requests.md#7-immersive-ui-spec-06)
(the branches in `trail-tall`, signposts, four new decorations, four creatures). Like every spec, it works with placeholders until
the art lands: on today's banner map, a side path is a short dotted loop beside the main path.

## Words

| Term | Meaning |
|---|---|
| **Fork** | A spot on the main trail where a side path leaves and comes back. It has a signpost with the side path's name. |
| **Side path** | A winding route (8 or 9 steps) off a fork through a habitat of its own, with its own landmarks. Its last step brings the pet back to its fork (or, on a revisit, to where it left from). |
| **Habitat** | The kind of place a side path winds through: Marsh, Ancient willow, Fern gully, Fairy ring. |
| **Route** | The choices she has made, in order: explore or pass at each fork reached, and later visits to passed paths. Append-only. |
| **Walk** | Where the pet is, derived by replaying her steps along the route. Never stored, like the trail position today. |
| **Waiting**, **saved steps** | The pet stands at a fork she hasn't chosen at yet; steps earned meanwhile are kept for whichever way she picks. |
| **Excursion** | A side path being walked: chosen at the fork, or revisited from the map. The pet returns to where it left from. |

## Domain (`Modules/TippyWander`)

### Trail content (version 2)

The main trail keeps every area, landmark ID and step number. Forks add to it:

```swift
public struct SidePath: Hashable, Sendable {
    public let name: String            // "Heron's Inlet", shown on the signpost
    public let length: Int             // steps to walk it, including the step back to the fork
    public let hint: String            // "Something glints by the water."
    public let landmarks: [Landmark]   // `step` counts steps into the path, 1..<length
}

public struct Fork: Identifiable, Hashable, Sendable {
    public let id: String              // stable, never renamed or reused
    public let areaID: String
    public let mainStep: Int           // where it sits on the main trail
    public let sidePath: SidePath
}

extension Trail {
    public static let forks: [Fork]    // in mainStep order
}
```

Landmark IDs are unique across the main trail and every side path, because `found` is one dictionary. Forks sit
between main-trail landmarks, never on one.

| Fork ID | Area | Main step | Side path | Habitat | Length | Discoveries (step into the path) |
|---|---|---|---|---|---|---|
| `reeds-inlet` | Reed Bed | 11 | Heron's Inlet | Marsh | 8 | `inlet-dragonflies` scenery (2), `inlet-pouch` 6 coins (3), `inlet-heron` visitor `heron` (5), `inlet-cairn` decoration `pebble-cairn` (7) |
| `willow-hollow` | Willow Grove | 19 | The Hollow Willow | Ancient willow | 8 | `hollow-swing` scenery (2), `hollow-owl` visitor `owl` (4), `hollow-bloom` decoration `lily-bloom` (6), `hollow-pouch` 10 coins (7) |
| `woods-ferns` | Mossy Woods | 33 | Fern Hollow | Fern gully | 9 | `ferns-pouch` 12 coins (2), `ferns-hedgehog` visitor `hedgehog` (4), `ferns-stream` scenery (6), `ferns-glow` decoration `glow-mushrooms` (8) |
| `glade-ring` | Mushroom Glade | 49 | The Toadstool Ring | Fairy ring | 8 | `ring-dance` scenery (2), `ring-toad` visitor `toad` (4), `ring-pouch` 15 coins (6), `ring-seat` decoration `toadstool-seat` (7) |

The four decorations are new find-only catalog items in Rewards (`inShop: false`, like `firefly-jar`):
`pebble-cairn` (ground), `lily-bloom` (water), `glow-mushrooms` (light) and `toadstool-seat` (ground). The app layer
grants them through the existing coordinator with key `find:<landmarkID>`, and pouches with `pouch:<landmarkID>`.
Rewards never learns about forks.

**The creatures** visit once, like the fox at dusk (the same `seenVisitors` and visitor sheet). Who they are and what
they say lives in `Views/Wander/VisitorProfiles.swift`; they talk about their place and the pet, never about
drinking:

| Visitor ID | Who | Where |
|---|---|---|
| `heron` | Sable, a heron fishing in the shallows | Heron's Inlet |
| `owl` | Bramble, an owl in the hollow trunk | The Hollow Willow |
| `hedgehog` | Thistle, a hedgehog in the moss | Fern Hollow |
| `toad` | Bellow, a toad playing a reed flute | The Toadstool Ring |

### Route and walk

```swift
public enum RouteChoice: Hashable, Sendable, Codable {
    case explore(forkID: String)               // chosen while waiting at the fork
    case pass(forkID: String)                  // "stay on the trail"
    case revisit(forkID: String, afterSteps: Int)  // a passed path, started from the map
}

public enum TrailSpot: Hashable, Sendable {
    case main(step: Int)
    case side(forkID: String, step: Int)       // 0..<length (0: at the fork, setting off); the last step returns to `.main`
}

public struct Walk: Hashable, Sendable {
    public let spot: TrailSpot
    public let mainStep: Int                   // the furthest main-trail step reached
    public let stepsUsed: Int
    public let savedSteps: Int                 // earned but not walked yet (waiting, or the trail's end)
    public let waitingAt: Fork?
    public let excursion: Fork?                // the side path being walked, if any
    public let openForks: [Fork]               // passed, not walked: open to revisit
}

public enum RoutePolicy {
    /// Replays `steps` along `route`, one step at a time:
    /// - on an excursion, walk the side path; its last step returns to where it left from;
    /// - a `revisit` starts once exactly `afterSteps` steps have been walked;
    /// - on the main trail, at a fork with no choice yet, stop: every remaining step is saved;
    /// - at a fork with `pass`, keep going; with `explore`, start the excursion;
    /// - at the trail's end, stop: remaining steps are saved.
    public static func walk(steps: Int, route: [RouteChoice]) -> Walk
    /// Every spot passed, in order, for the map's replay and for marking finds.
    public static func path(steps: Int, route: [RouteChoice]) -> [TrailSpot]
}
```

The replay is a pure function, so the same steps and route always give the same walk, and saved steps are just
steps not walked yet: choosing a day later gives exactly the same result as choosing at once.

### `WanderState` changes

- `route: [RouteChoice]` is stored (append-only) and `currentVersion` becomes 2.
- `position` stays the number of steps. `walk` is the new derived location, and the map and Home use it.
- `sync` marks every landmark on `RoutePolicy.path` as found, main trail and side paths alike. Eggs, nesting and
  hatching are unchanged: they count check-ins, not where the pet is.
- `nextLandmark` is the first landmark not yet found along the route ahead. While waiting it is nil, and
  `waitingAt` says why.
- `mutating func choose(at forkID: String, explore: Bool, today:) throws -> WanderEvents`: allowed only while
  waiting at that fork. It appends the choice, then marks the finds along the newly walkable stretch, so saved steps
  turn into finds at once.
- `mutating func revisit(_ forkID: String, today:) throws -> WanderEvents`: allowed for a fork that was passed and
  whose side path hasn't been walked, and not during another excursion. It appends `.revisit(forkID, afterSteps:
  walk.stepsUsed)`. With saved steps it walks at once. Otherwise the pet heads there with the next steps earned.
- New problems: `notWaitingAtFork`, `pathNotOpen`, `onExcursion`.
- `WanderEvents` gains `reachedFork: Fork?` (the pet just started waiting) and `excursionDone: Fork?`.

**Migration from version 1:** a saved Wander whose position is already past a fork must not jump backwards. When
decoding version 1, append `.pass(forkID)` for every fork with `mainStep < position`, in trail order. Those side
paths are open to revisit, and nothing found is lost. This also covers restoring an old backup (spec 04 decodes
through the same codec).

### Tests

- The walk is deterministic, and re-syncing changes nothing.
- Waiting saves steps, and a later choice uses them all.
- Explore walks the loop, comes back to the fork and continues. Pass continues straight on.
- A revisit inserts at the recorded point, returns to the main spot, and can't start during another excursion.
- Side-path finds are found once and replay into Rewards once.
- Migrating version 1 never moves the pet back. Every invariant from spec 03 still holds.

## The app

**Model (`WanderModel`):** `choose(at:explore:)` and `revisit(_:)` intent methods, which save and then run the
coordinator's find replay, like `sync`.

**Home:**
- While waiting, the signpost (`wander-next-label`) reads "Sprout is at a fork" with a small "!" flag. Tapping it
  opens the map at the fork.
- On an excursion it reads "Exploring Heron's Inlet".
- No notifications or nagging: the pet waits happily, and the bubble may say "Which way should we go?" on days it's
  waiting.

**The map:**
- **The side path:** on the continuous trail it follows its painted branch (spec 05 §7 sidecar). Until then it's a
  dotted loop beside the main path, with its nodes (`landmark-<id>`) and a wooden signpost at the fork
  (`fork-<forkID>`) showing the side path's name.
- **Choosing:** when the pet is waiting, a parchment card (`fork-card`) asks "Which way?", with:
  - "Explore Heron's Inlet" (`fork-explore-button`), showing its length ("4 steps") and a hint ("something
    glints");
  - "Stay on the trail" (`fork-stay-button`).

  Both show how many steps are saved ("2 steps saved"). The choice replays: the pet walks the saved steps down the
  way she picked.
- **Revisiting:** a passed side path's signpost has an "Explore" button (`revisit-<forkID>-button`) while it's open.
  The pet hops to the fork with a small puff, walks the loop with saved or future steps, and hops back.
- **VoiceOver:** `wander-pet`'s value names the spot: "Step 9", "At the Heron's Inlet fork", or "Heron's Inlet,
  step 5 of 8".

**As built** (on today's banner map): a fork takes two rows in the middle of the trail. Its side path winds out to
one side through its habitat, drawn in code until the art lands (`SidePathHabitat`: the route's shape in a unit
space, and the scenery under it: a pool with reeds and lily pads, a willow with its pond, a stream through ferns, a
ring of toadstools). The signpost, with the habitat and the Explore button, stands on the other side of the main
path. The replay follows the walked route by index, along the winding path and back. Home's signpost reads "At a fork: which
way?", "Exploring Heron's Inlet", or "3 steps to a fork" when a fork comes before the next landmark.

**Demo seeds:**
- `at-fork`: `two-pets` with 16 steps and the fox met, so the pet waits at Heron's Inlet with 5 saved steps
  (enough to reach the heron).
- `fork-passed`: 15 steps with Heron's Inlet passed and open.

**Scenarios:**
- `fork-explore`: choose to explore, watch the finds, the pet ends back at the fork.
- `fork-stay`: stay on the trail.
- `side-path-revisit`: revisit from the map.

## Acceptance

- The Wander tests above pass, and all existing Wander tests pass unchanged (main-trail steps and IDs are
  untouched).
- A version 1 `wander.json` and a version 1 backup both load with the pet where it was.
- On the map the three scenarios show the fork card, the walk down the side path and back, and the revisit.
- New terms (fork, side path, route, walk, waiting, saved steps, excursion) are in `architecture.md` §13.
