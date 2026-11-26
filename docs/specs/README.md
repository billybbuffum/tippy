# Tippy build specs

Implementation specs for the rest of [the plan](../research-and-plan.md). Each spec is a self-contained work
package for one agent and one pull request (two for spec 03). Read this page first, then your spec, then
[`architecture.md`](../architecture.md) and [`CLAUDE.md`](../../CLAUDE.md). The architecture rules and the
smoke-test checklist in `CLAUDE.md` apply to every spec.

| Spec | Builds | Depends on | Can run in parallel with |
|---|---|---|---|
| [01 Rewards: coins and the weekly recap](./01-rewards-coins-recap.md) | `TippyRewards` package, `RewardsModel`, coin badge, weekly recap | main (core loop) | 03, 05 |
| [02 Camp: shop and decorating](./02-camp-shop-decorating.md) | Catalog, purchases, placement, camp scene on Home | 01 merged | 03, 05 |
| [03 The Wander, eggs and pets](./03-wander-eggs-pets.md) | `TippyWander` package, trail map, nest and hatching, pet collection | main (core loop) | 01, 02, 05 |
| [04 Backup bundle, polish and pilot](./04-backup-polish-pilot.md) | Backup of every context, restore preview, pilot checklist | 01, 02, 03 merged | 05 |
| [05 Art requests](./05-art-requests.md) | Sprites for the camp, the Wander, eggs, hatching and pet moods | nothing | everything |
| [06 Immersive pixel UI](./06-immersive-pixel-ui.md) | Full-screen pixel world: the pixel UI kit, the immersive Home, then parchment sheets, the continuous Wander and pixel lists | 01–04 merged | 05 §7 (art) |
| [07 Forks and side paths on the Wander](./07-wander-forks.md) | Forks where she picks the way, side paths that loop back with their own finds, the route and walk in `TippyWander` | 03, 06 merged | 05 §7 (art); builds with spec 06's continuous Wander |

```
main ──► 01 Rewards ──► 02 Camp ──┐
   └───► 03 Wander ───────────────┴──► 04 Backup + pilot
05 Art (any time; code falls back to placeholders until it lands)
```

## Shared contracts

These are decided here so that parallel work fits together. Don't change them in a feature PR; propose a change to
this page instead.

### 1. Contexts and packages

| Context | Package | Depends on | Owns |
|---|---|---|---|
| Moderation | `Modules/TippyModeration` | none | Journal, settings, weeks, mood, reminders (built) |
| Rewards | `Modules/TippyRewards` | `TippyModeration` | Coin ledger, weekly recaps, catalog, purchases, camp placements |
| Wander | `Modules/TippyWander` | `TippyModeration` | Step ledger, trail, finds, eggs, hatching, pets, active pet |
| *(integration)* | `Modules/TippyBackup` (spec 04) | all three | The backup bundle format and restore preview; no rules of its own |

Rewards and Wander **never import each other**. Where one affects the other (a decoration or coin pouch found
on the Wander), the **app layer** coordinates. See contract 4.

### 2. Journal change hook (whoever lands first adds it)

Downstream contexts react to the journal through one hook on `JournalModel`. The first of spec 01 or spec 03 to
merge adds exactly this; the other rebases onto it:

```swift
// Sources/Tippy/Model/JournalModel.swift
/// Downstream models (Rewards, Wander) subscribe here in the composition root.
/// Called after every successful change, on refresh (app to the front), and once
/// when a subscriber is added, always on the main actor.
private var changeHandlers: [@MainActor (Journal, LocalDate) -> Void] = []

func onJournalChange(_ handler: @escaping @MainActor (Journal, LocalDate) -> Void) {
    changeHandlers.append(handler)
    handler(journal, today)
}

private func notifyChange() {
    for handler in changeHandlers { handler(journal, today) }
}
```

`notifyChange()` is called at the end of `mutate` (success path, after `rescheduleReminders()`) and at the end of
`refresh()`. Subscribers are registered in `App/TippyApp.swift` and `Demo/UISmokeMode.makeModel` only.

### 3. Once-only award ledgers

Coins (Rewards) and steps (Wander) are **ledgers of awards keyed by the fact that earned them**:

