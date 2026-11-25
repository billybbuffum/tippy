# Tippy sprite pack

Original pixel art of a teal pond creature and objects for its camp. Stills are 256 × 256 RGBA PNGs with transparent backgrounds unless a table specifies a different size.

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

PNG strips contain transparent 128 × 128 frames in a single row.
Read left to right in 128-pixel increments. The GIFs show
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


### Camp and Wander

| Folder | Files | Size |
| --- | --- | --- |
| `Camp/` | `pond-background`, `pond-background-dusk` | 512 × 512, opaque |
| `Camp/` | `lily-planter`, `reed-cluster`, `flower-pot`, `stepping-stones`, `bench`, `string-lights`, `willow-arch`, `firefly-jar`, `nest` | 256 × 256 |
| `Rewards/` | `coin-pouch` | 256 × 256 |
| `Wander/` | `area-pond-shore`, `area-reed-bed`, `area-willow-grove`, `area-mossy-woods`, `area-mushroom-glade`, `area-meadow` | 512 × 256, opaque |
| `Wander/` | `node-found`, `node-next`, `node-locked`, `find-egg`, `find-gift`, `find-pouch`, `find-visitor`, `find-scenery` | 64 × 64 |
| `Pet/` | `<pet>-egg`, `<pet>-okay`, `<pet>-concerned`, `<pet>-waiting` for moth, turtle, seal, and fox, plus `fox-dusk` | 256 × 256 |

Both Camp backgrounds share the placement coordinates defined in the [art spec](../../docs/specs/05-art-requests.md).

| Strip | Frames | Frame durations (ms) | Preview |
| --- | --- | --- | --- |
| `firefly-jar-glow.png` | 4 | 650, 140, 140, 170 | [GIF](Animations/firefly-jar-glow.gif) |
| `fox-egg-wiggle.png` | 4 | 650, 140, 140, 170 | [GIF](Animations/fox-egg-wiggle.gif) |
| `fox-idle.png` | 4 | 480, 160, 250, 160 | [GIF](Animations/fox-idle.gif) |
| `hatch.png` | 6 | 300, 120, 120, 120, 200, 400 | [GIF](Animations/hatch.gif) |
| `lily-planter-bob.png` | 4 | 650, 140, 140, 170 | [GIF](Animations/lily-planter-bob.gif) |
| `moth-egg-wiggle.png` | 4 | 650, 140, 140, 170 | [GIF](Animations/moth-egg-wiggle.gif) |
| `moth-idle.png` | 4 | 480, 160, 250, 160 | [GIF](Animations/moth-idle.gif) |
| `reed-cluster-sway.png` | 4 | 650, 140, 140, 170 | [GIF](Animations/reed-cluster-sway.gif) |
| `seal-egg-wiggle.png` | 4 | 650, 140, 140, 170 | [GIF](Animations/seal-egg-wiggle.gif) |
| `seal-idle.png` | 4 | 480, 160, 250, 160 | [GIF](Animations/seal-idle.gif) |
| `string-lights-twinkle.png` | 4 | 650, 140, 140, 170 | [GIF](Animations/string-lights-twinkle.gif) |
| `turtle-egg-wiggle.png` | 4 | 650, 140, 140, 170 | [GIF](Animations/turtle-egg-wiggle.gif) |
| `turtle-idle.png` | 4 | 480, 160, 250, 160 | [GIF](Animations/turtle-idle.gif) |

### Wander effects

| Strip | Frames | Frame durations (ms) | Playback | Preview |
| --- | --- | --- | --- | --- |
| `dust-puff.png` | 3 | 90, 90, 140 | Once | [GIF](Animations/dust-puff.gif) |
| `sparkle.png` | 4 | 120, 120, 120, 200 | Once | [GIF](Animations/sparkle.gif) |
| `find-glow.png` | 4 | 650, 140, 140, 170 | Loop | [GIF](Animations/find-glow.gif) |
