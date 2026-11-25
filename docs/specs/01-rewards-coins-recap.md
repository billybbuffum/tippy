# Spec 01: Rewards, coins and the weekly recap

**Goal:** every honest check-in earns coins she can see, and each finished week ends with a short, warm recap
that awards the goal bonus. This creates the `TippyRewards` context that spec 02 (Camp) builds on.

**Depends on:** `main`. **Parallel with:** 03, 05. **Read first:** [specs README](./README.md) contracts 1–7,
[`architecture.md`](../architecture.md) §3–8.

## Scope

In scope:
- the `TippyRewards` package: coin ledger, earning rules, weekly recaps;
- `RewardsStore` with its file adapter;
- `RewardsModel`;
- the journal change hook (contract 2), if not already on `main`;
- a coin badge on Home and a "+N coins" toast;
- the weekly recap sheet.

Out of scope:
- the shop, purchases and placements (spec 02; leave room in the aggregate);
- Wander pouches (spec 03 calls `award(coins:key:)`, added here);
- backup of rewards (spec 04).

## Domain: `Modules/TippyRewards` (Foundation only, Swift 6 mode)

`Package.swift` mirrors `TippyModeration`'s (tools 6.0, iOS 17 and macOS 13, `swiftLanguageModes: [.v6]`) and
depends on `../TippyModeration`.

### Types

```swift
/// "checkIn:2026-11-19", "drinkFree:2026-11-19", "weekGoal:2026-11-16", "pouch:<landmark>", "find:<landmark>".
public struct AwardKey: Hashable, Codable, Sendable, CustomStringConvertible {
    public let rawValue: String
    public static func checkIn(_ day: LocalDate) -> AwardKey
    public static func drinkFree(_ day: LocalDate) -> AwardKey
    public static func weekGoal(_ week: Week) -> AwardKey      // keyed by week.start
    public static func pouch(_ landmarkID: String) -> AwardKey
    public static func find(_ landmarkID: String) -> AwardKey  // used by spec 02 grants
}

public struct Award: Hashable, Codable, Sendable {
    public let key: AwardKey
    public let coins: Int          // > 0
    public let earnedOn: LocalDate // the day the fact belongs to (week end for weekGoal)
}

public struct EarningRules: Sendable {
    public var checkIn = 5
    public var drinkFreeBonus = 3
    public var weekGoalBonus = 15
    public var backfillDays = 7          // a day earns only if day >= today - backfillDays
    public var goalBonusMinDaysLogged = 5 // a week must be honestly logged to earn its bonus
    public var goalBonusLookbackWeeks = 4 // only weeks that ended in the last 4 weeks
    public static let standard = EarningRules()
}

public struct WeeklyRecap: Hashable, Codable, Sendable {
    public let weekStart: LocalDate
    public let seenAt: Date
    /// Her optional "one thing to try next week".
    public var nextWeekIdea: String?
}
```

### Aggregate: `RewardsLedger`

```swift
public struct RewardsLedger: Hashable, Codable, Sendable {
    public static let currentVersion = 1
    public private(set) var awards: [AwardKey: Award]
    public private(set) var recaps: [LocalDate: WeeklyRecap]   // keyed by week start
    // Spec 02 adds: purchases, owned items, placements. Encode new fields with decodeIfPresent defaults.

    public var earned: Int                      // sum of award coins
    public var balance: Int                     // earned - spent (spent = 0 until spec 02)

    /// Records an award unless its key exists. Returns true if it was new.
    @discardableResult public mutating func record(_ award: Award) -> Bool
    public mutating func markRecapSeen(_ week: Week, at: Date, nextWeekIdea: String?)
    public func hasSeenRecap(for week: Week) -> Bool
    public func coinsEarned(in week: Week) -> Int  // awards whose earnedOn is inside the week
}
```

Invariants:
- an award's coins are greater than 0;
- keys are unique;
- awards are never removed;
- one recap per week (seeing it again updates `nextWeekIdea` only).

Codable rules are as in `Journal`: a `version` key, missing fields fall back to defaults, a newer version is
refused, and dictionaries are encoded as sorted arrays.

### Domain services

```swift
public enum AwardPolicy {
    /// Every award the journal currently qualifies for. The ledger ignores ones already recorded.
    public static func eligibleAwards(journal: Journal, today: LocalDate, rules: EarningRules = .standard) -> [Award]
}

public enum RecapPolicy {
    /// The week to recap now, or nil: only the week just before the current one, if it had at
    /// least one check-in and hasn't been seen. No queue of older weeks.
    public static func weekToRecap(journal: Journal, ledger: RewardsLedger, today: LocalDate) -> Week?
}
```

`eligibleAwards` returns:
- **`checkIn(d)`:** 5 coins for each logged day `d` (drinks or drink-free) with `today - 7 <= d <= today`.
- **`drinkFree(d)`:** +3 for each drink-free day in that same window.
- **`weekGoal(w)`:** +15 for each finished week `w` (`w.end < today`) that meets all of these:
  - it ended within the last 4 weeks;
  - `summary.checkedInDays >= 5`;
  - `summary.metGoal`, using `journal.goal(for: w)`, the goal that week had.