- **Key format:** `"<kind>:<id>"`, with dates in `yyyy-MM-dd`, for example `checkIn:2026-11-19`,
  `drinkFree:2026-11-19`, `weekGoal:2026-11-16` (the week's start), `reflection:2026-11-19`,
  `pouch:reeds-pouch-1`, `find:willow-lantern`.
- **Recording a key that exists is a no-op**, so syncing the same journal twice changes nothing.
- **Awards are never removed.** Editing, clearing or deleting a day later doesn't take one back.
- **Sync is a pure domain function:** `eligible awards = f(journal, today)`. The model records whichever are new.
- **Back-fill limit:** a day earns only if it's within **7 days** of `today` at the time of the sync (`day >= today
  - 7`). This rewards remembering a missed day without letting old history be farmed.
- **Balances and positions are derived:** the coin balance is earned minus spent, and the pet's trail position is
  the number of step awards. Neither is stored.

### 4. Cross-context coordination (app layer)

`Sources/Tippy/Model/AppCoordinator.swift` (created by whichever of 01 or 03 needs it second, normally 03) wires
the contexts together in the composition root. It holds no state of its own:

- Journal changes go to `RewardsModel.sync(journal:today:)` and `WanderModel.sync(journal:today:)`.
- Wander finds reach Rewards. After a Wander sync, every found landmark whose content is `.decoration(itemID)` or
  `.pouch(coins)` is passed to `RewardsModel.grant(itemID:key:)` or `RewardsModel.award(coins:key:)` with key
  `find:<landmarkID>` or `pouch:<landmarkID>`. Both are idempotent, so the coordinator replays all finds on every sync.
  If spec 03 lands before spec 02, decorations found early are granted once 02 lands, with nothing lost.

### 5. Storage

One JSON file per context in `Application Support/Tippy/`: `journal.json` (built), `rewards.json` (01),
`wander.json` (03). Each has a `version`, decodes missing fields to defaults, refuses newer versions, writes
atomically, and moves an unreadable file aside, exactly like `FileJournalStore`. Spec 04 bundles all three into one
backup.

### 6. Home screen regions

Home is shared, so each spec owns one region and adds to it with small edits:

| Region | Today | Owner |
|---|---|---|
| Toolbar leading | History | built |
| Toolbar trailing | Coin badge (01), then Settings | 01 adds the badge before the gear |
| Scene | `PetView` | 02 replaces it with `CampSceneView`, which shows the active pet (from 03 when present) and the nest (03) |
| Header chips under the scene | Pet name and mood caption | 03 adds the "next landmark" chip and the Wander and Pets buttons |
| Cards | Reminder offer, week card, today card | 01 adds the recap entry point if needed |
| Bottom bar | Log a drink, No drinks today | built; leave alone |

The pet's name moves to Wander once spec 03 lands (each pet has its own). Until then `ModerationSettings.petName`
is the name.

### 7. Identifiers, seeds and sprites

- **Accessibility identifiers:** kebab-case. New ones are prefixed with the feature (`recap-`, `coin-`, `shop-`,
  `camp-`, `wander-`, `nest-`, `hatch-`, `pets-`). Every identifier a spec names is a contract its scenarios rely on.
- **Seeds:** each spec adds its seeds to `UISmokeMode.Seed` and `SmokeScenario.Seed`, plus the README table. All
  seeds keep the fixed clock: **Thursday 19 November 2026, 6 PM**, with Monday-start weeks.
- **Sprites:** add paths to `scripts/sync-sprites.py`'s `MANIFEST`, run it, and commit the copies. Load them only
  through `SpriteLibrary`. When art from spec 05 isn't there yet, `SpriteLibrary.image` returns nil; draw a simple
  placeholder (SF Symbol or shape) instead. Never block on art.

## Working in parallel

- **Branch per spec** from the latest `main`, one PR per spec. Rebase before opening and again before merge.
- **Hot files** several specs touch:
  - `HomeView.swift`, `TippyApp.swift`, `UISmokeMode.swift`, `SmokeSupport.swift`, `JournalModel.swift`
  - `scripts/sync-sprites.py`, `docs/architecture.md` (glossary and context table), `README.md` (seeds table)

  Keep edits there small and additive, and expect easy rebase conflicts.
- **Don't refactor what another spec owns.** If you need a change in another context's code, make the smallest
  possible edit and call it out in the PR body.
- **Definition of done**, for every spec:
  - `swift test` passes for the touched packages;
  - `scripts/check-architecture.py` and `scripts/sync-sprites.py --check` pass;
  - the Build and UI smoke checks are green on the PR;
  - the "Feature demo" in the smoke comment shows the feature;
  - new terms are in the ubiquitous language (`architecture.md` §13);
  - the PR body lists what you deviated from in the spec and why.
- **Privacy:** fixtures, seeds and GIFs use made-up data only.
