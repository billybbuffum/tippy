# Tippy sprite pack

Original pixel art of a teal pond creature and objects for its camp. Each sprite
is a separate 256 × 256 RGBA PNG with a transparent background.

| Folder | Sprites |
| --- | --- |
| `Pet/` | `thriving`, `happy`, `okay`, `concerned`, `waiting`, `egg` |
| `Rewards/` | `coin` |
| `Camp/` | `sprout`, `mushroom`, `watering-can`, `lantern`, `seashell` |
| `Drinks/` | `water`, `beer`, `wine`, `cocktail` |

The five mood filenames match the raw values of `PetMood` in
`Modules/TippyModeration`. Keep their canvas padding when swapping moods so
the poses stay aligned. Use nearest-neighbor scaling to preserve the pixel
edges (`.interpolation(.none)` in SwiftUI).

These are source assets under `Assets/`. To use a sprite at runtime, add it
to the app target's resources and load it from that resource bundle.

## Animations

Each PNG strip has four transparent 128 × 128 frames in a single row.
Read left to right, starting at x = 0, 128, 256, and 384. The GIFs show
the loops at their intended speed.

| Strip | Frame durations (ms) | Preview |
| --- | --- | --- |
| `pet-idle.png` | 480, 160, 250, 160 | ![Pet breathing](Animations/pet-idle.gif) |
| `pet-hop.png` | 480, 100, 160, 110 | ![Pet hopping](Animations/pet-hop.gif) |
| `coin-shimmer.png` | 250, 100, 120, 100 | ![Coin turning](Animations/coin-shimmer.gif) |

## App icon

[`Assets/DefaultIcon.png`](../DefaultIcon.png) is the matching opaque 1024 ×
1024 icon. The existing build script uses it when the optional private icon
is unavailable.

### Alternate pets

The cinnamon fox, lilac moth, leaf-shell turtle, and spotted seal each have a
`<pet>-happy.png` idle pose and a `<pet>-thriving.png` delighted pose in `Pet/`.
Each also has a four-frame `<pet>-delight.png` strip in `Animations/`, with
frame durations of 620, 180, 120, and 180 ms.

[Fox](Animations/fox-delight.gif) · [Moth](Animations/moth-delight.gif) ·
[Turtle](Animations/turtle-delight.gif) · [Seal](Animations/seal-delight.gif)

### Small prop loops

The 650 ms resting frame gives each of these four-frame loops a quiet beat.
Use frame durations of 650, 140, 140, and 170 ms. Each preview links to the GIF
beside its identically named PNG strip.

| Sprite | Preview |
| --- | --- |
| Egg | [Wiggle](Animations/egg-wiggle.gif) |
| Sprout | [Sway](Animations/sprout-sway.gif) |
| Mushroom | [Bob](Animations/mushroom-bob.gif) |
| Watering can | [Tilt](Animations/watering-can-tilt.gif) |
| Lantern | [Glow](Animations/lantern-glow.gif) |
| Seashell | [Glint](Animations/seashell-glint.gif) |
| Water | [Glint](Animations/water-glint.gif) |
| Beer | [Bob and glint](Animations/beer-bob.gif) |
| Wine | [Sway](Animations/wine-sway.gif) |
| Cocktail | [Glint](Animations/cocktail-glint.gif) |
