# Tippy app architecture

The architecture of the iPhone app, and the rules every change follows. It applies Domain-Driven Design with a
hexagonal (ports and adapters) structure, written in idiomatic modern Swift: value types, Observation, Swift
concurrency, SwiftUI. The server rules in [`server-architecture.md`](./server-architecture.md) use the same
model, and the two share the [ubiquitous language](#13-ubiquitous-language).

If code and this document disagree, fix one of them in the same pull request. `scripts/check-architecture.py`
enforces the rules a script can check (see [section 11](#11-enforced-rules-and-review-checklist)).

---

## 1. The shape

```
                    ┌────────────────────────────────────────────────────────────┐
  SwiftUI views ───►│  Application layer: JournalModel (@MainActor @Observable)   │
  (Views/)          │  - the only place state changes                            │
  read state,       │  - orchestrates the domain, calls ports                    │
  send intents      └───────────────┬──────────────────────────┬─────────────────┘
                                    │ uses                     │ calls ports
                                    ▼                          ▼
                    ┌──────────────────────────┐   ┌──────────────────────────────┐
                    │ Domain: Modules/<Context>│   │ Ports (protocols)            │
                    │ Foundation only, pure    │   │ JournalStore (domain repo),  │
                    │ value types + rules      │   │ ReminderScheduling (Model/)  │
                    └──────────────────────────┘   └───────────────▲──────────────┘
                                                                   │ implement
                                                   ┌───────────────┴──────────────┐
                                                   │ Adapters/ (Apple frameworks) │
                                                   │ Demo/ (smoke-test stand-ins) │
                                                   └──────────────────────────────┘
  App/TippyApp.swift = composition root: the one place that picks adapters and builds models.
```

**Dependencies point inward.** Views know the model. The model knows the domain and the ports. Adapters know the
ports and the domain. The domain knows nothing outside itself.

## 2. Layers and folders

| Layer | Where | May import | Holds |
|---|---|---|---|
| **Domain** | `Modules/<Context>/Sources/<Context>/` (one Swift package per bounded context) | `Foundation`, and contexts its `Package.swift` depends on | Entities, value objects, aggregates, domain services, repository ports, codecs |
| **Application** | `Sources/Tippy/Model/` | `Foundation`, `Observation`, contexts | `@MainActor @Observable` models (use cases + observable state), application ports (`Ports.swift`) |
| **Adapters** | `Sources/Tippy/Adapters/` | `Foundation`, platform frameworks (`UserNotifications`, later `WidgetKit`, `HealthKit`, `CloudKit`), contexts | One port implementation per file |
| **Presentation** | `Sources/Tippy/Views/<Feature>/` | `SwiftUI`, `UIKit` (images only), `Charts`, `UniformTypeIdentifiers`, `CoreText` (registering the bundled fonts), contexts | Views, view-only helpers (`Views/Shared/`), the pixel UI kit (`Views/Pixel/`), sprite loading |
| **Composition** | `Sources/Tippy/App/` | `SwiftUI`, `Foundation` | `TippyApp` (composition root), `RootView` (top-level routing and alerts) |
| **Demo** | `Sources/Tippy/Demo/` | `Foundation`, contexts | `UISmokeMode` (seeds, fixed clock), in-memory and silent stand-in adapters |

Every Swift file in the app lives in one of those five folders, `Views/<Feature>/` counting as one.

## 3. Domain layer (DDD in Swift)

The domain is where every business rule lives. If it can be decided without a screen, a disk or the network, it
goes here, with a unit test.

- **One package per bounded context.** Today that's `TippyModeration` and `TippyWander`. Planned contexts are in
  [section 8](#8-bounded-contexts). A context's public API is its *published language*: only types marked
  `public` are visible to others.
- **Value types.** Entities and value objects are `struct`s; closed sets of cases are `enum`s. They are `Sendable`,
  `Hashable` where identity or comparison matters, and `Codable` only where they are persisted. No classes in the
  domain.
- **Value objects validate on construction.** A failable or throwing `init` makes invalid states
  unrepresentable (`DrinkServing(volumeMilliliters:abvPercent:)` is nil for an impossible serving;
  `LocalDate(year:month:day:)` is nil for February 30th).
- **Aggregates guard invariants.** State is `public private(set)`, and changes go through `mutating` methods
  that `throw` a typed error when a rule would break. `Journal` is the aggregate root for the Moderation context.
  Its invariants (never both drink-free and drinking on one day, nothing in the future, entries in order) are
  enforced in `log`, `markDrinkFree`, `removeEntry` and `init`. One aggregate is changed per user action.
- **Typed errors.** Each aggregate has an `enum Problem: Error, Equatable, Sendable`. User-facing wording belongs
  to the app (an extension in `Model/`), never the domain.
- **Domain services** are stateless `enum`s with `static` functions when a rule spans several values
  (`MoodPolicy`, `ReminderPlanner`).
- **Bundled content catalogs** (reflection prompts now; shop items and the Wander's trail later) live in the
  domain as static data with **stable string IDs**, because saved records refer to them. Never reuse or rename an ID.
- **No ambient state.** No `Date()`, no `Calendar.current`, no `UserDefaults`, no singletons. "Today" and the
  calendar are parameters, so every rule is deterministic and testable.
- **Repository ports live with their aggregate** (`JournalStore` beside `Journal`). The domain also owns its
  persisted format (`JournalCodec`), so backups and files are versioned in one place.
- **Swift 6 language mode** (full data-race checking) is on for every domain package.

## 4. Application layer

- **One model per bounded context**, named `<Context>Model` (`JournalModel`). It's a `@MainActor @Observable final
  class` that does three things:
  - exposes **derived state** as computed properties over the domain (`summary`, `mood`, `currentGoal`), never
    duplicated stored copies;
  - provides **intent methods**, one per use case (`log(kind:serving:on:)`, `markDrinkFree(_:)`,
    `updateSettings(_:)`). Each one validates through the aggregate, saves through the port, then runs side
    effects such as rescheduling reminders;
  - turns domain `Problem`s into a user `message`.
- **All mutation goes through one private `mutate` function.** It copies the aggregate, applies the change,
  commits it on success, saves, and runs follow-up effects. Views never mutate domain values directly.
- **Application ports** for platform services are protocols in `Model/Ports.swift` (`ReminderScheduling`), stated
  in domain terms (`LocalDate`, not `UNNotificationRequest`). Time is a port too: `Now` (`() -> Date`) and an
  injected `Calendar`. The model has no defaults for them, so the composition root must choose.
- **Async work** (permission prompts, future network calls) is `async` on the model. Views call it from
  `Task { await model.… }`. The model stays on the main actor, so its state is only touched there.
- No `import SwiftUI` or `UIKit` here. A model that needs a `Binding` is a sign the logic belongs in a view helper.

## 5. Adapters

- One adapter per file, named after what it is plus the port: `FileJournalStore`, `NotificationReminderScheduler`.
- Adapters translate. They contain no business rules. A rule that sneaks into an adapter (say, "don't remind on
  logged days") moves into a domain service (`ReminderPlanner`), and the adapter just carries out the plan.
- Adapters handle the platform's failure modes honestly. `FileJournalStore` writes atomically with file
  protection, and moves an unreadable file aside instead of overwriting it.
- Only `App/` (the real ones) and `Demo/` (stand-ins) construct adapters.

## 6. Presentation (SwiftUI)

- **Views are a function of model state.** Read the model with `@Environment(JournalModel.self) private var
  model`, call its intent methods, and keep only transient UI state in `@State` (a sheet is showing, a draft
  form, a selection). Use `@Bindable` when binding directly to an observable model's properties; for domain
  values behind the model, write a small `Binding(get:set:)` helper that calls an intent method, as `SettingsView`
  does with `setting(_:)`.
- **No business logic in views.** If a view computes something a test should cover, move it into the domain.
  Formatting (`drinksText`, display names, symbols, captions) lives in `Views/Shared/Display.swift` as
  extensions on domain types.
- **Time comes from the model** (`model.now`, `model.today`), never `Date()`, so demo mode's fixed clock covers
  every screen.
- **One feature per folder** (`Views/Home/`, `Views/Logging/`, …). Extract a subview, as its own `struct` or a
  `private var … : some View`, once a `body` passes about 60 lines or a piece repeats. No `AnyView`.
- **Observation, not Combine.** Use `@Observable` + `@Environment(Type.self)`. No `ObservableObject`,
  `@Published` or `@StateObject` in new code.
- **Navigation:** `NavigationStack` per root. Use sheets for short tasks (log a drink, settings) and push for
  browsing (history). `RootView` owns app-wide routing (onboarding or home) and app-wide alerts.
- **Accessibility and testability:**
  - every interactive control gets a kebab-case `.accessibilityIdentifier` on the control itself;
  - icon-only buttons get an `.accessibilityLabel`;
  - decorative views are `.accessibilityHidden(true)`;
  - text uses Dynamic Type styles (`.headline`, `.caption`), never fixed point sizes, except in drawn art like
    `PetView`, which scales to its frame, and pixel text (`.pixelFont`), which sits on the UI grid and switches to
    the rounded system font at accessibility sizes.
- **The pixel UI** ([spec 06](./specs/06-immersive-pixel-ui.md)). Home is the world, edge to edge, with no
  navigation bar, materials or iOS cards; other screens follow it. Build it from the kit in `Views/Pixel/`, never
  from system chrome:
  - two grids: the **world grid** (one art pixel = screen width / 132, `PixelGrid.worldUnit`) for scenes and
    sprites, and the **UI grid** (2 pt, `PixelGrid.uiPoint`) for panels, buttons, icons and text;
  - `PixelPalette` for every colour, `.pixelPanel(_:)` for any panel, `.buttonStyle(.pixel(_:))` for any button,
    `PixelIcon` for HUD icons, `.pixelFont(_:_:)` for text (sizes in UI pixels);
  - visible pixel text may be shorter than its accessibility label (the week meter shows `6/14`; VoiceOver and
    the smoke tests read "6.0 of 14 drinks this week").
- **Animations** respect demo mode. Nothing repeats forever under `UISmokeMode.isActive`, because XCUITest waits for the
  app to go idle.

## 7. Composition root and demo mode

- `App/TippyApp.swift` builds the model graph once, as `AppModels` (one model per context):
  - on a device: `FileJournalStore`, `FileRewardsStore`, `FileWanderStore`, `NotificationReminderScheduler`, `.autoupdatingCurrent` and
    `{ Date() }`;
  - under the UI smoke test, `UISmokeMode.makeModels()` swaps in `InMemoryJournalStore`, `InMemoryRewardsStore`, `InMemoryWanderStore`,
    `SilentReminderScheduler`, a fixed calendar and a fixed clock (Thursday 19 November 2026, 6 PM).
- Downstream models follow the journal through its change hook, `JournalModel.onJournalChange`, which both
  composition roots (and only they) subscribe to: `rewards.sync(journal:today:)` and `wander.sync(journal:today:)` run after every change, on refresh,
  and once at launch.
- Models reach views through `.environment(...)` on the `WindowGroup`, one call per model.
- Demo mode is compiled out on devices (`isActive` is a constant `false` off the simulator), and every seed is
  named in both `UISmokeMode.Seed` and `SmokeScenario.Seed`.

## 8. Bounded contexts

| Context | Package | Owns | Status |
|---|---|---|---|
| **Moderation** | `TippyModeration` | The journal: drink entries, drink-free days, reflections, the weekly goal per week, settings, week summaries, pet mood, reminder plan | Built |
| **Rewards** | `TippyRewards` | The coin ledger, the shop catalog, purchases, decorations placed in the camp, weekly recaps | Built (coins, recaps, shop, camp) |
| **Wander** | `TippyWander` | The step ledger, the trail (areas, landmarks, finds), eggs, hatching, the pet collection, the active pet | Built (trail, nest, hatching, the pet collection, the visitor) |
| *(integration)* | `TippyBackup` | The backup bundle (journal, rewards, Wander in one file, v1 journal-only files still read) and the restore preview; no rules of its own | Built |

Rules between contexts:
- **Downstream contexts read upstream facts through public API only.** Rewards and Wander depend on Moderation
  (check-ins, drink-free days, reflections, week summaries). Moderation never depends on them, and Rewards and Wander
  don't depend on each other. The app's models coordinate them.
- **Awards are recorded once, keyed by the fact that earned them, and never revoked.** Coins and steps live in
  ledgers whose keys name their source (`checkIn:2026-11-19`, `drinkFree:2026-11-19`, `weekGoal:2026-11-16`,
  `reflection:2026-11-19`). Recording an award whose key exists is a no-op, so retries, relaunches and edits can't
  duplicate one, and later edits or deletions never take one back. Balances are derived from the ledger (earned
  minus spent), never stored.
- **Each context has its own aggregate, repository port, file and model** (`RewardsModel` with its own
  `rewards.json`). A model may read another context's model, injected through its initializer, but changes it
  only through that model's intent methods.
- **No dependency cycles.** The checker fails a cycle between packages.

## 9. Cross-cutting concerns

**Days and time**
- A day is a `LocalDate`; an instant is a `Date`. Entries are filed under a `LocalDate`, which is decided once,
  with the user's calendar, when the entry is logged.
- `Week` starts on the user's first weekday. Week math happens only in the domain.
- Rewards identify a completed week by the Monday-start week containing its middle day. Switching between
  Sunday and Monday in Settings cannot pay the same week's bonus or show its recap twice. Saved keys and
  recap dates retain their original dates; daily awards continue to use exact logged dates.

**Persistence and migration**
- Each context's aggregate is one JSON file in Application Support, written atomically, with a `version`.
- **Additive changes** (a new field) need no version bump. Decode with `decodeIfPresent` and a default, so old
  files and old backups still load. Add a test that decodes an old shape.
- **Breaking changes** bump `currentVersion` and add a migration step in the codec, with a test per step.
- A file from a newer version is refused, never half-read.
- A backup is the codec's output, so export and restore can't drift from storage.

**Art and other resources**
- Source art lives in `Assets/Sprites/` (see its README for sizes, frame strips and timings). The app ships only
  the files listed in `scripts/sync-sprites.py`, copied into `Sources/Tippy/Resources/Sprites/`, which SwiftPM
  bundles and xtool packs. CI fails if a copy drifts from its source.
- Views load sprites only through `SpriteLibrary` (`Views/Shared/Sprites.swift`), drawn with nearest-neighbour
  scaling (`.interpolation(.none)`). Looping animations play only when Reduce Motion is off and not in demo mode;
  otherwise the still pose shows.
- All art is original or CC0; never Tipple's.

**Errors**
- Domain errors are typed. The model turns them into one `message` that `RootView` shows.
- Never use `try?` on a write of user data. A failed save is reported.

**Concurrency**
- Domain packages use the Swift 6 language mode.
- The app target stays in Swift 5 mode, like ChoreLock, until it builds clean under Swift 6; then flip
  `swiftLanguageModes` to `.v6`.
- The model is `@MainActor`. Adapter callbacks that leave the main actor must come back before touching the
  model.

**Privacy**
- No analytics and no network. Data leaves the phone only through a feature the user starts: export, and later
  any opt-in sync.

**Safety**
- The pet is never punished, sick or dying; "concerned" is the lowest mood.
- The not-medical-advice note and helpline stay reachable from Settings.

## 10. Swift style

- **Access control:** `private` by default in the app. In domain packages, mark `public` only what other layers
  need, and use `public private(set)` for aggregate state.
- **`final class`** for every class, `struct` everywhere a reference isn't needed, and `let` over `var`.
- **No force unwraps or force tries**, except for constants known valid at compile time, such as
  `DrinkServing(volumeMilliliters: 355, abvPercent: 5)!` or a fixed time zone identifier. Prefer `guard` with an
  early exit.
- **One primary type per file**, named after it. Small private helpers and extensions may share the file.
- **Naming:** follow the Swift API Design Guidelines. Use the [ubiquitous language](#13-ubiquitous-language)
  exactly (`markDrinkFree`, not `setSober`). Booleans read as assertions (`isDrinkFree`, `hasOnboarded`).
- **Documentation:** a `///` comment on every type and on any non-obvious member, saying *why* and which rule it
  enforces.
- **Formatting:** 4-space indent, lines up to about 120 characters, trailing commas in multi-line literals.

## 11. Enforced rules and review checklist

`scripts/check-architecture.py` runs on every push and pull request (`.github/workflows/architecture.yml`, a few
seconds on Linux). It fails when:
- a file imports outside its layer's allowance (table in section 2);
- the domain, model or views read the clock directly (`Date()` / `Date.now`);
- anything outside `App/` or `Demo/` constructs an adapter;
- a view touches storage or the codec;
- an app source file sits outside `App/`, `Model/`, `Adapters/`, `Views/` or `Demo/`;
- context packages depend on each other in a cycle.

Reviewers also check what a script can't:
- [ ] New rules are in the domain, with unit tests (including old-file decoding for new persisted fields).
- [ ] Aggregate state changes only through `mutating` methods that guard its invariants.
- [ ] Views hold no business logic; new controls have accessibility identifiers; a smoke scenario shows the change.
- [ ] New terms are added to the ubiquitous language below.
- [ ] Nothing leaves the phone without the user starting it.

## 12. Adding a feature: the order of work

1. **Name it.** Add or adjust terms in the [ubiquitous language](#13-ubiquitous-language). Decide which context
   owns it.
2. **Domain first.** Add types and rules to the context's package, with `swift test` coverage, plus decoding
   defaults and an old-shape test if anything new is persisted.
3. **Port, if it needs the platform.** Declare a protocol in `Model/Ports.swift` (or a repository beside its
   aggregate), then write the adapter in `Adapters/` and a stand-in in `Demo/`.
4. **Model.** Add derived properties and one intent method per use case, all going through `mutate`.
5. **Composition.** Wire any new adapter in `App/TippyApp.swift` and `UISmokeMode.makeModels()`.
6. **View.** Put it in its feature folder, reading the model, with accessibility identifiers.
7. **Smoke scenario and seed.** Follow `CLAUDE.md`.
8. Run `scripts/check-architecture.py` and `swift test --package-path Modules/<Context>`, then push and read CI.

## 13. Ubiquitous language

Use these terms exactly in code, tests, UI copy and docs. If one changes, update this table first.
`server-architecture.md` adds server-only terms on top of these.

| Term | Meaning | In code |
|---|---|---|
| **Journal** | Everything the user has logged plus their settings; the Moderation aggregate | `Journal` |
| **Drink entry** | One logged drink as entered: kind, amount and unit, ABV, optional standard-drink override, the day it counts towards | `DrinkEntry`, `VolumeUnit` |
| **Drink kind** | Beer, wine, cocktail, shot (`spirit`), seltzer, other; each with a typical serving | `DrinkKind` |
| **Serving** | Volume and strength of one drink | `DrinkServing` |
| **Standard drink** | 14 g of pure alcohol (US). A *UK unit* is 8 g | `standardDrinks`, `StandardDrink` |
| **Day** | A calendar day with no time zone | `LocalDate` |
| **Week** | Seven days starting on the user's first weekday | `Week`, `firstWeekday` |
| **Weekly goal** | Maximum standard drinks per week, kept per week: a change applies from the current week on | `goal(for:)`, `setWeeklyGoal`, `goalHistory` |
| **Baseline** | Standard drinks in a typical week before Tippy | `baselinePerWeek` |
| **Check-in** | Logging a day, with drink entries or as a drink-free day | `isCheckedIn` |
| **Drink-free day** | A day checked in with no drinks; never also has entries | `markDrinkFree`, `drinkFreeDays` |
| **Back-fill** | Logging an earlier day | the `on:` day of `log` |
| **Empty-day choice** | What a day becomes when its last drink is deleted: drink-free or cleared (unlogged) | `EmptyDayChoice` |
| **Reflection** | Her optional answer to the day's prompt, kept with the logged day | `Reflection`, `ReflectionPrompts` |
| **Days logged** | Checked-in days so far this week (nothing resets) | `checkedInDays` |
| **Week summary** | A week's total, goal, drink-free days, days elapsed | `WeekSummary` |
| **Pace** | Standard drinks so far ÷ the pro-rated weekly goal | `pace` |
| **Mood** | The pet's state from pace and check-ins: thriving, happy, okay, concerned, waiting | `PetMood`, `MoodPolicy` |
| **Pet** | The user's companion; the first one is named in onboarding. Each pet has its own name, kept in the Wander | `Pet`, `PetView`, `petName` (the active pet's name, kept in step for reminders) |
| **Reminder** | The evening nudge on a day not yet checked in | `ReminderPlanner`, `ReminderScheduling` |
| **Backup** | Every context exported as one file (format `tippy-backup` v2); restoring shows a preview, then replaces everything, all or nothing | `BackupFormat`, `BackupModel`, `RestorePreview` |
| **Onboarding** | The first-launch questions | `hasOnboarded`, `OnboardingView` |
| **Camp** *(Rewards)* | Home: the pond scene where the active pet lives and decorations are placed | `CampSceneView`, `CampLayout` |
| **Catalog item**, **slot** *(Rewards)* | A decoration with a stable ID, price and kind (ground, water, light); a spot in the camp of one kind | `CatalogItem`, `CampSlot`, `SlotKind`, `CampCatalog` |
| **Coins** *(Rewards)* | Earned per check-in (5), with bonuses for drink-free days (+3) and weeks within the goal (+15); recorded once per fact, never revoked. The balance is earned minus spent | `RewardsLedger`, `balance`, `EarningRules` |
| **Award** *(Rewards)* | Coins recorded once for one fact (a check-in, a drink-free day, a week within its goal, a pouch); never removed | `Award`, `AwardPolicy`, `record` |
| **Award key** *(Rewards)* | The fact an award was earned for, `"<kind>:<id>"` (`checkIn:2026-11-19`, `weekGoal:2026-11-16`); one award per key | `AwardKey` |
| **Back-fill window** *(Rewards)* | A day earns coins only within 7 days of the sync (`day >= today - 7`), so remembering a missed day pays but old history can't be farmed | `backfillDays` |
| **Decoration**, **purchase**, **placement** *(Rewards)* | A catalog item; buying it (one of each, never past the balance); putting it in a spot of its kind (moving and storing are free) | `Purchase`, `buy`, `place`, `placements` |
| **Owned**, **stored**, **grant** *(Rewards)* | Bought or found; owned but not placed; a found decoration given once per `find:<landmark>` key | `owned`, `storedItems()`, `grant` |
| **Decorate mode** *(Rewards)* | Home with every spot outlined, to place, move or put away decorations by tapping | `HomeView`, `HomeDock` |
| **World**, **world grid** *(UI)* | Home's full-screen scene (sky, treeline, pond camp, ground) and its grid of one art pixel = width / 132 | `WorldBackdrop`, `WorldLayout`, `SkyTime`, `PixelGrid` |
| **HUD**, **dock**, **notice** *(UI)* | The pixel panels over the sky (nameplate, coins, week meter); the wooden shelf of buttons at the bottom; a one-time parchment panel under the HUD | `HomeHUD`, `WeekMeter`, `HomeDock`, `FindCard`, `ReminderOfferCard` |
| **Pixel kit**, **UI grid** *(UI)* | The panels, buttons, icons, fonts and palette every pixel screen is built from, on a 2 pt grid | `PixelPanel`, `PixelButtonStyle`, `PixelIcon`, `PixelFonts`, `PixelPalette` |
| **Speech bubble** *(UI)* | Today's status in the pet's voice ("How was today?") | `SpeechBubble`, `today-status-label` |
| **Parchment sheet** *(UI)* | A sheet drawn as paper with a title ribbon and pixel buttons instead of a navigation bar, its form in paper sections | `ParchmentSheet`, `TitleRibbon`, `PixelSection`, `PixelStepper`, `PixelSegmented`, `DimmedSceneCard` |
| **Weekly recap** *(Rewards)* | The summary of last week, shown once after it ends (never a queue of older weeks): total against that week's goal, days, coins with the goal bonus, reflections | `WeeklyRecap`, `RecapPolicy`, `WeeklyRecapView` |
| **Next-week idea** *(Rewards)* | Her optional "one thing to try next week", written in the recap and shown on Home that week | `nextWeekIdea`, `NextWeekIdeaCard` |
| **The Wander** *(Wander)* | The trail her pet walks out from the pond, one step at a time | `WanderState`, `WanderModel`, `TrailMapView` |
| **Step** *(Wander)* | One per check-in and one per reflection, for days within 7 days of today; recorded once, never taken back. The trail position is the number of steps | `StepKey`, `StepAward`, `StepPolicy`, `position` |
| **Trail**, **area** *(Wander)* | The fixed route (version 1, 60 steps); its stretches, each with a banner: Pond Shore, Reed Bed, Willow Grove, Mossy Woods, Mushroom Glade, Meadow | `Trail`, `Area` |
| **Landmark** *(Wander)* | A spot on the trail at a given step, holding an egg, a decoration, a coin pouch, a visitor or just scenery | `Landmark`, `LandmarkContent` |
| **Find** *(Wander)* | Reaching a landmark: it's marked found that day, never un-found, and announced once on a find card | `found`, `foundLandmarks`, `FindCard` |
| **Egg**, **nest**, **basket** *(Wander)* | An egg from a landmark (or the starter); the nest holds one egg at a time and counts its check-ins; the others wait in the basket in the order found | `Egg`, `nestedEgg`, `basket` |
| **Hatch** *(Wander)* | The nested egg becomes a pet once enough check-ins pass (the starter after 1, others after 3); she names it in the hatch moment | `hatchAfterCheckIns`, `pendingHatch`, `HatchView` |
| **Species** *(Wander)* | The kind of pet: pondling, lilac moth, leaf-shell turtle, spotted seal, cinnamon fox | `Species` |
| **Collection**, **active pet** *(Wander)* | Every hatched pet; the one out in the camp, shown on Home | `pets`, `activePetID`, `setActive` |
| **Visitor** *(Wander)* | A one-time guest found on the trail (the fox at dusk), seen once | `LandmarkContent.visitor`, `markVisitorSeen`, `VisitorView` |
| **Pets** (the collection) *(Wander)* | Every hatched pet, the egg in the nest and the basket; choosing one sends it out into the camp | `PetsView`, `setActive` |
| **App coordinator** | The app-layer wiring between contexts: syncs Rewards and the Wander on every journal change and replays Wander finds into Rewards grants and awards | `AppCoordinator` |
