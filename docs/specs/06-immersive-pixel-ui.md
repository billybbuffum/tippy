# Spec 06: Immersive pixel UI

**Goal:** the whole screen is the pixel world. Home is the camp, edge to edge: sky, treeline, pond and ground fill
the phone. Every control is a pixel-art game piece on top of it (panels, buttons, a wooden dock, the pet's speech
bubble), not a window into the pond framed by standard iOS controls. Other screens follow: sheets become parchment
cards over the dimmed scene, and the Wander becomes one continuous trail.

**Concept mockups** (built from the real sprites) were reviewed on 26 November 2026: Home, Log a drink, and the
Wander, next to today's app.

**Depends on:** `main` (specs 01–04). **Art:** [spec 05 §7](./05-art-requests.md#7-immersive-ui-spec-06). Every
screen works with placeholders until that art lands.

## Principles

1. **One world grid.** The scene uses one art pixel = `screenWidth / 132` points (≈ 3 pt on a 393 pt wide phone).
   All world art sits on that grid: the existing sprites are 64 px art at 4× and the scenes 128 px art, so they snap
   cleanly (`.interpolation(.none)`, sizes in whole art pixels).
2. **One UI grid.** HUD panels, buttons and text use a finer grid of **2 pt per UI pixel**. Panels have a 1 UI px
   plum outline with cut corners, a highlight row, a shade row and a 1 px drop shadow. Nothing uses system
   materials, blur, SF Symbols in the HUD, or rounded iOS cards on Home.
3. **Pixel type.** These fonts are bundled and registered at launch, with their licence (SIL Open Font License) in
   `Sources/Tippy/Resources/Fonts/`:
   - **Pixelify Sans** for text: 10 UI px for body, 13 for names and titles;
   - **Silkscreen** for small caps labels (8 UI px).

   **At accessibility text sizes** (`dynamicTypeSize >= .accessibility1`), text falls back to the rounded system
   font so it stays readable.
4. **The pet carries the voice.** Today's status is the pet's speech bubble ("How was today?"), not a card. Weekly
   numbers stay neutral and live in the HUD.
5. **Nothing about behaviour changes.** Same models, same rules, same accessibility identifiers and labels. Visible
   text may be shorter than the accessibility label (the week meter shows `6/14`, VoiceOver hears "6.0 of 14 drinks
   this week"). Smoke scenarios only change where they used the hidden navigation bar as Home's marker; they use
   `home-screen` instead.
6. **Motion stays gentle.** Stars twinkle, the pet idles and decorations loop only when `MotionAllowed`. Under
   Reduce Motion and in demo mode everything is still.
7. **Always light.** The app sets `UIUserInterfaceStyle` to Light (and `.preferredColorScheme(.light)`), because
   system controls kept on the pixel screens (calendars, pickers, the keyboard) draw near-white text in dark mode,
   which vanishes on parchment. Found on her phone: the drink-free day calendar showed only today.

## Pixel UI kit (`Sources/Tippy/Views/Pixel/`)

| Piece | What it is |
|---|---|
| `PixelPalette` | The palette: plum outline, cream and parchment, teal (the pondling), leaf green, wood, gold. Day, dusk and night sky bands. |
| `PixelFont` | `.pixelBody(size)`, `.pixelLabel(size)`, with the Dynamic Type fallback. `PixelFonts.register()` is called once by the composition root. |
| `PixelPanel` | A `View` background drawn with `Canvas` on the UI grid: outline, cut corners, highlight, shade, shadow. Styles: `.parchment`, `.wood`, `.teal`, `.leaf`. Modifier: `.pixelPanel(.parchment)`. |
| `PixelButtonStyle` | `ButtonStyle` on a `PixelPanel`. When pressed, the button moves down 1 px and loses its shadow. Kinds: `.primary` (teal), `.leaf`, `.wood`, `.parchment`. Disabled buttons are desaturated. |
| `PixelIcon` | Small hand-made icons as string bitmaps (mug, leaf, map, paw, brush, bag, calendar, gear, coin), drawn on the UI grid. Spec 05 §7 replaces them with drawn art. |
| `SpeechBubble` | A parchment bubble with a tail, pointing at a spot in the scene. |
| `PixelDock` | The wooden plank shelf at the bottom (wood planks drawn on the UI grid), respecting the home indicator. |

## Home

```
┌──────────────────────────────┐  the world fills everything, ignoring safe areas
│ sky (bands, stars, moon/sun) │
│ [Sprout · THRIVING] [◎ 120][⚙]│  HUD: nameplate + mood, coins (opens the shop), Settings
│ [THIS WEEK ▮▮▮▮▮▯▯ 6/14]    │  week meter: drink-free days and days logged under it
│ treeline                     │
│ pond camp: decorations, pet, │  CampSceneView at scene scale, no rounded corners
│   nest; speech bubble        │
│ [⚑ WANDER → 3 steps to …]    │  signpost (wander-next-label): the one way into the Wander
├──────────────────────────────┤
│ [ Log a drink ] [ None ]     │  the dock
│ [PETS]  [CAMP]  [HISTORY]    │
└──────────────────────────────┘
```

**The scene** (`Views/Home/WorldBackdrop.swift`), in art pixels:
- **Sky:** day, dusk or night by the hour, from `model.now`.
- **Treeline:** a 32 px band above the pond. Until spec 05 §7 delivers the tall camp scene, it's the upper band of
  `area-willow-grove`.
- **The pond camp:** 128 px. Its top sits so its bottom is about 70 pt above the dock, and never higher than the
  HUD allows.
- **Ground:** below the pond to the bottom, tiled from the pond background's bottom band.

**One-time notices** (find card, reminder offer, next-week idea) stack under the HUD as parchment panels, in that
order.

**The dock:**
- **First row:** `log-drink-button` (primary) and `drink-free-button` (leaf).
- **Second row:** `pets-button`, `decorate-button` (labelled Camp) and `history-button`, each a word under its icon.
- **One way to each place** (changed after she tried it: eleven controls with duplicates felt cluttered). The
  Wander opens only from the signpost, the shop from the coin badge or inside Camp, and History from the dock. There
  is no separate Wander or Shop button on the dock, and no icon-only History button in the HUD.
- **In decorate mode** the dock swaps to `shop-button`, the hint, and `decorate-done-button`.

**Identifiers kept:**
- `pet-name-label`, `pet-view`
- `today-status-label` (on the bubble)
- `week-total-label`, `drink-free-count-label`, `days-logged-label`
- `coin-badge-button`, `coin-balance-label`
- `history-button`, `settings-button`
- `wander-next-label`, `pets-button` (`wander-button` is gone: the signpost opens the Wander)
- `nest-view`, `nest-countdown-label`
- `camp-scene`, every `camp-slot-*` and `camp-item-*`
- `find-card`, `reminder-offer-card`, `recap-idea-label`

**New:** `home-screen`, on Home's root.

## Later screens (each its own PR, in this order)

1. **Sheets as parchment:** Log a drink, Reflection, Shop, slot sheet, weekly recap, hatch, visitor. These are
   `PixelPanel` cards over the dimmed scene, with a title ribbon and pixel buttons.
   - `ParchmentSheet` replaces each sheet's navigation bar: Cancel or Skip on the left, the `TitleRibbon` in the
     middle, Save or Done on the right. Each sheet gets a root identifier, which scenarios use in place of the
     navigation bar: `log-drink-sheet`, `edit-drink-sheet`, `reflection-sheet`, `shop-sheet`, `slot-sheet`,
     `recap-sheet` (the visitor keeps `visitor-dialog`, the hatch `hatch-view`).
   - Forms become `PixelSection`s (a small caps heading over a paper card) with `PixelStepper`, the `.pixel`
     toggle style, `PixelSegmented` and `.pixelField()`. The date picker stays the system one.
   - The shop's "Buy this decoration?" is a pixel card over the shop (`confirm-buy-dialog`), not a system alert.
   - The hatch moment is a full-screen cover with a clear background: a parchment card over the dimmed Home.
2. **The Wander:** one continuous vertical trail painting (spec 05 §7), with the path, nodes and pet on the world
   grid, and the area name on signposts. Built together with [spec 07](./07-wander-forks.md)'s forks and side
   paths, so the painting and the map are made once with their branches.
3. **History, Pets, Settings:** parchment lists inside a wooden frame. Settings keeps system controls where a pixel
   version would hurt accessibility (date pickers, the file picker).
   - Pushed screens (History, Pets) use `.pixelScreen(_:identifier:)`: wooden planks, the title on a ribbon, and the
     content in a parchment frame. They keep the system back button, because hiding the navigation bar would also
     lose the swipe back. Markers: `history-screen`, `pets-screen`.
   - Settings, the restore preview and History's drink-free day are parchment sheets: `settings-sheet`,
     `restore-preview`, `drink-free-day-sheet`. Mark a day drink-free moves from the toolbar into the screen.

## Acceptance (Home)

- Home shows no system navigation bar, materials or iOS cards. Everything visible is world art or the pixel kit.
- Works on a 6.1" and a 6.9" phone, and on an SE-size phone where the scene compresses: the pond stays fully
  visible and nothing sits under the dock.
- Under Reduce Motion nothing loops. At accessibility text sizes the HUD text switches font and still fits (panels
  grow).
- All 27 existing smoke scenarios pass, with Home's marker changed to `home-screen`.
- Fonts ship with their OFL licence. The architecture check allows the `CoreText` import needed to register them.
