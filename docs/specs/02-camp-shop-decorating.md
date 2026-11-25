# Spec 02: Camp, the shop and decorating

**Goal:** Home becomes her pond camp. She spends coins in a shop and places decorations in the scene. Moving and
storing items is free. Week two still has things to want.

**Depends on:** spec 01 merged (it extends `TippyRewards` and `RewardsModel`). **Parallel with:** 03, 05.
**Read first:** [specs README](./README.md) (especially contracts 3, 4 and 6), [spec 01](./01-rewards-coins-recap.md).

## Scope

In scope:
- the catalog and slots;
- purchases, ownership and placements in `RewardsLedger`;
- `grant` for Wander finds;
- the camp scene on Home, the shop and the decorate mode.

Out of scope:
- art (spec 05; use placeholders until it lands);
- the nest and multiple pets (spec 03 adds them to the scene through the hooks defined here).

## Domain: additions to `Modules/TippyRewards`

### Catalog (bundled content: stable IDs, never renamed or reused)

```swift
public enum SlotKind: String, Codable, Sendable { case ground, water, light }

public struct CampSlot: Identifiable, Hashable, Sendable { public let id: String; public let kind: SlotKind }

public struct CatalogItem: Identifiable, Hashable, Sendable {
    public let id: String            // "lantern"
    public let name: String          // "Paper lantern"
    public let price: Int            // coins
    public let kind: SlotKind
    public let spritePath: String    // "Camp/lantern"
    public let inShop: Bool          // false for Wander-only finds
}

public enum CampCatalog {
    public static let slots: [CampSlot]
    public static let items: [CatalogItem]
    public static func item(_ id: String) -> CatalogItem?
}
```

**Slots** (9):
- `light-1`, `light-2` (light)
- `ground-1` … `ground-5` (ground)
- `water-1`, `water-2` (water)

**Items** (13 to start). Prices follow the plan: three starters, a middle band, then showpieces.

| ID | Name | Kind | Price | In shop | Art |
|---|---|---|---|---|---|
| `lantern` | Paper lantern | light | 10 | yes | exists |
| `sprout` | Little sprout | ground | 12 | yes | exists |
| `seashell` | Seashell | ground | 12 | yes | exists |
| `mushroom` | Spotted mushroom | ground | 25 | yes | exists |
| `watering-can` | Watering can | ground | 30 | yes | exists |
| `lily-planter` | Lily pad planter | water | 35 | yes | spec 05 |
| `flower-pot` | Flower pot | ground | 40 | yes | spec 05 |
| `stepping-stones` | Stepping stones | ground | 45 | yes | spec 05 |
| `reed-cluster` | Reed cluster | water | 50 | yes | spec 05 |
| `bench` | Log bench | ground | 60 | yes | spec 05 |
| `string-lights` | String lights | light | 90 | yes | spec 05 |
| `willow-arch` | Willow arch | ground | 150 | yes | spec 05 |
| `firefly-jar` | Firefly jar | light | 0 | **no**: found on the Wander (spec 03) | spec 05 |

### Ledger additions

```swift
public struct Purchase: Hashable, Codable, Sendable { public let itemID: String; public let price: Int; public let at: Date }

// in RewardsLedger
public private(set) var purchases: [Purchase]
public private(set) var owned: Set<String>                  // bought or granted
public private(set) var grants: [AwardKey: String]          // find:<landmark> -> itemID (idempotent)
public private(set) var placements: [String: String]        // slotID -> itemID
public var spent: Int                                        // sum of purchase prices
public var balance: Int { earned - spent }

public enum Problem: Error, Equatable, Sendable {
    case unknownItem, notForSale, alreadyOwned, insufficientCoins, notOwned, unknownSlot, wrongSlotKind
}

public mutating func buy(_ itemID: String, at: Date) throws        // checks all of the above, atomically
@discardableResult public mutating func grant(_ itemID: String, key: AwardKey) -> Bool  // no-op if key seen
public mutating func place(_ itemID: String, in slotID: String) throws
public mutating func store(slotID: String)                          // empties the slot; the item stays owned
public func storedItems() -> [String]                               // owned but not placed
public func item(in slotID: String) -> String?
```

Rules:
- **One of each item.** Buying something already owned fails with `alreadyOwned`. Keep it simple; duplicates
  can come later.
- **Placing** an owned item into a slot of the matching kind. If that item is already placed elsewhere, it moves.
  If the target slot is occupied, the previous item goes back to storage (a swap). Moving and storing are free.
- **Grants** add to `owned` without spending, once per key.
- **On load, invariants are repaired:** placements of unknown or unowned items are dropped, and so are mismatched
  kinds. Purchases are kept as history.
- **The balance never goes negative.** `buy` checks it at commit time.