Unit tests cover, at minimum:
- the amounts;
- the back-fill window edges (7 days earns, 8 doesn't);
- a drink-free day logged, then turned into a drink day: the bonus stays, since awards are never revoked;
- the goal bonus needing 5 logged days;
- a goal change mid-history using that week's own goal;
- weekly recap selection (only last week, needs a check-in, not if seen);
- `record` idempotency;
- the codec round-trip;
- decoding an old shape with missing fields;
- refusing a newer version.

### Port

```swift
public protocol RewardsStore { func load() throws -> RewardsLedger?; func save(_ ledger: RewardsLedger) throws }
public enum RewardsCodec { encode / decode }   // same style as JournalCodec
```

## App layer

- **`Adapters/FileRewardsStore.swift`:** `rewards.json`, a copy of `FileJournalStore`'s behaviour.
- **`Demo/DemoAdapters.swift`:** add `InMemoryRewardsStore`.
- **`Model/RewardsModel.swift`:** `@MainActor @Observable final class RewardsModel`:
  - **State:** `ledger`, `balance`, `message`.
  - **`lastEarned: Int?`:** coins from the latest sync that recorded something new. The view shows a toast, then
    calls `acknowledgeEarned()`.
  - **`pendingRecap: Week?`:** refreshed on every sync.
  - **`sync(journal:today:)`:** records `AwardPolicy.eligibleAwards`, saves if anything is new, sets `lastEarned`,
    and updates `pendingRecap`.
  - **`award(coins:key:on:)` and `grant(itemID:key:)`:** for the coordinator. `grant` is a stub until spec 02;
    leave a `// spec 02` note.
  - **`markRecapSeen(_ week:, nextWeekIdea:)`.**
  - **`coinsEarned(in:)`.**
  - All writes go through one private `mutate`, like `JournalModel`.
- **Composition (`App/TippyApp.swift`):** build `RewardsModel` (and `JournalModel`), register
  `journal.onJournalChange { rewards.sync(journal: $0, today: $1) }`, and inject both with `.environment(...)`.
  `TippyApp` keeps a small holder (an `AppModels` struct or similar) rather than one `@State` per model.
  `UISmokeMode.makeModel` builds the same graph with in-memory stores.

## UI

| Element | Where | Identifier | Behaviour |
|---|---|---|---|
| Coin badge | Home toolbar, trailing, before the gear | `coin-balance-label` (the label), `coin-badge-button` (the button) | Coin sprite (still pose under Reduce Motion, `coin-shimmer` otherwise) plus the balance. Tapping it does nothing until spec 02 (shop). |
| Earned toast | Home, top, over the scene | `coins-earned-toast` | "+5 coins" with the coin, slides in after a sync that earned coins, gone after about 2 s. No sound or haptic. Under Reduce Motion it fades. |
| Weekly recap | Sheet from Home when `pendingRecap != nil`, presented once on appear (not over another sheet) | `weekly-recap-view` | See below. |

**Recap contents**, in this order:
1. **Title:** "Your week, Nov 10–16".
2. **Pet sprite:** `thriving` if the goal was met, `happy` otherwise. Never sad.
3. **Total against that week's goal:** `recap-total-label`, for example "11.0 of 14 drinks". Neutral wording only.
4. **Drink-free days and days logged:** `recap-days-label`.
5. **Coins earned that week:** `recap-coins-label`. Include the goal-bonus line, "+15 for staying within your
   goal", only if it was earned.
6. **Her reflections from that week:** list each prompt and answer. If there are none, show a gentle line.
7. **An optional "One thing to try next week" field:** `recap-idea-field`.
8. **Done button:** `recap-done-button`. It marks the recap seen and saves the idea.

The idea she wrote appears on Home during the following week as a small card (`recap-idea-card`) with an `×`
to hide it. The hide state is presentation-only, kept in `@AppStorage`, and is allowed because it is a per-device
convenience.

## Sprites

Add `Rewards/coin.png` and `Animations/coin-shimmer.png` (frame durations 250, 100, 120, 100 ms) to the
`sync-sprites.py` `MANIFEST`, plus a `SpriteAnimation.coinShimmer`.

## Demo seeds and smoke scenarios

| Seed | State |
|---|---|
| `last-week-done` | Last week (Nov 9–15) logged 6 of 7 days at 10 drinks against a goal of 14, one reflection. The ledger already holds those days' check-in and drink-free awards, as if synced live; the week-goal award isn't recorded yet. Recap not seen; this week empty. |
| `coins` | The `default` seed plus a ledger worth 120 coins (synthetic awards). Spec 02 uses it. |

| Scenario | Seed | Shows |
|---|---|---|
| `earn-coins` | `default` | Mark today drink-free, skip the reflection, see the toast, and `coin-balance-label` reads 8. |
| `weekly-recap` | `last-week-done` | The recap opens on launch with total, days and coins including +15. Type an idea, Done; the idea card is on Home. |
| `backfill-earns` | `default` | Back-fill a drink-free day 3 days ago from History; the balance goes up by 8. |

Update existing scenarios only if the toast or recap gets in their way (`default` has no finished week, so the recap
shouldn't appear).

## Acceptance

- Logging, editing, deleting and relaunching never change the balance except by adding new awards.
- A seeded finished week shows its recap exactly once. Coming back after three weeks away shows only last week's
  recap, never a queue.
- The coin badge, toast and recap work with VoiceOver: the badge reads "120 coins", and the toast is announced.
- The glossary in `architecture.md` §13 is updated: coins, award, award key, back-fill window, weekly recap,
  next-week idea.