Tests cover:
- every `Problem` case;
- a swap on an occupied slot;
- moving an item between slots;
- storing an item;
- grant idempotency;
- an exact-balance purchase;
- the codec round-trip with the new fields;
- decoding an older spec-01 file, which has no purchases.

## App layer

`RewardsModel` gains:
- `buy(_:)`, `place(_:in:)`, `store(slotID:)` and `grant(itemID:key:)`, which replaces spec 01's stub;
- the derived values `catalog`, `owned`, `stored`, `placements` and `affordable(_:)`.

Every write goes through `mutate`. Errors set `message`, and `RootView`'s alert shows it. Extend the alert so it
shows any model's message.

## UI

### Camp scene (replaces `PetView` at the top of Home)

`Views/Camp/CampSceneView.swift` is a square scene:
1. **Background:** the `Camp/pond-background` sprite. If it's missing, draw a placeholder (a soft green ground
   with a blue pond ellipse at the coordinates below).
2. **Placed decorations:** drawn at their slot centres, scaled to the scene.
3. **The active pet** in its mood pose (today's `PetView`) at the pet spot.
4. **A nest spot:** spec 03 fills it. Expose `CampSceneView(nest: AnyView?)`, or better, a generic
   `@ViewBuilder nest` closure that defaults to empty.

Positions are normalized (0…1, origin top-left), and spec 05 paints the background to match:

| Spot | x | y | Notes |
|---|---|---|---|
| Pond (ellipse) | 0.50 | 0.42 | size 0.62 × 0.26 |
| `water-1` | 0.38 | 0.40 | |
| `water-2` | 0.64 | 0.44 | |
| `light-1` | 0.14 | 0.18 | top-left |
| `light-2` | 0.86 | 0.18 | top-right |
| Pet | 0.50 | 0.70 | sprite about 0.34 of the scene's width |
| Nest (spec 03) | 0.26 | 0.74 | |
| `ground-1` | 0.10 | 0.62 | |
| `ground-2` | 0.20 | 0.88 | |
| `ground-3` | 0.50 | 0.92 | |
| `ground-4` | 0.80 | 0.88 | |
| `ground-5` | 0.90 | 0.62 | |

Decorations are about 0.16 of the scene's width; `willow-arch` is 0.26. Draw back to front by y. All sprites use
nearest-neighbour scaling. Decorations with loop strips in spec 05 (lantern glow, sprout sway, …) animate only when
`MotionAllowed` says so.

### Shop

- **Opening it:** the coin badge (`coin-badge-button`) or a "Shop" button in decorate mode (`shop-button`) opens
  `Views/Camp/ShopView.swift` as a sheet titled "Shop".
- **The list:** a grid of `inShop` items, each showing its sprite (or a placeholder), name, price and state:
  Owned / Buy / Not enough coins. Identifiers: `shop-item-<id>`, `buy-<id>-button`.
- **The balance** shows at the top: `shop-balance-label`.
- **Buying** asks for confirmation ("Buy Paper lantern for 10 coins?"), then shows a short celebratory state and
  offers "Place it now" (`place-now-button`), which jumps into decorate mode with that item selected.

### Decorate mode

- **Entering:** the "Decorate" button (`decorate-button`) under the scene turns on decorate mode. Every slot shows
  an outline (`camp-slot-<slotID>`); occupied slots show their item.
- **Tap a slot:** a sheet lists stored items of that kind (`place-<itemID>-button`). If the slot is occupied it
  also offers "Put away" (`store-item-button`).
- **Tap a placed item:** select it, then tap another compatible slot to move it.
- **Leaving:** "Done" (`decorate-done-button`). Drag-and-drop is optional and out of scope.
- **Tap only:** no gestures are required, so it works with VoiceOver. Every slot has a label, such as "Ground spot
  2, empty" or "Light spot 1, Paper lantern".

## Demo seeds and smoke scenarios

| Seed | State |
|---|---|
| `coins` (from 01) | 120 coins, nothing owned |
| `furnished-camp` | 60 coins; owns lantern, sprout, seashell, mushroom and lily-planter; places all but the mushroom |

| Scenario | Seed | Shows |
|---|---|---|
| `buy-and-place` | `coins` | Shop, buy the lantern, Place it now, tap `light-1`; it's in the scene and the balance is 110. |
| `shop-not-enough` | `coins` | `willow-arch` shows "Not enough coins" and its buy button is disabled. |
| `decorate-move-store` | `furnished-camp` | Move the sprout to another ground slot, put away the seashell, place the mushroom. |

## Acceptance

- In the first session, the starter coins buy a choice between three items (10–12 each).
- Buying twice can't charge twice: a rapid double tap is guarded in the model and the ledger. A purchase and its
  ownership are saved together.
- Everything placed is still there after relaunch. Moving and storing never change the balance.
- If decoration art is missing, the scene still works with placeholders.
- Glossary: camp, catalog item, slot, purchase, owned, placement, stored, grant.
