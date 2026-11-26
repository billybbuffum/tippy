# Spec 05: Art requests

**Goal:** the pixel art that specs 02 and 03 need, matching the existing pack
([`Assets/Sprites/README.md`](../../Assets/Sprites/README.md)).

**Depends on:** nothing. The code falls back to placeholders, so art can land any time. **Parallel with:** everything.

## Conventions (same as the existing pack)

- Original pixel art. Nothing resembling Tipple's fox, camp or style.
- **Stills:** 256 × 256 RGBA PNG, transparent background, with the same canvas padding as the existing sprites so
  poses line up.
- **Loops:** a single-row PNG strip of four 128 × 128 frames, plus a GIF preview. Frame durations go in the README.
  Default quiet loop: 650, 140, 140, 170 ms.
- **Scaled with nearest-neighbour in the app.** Avoid anti-aliased edges and keep the palette consistent with the
  teal pondling.
- **Commit under `Assets/Sprites/`** in the folders below and update its README tables. The app only uses art once a
  spec adds it to `scripts/sync-sprites.py`. Art PRs don't touch code.
- **Every file name below is a contract** the code looks up. Keep the names exactly.

## 1. Camp (spec 02)

| File | Size | Notes |
|---|---|---|
| `Camp/pond-background.png` | 512 × 512, opaque | The camp scene, top-down 3/4 view, with a pond ellipse centred at (0.50, 0.42), size 0.62 × 0.26 of the width. The ground is open around these spots, so decorations sit there naturally. Spots are normalized, origin top-left: `water-1` (0.38, 0.40), `water-2` (0.64, 0.44), `light-1` (0.14, 0.18), `light-2` (0.86, 0.18), pet (0.50, 0.70), nest (0.26, 0.74), `ground-1` (0.10, 0.62), `ground-2` (0.20, 0.88), `ground-3` (0.50, 0.92), `ground-4` (0.80, 0.88), `ground-5` (0.90, 0.62). Keep the spots uncluttered; subtle markings are fine. |
| `Camp/pond-background-dusk.png` | 512 × 512 | Optional evening variant (after 6 PM). |
| `Camp/lily-planter.png` | 256 | Water item. Sits on the pond surface. |
| `Camp/reed-cluster.png` | 256 | Water item. |
| `Camp/flower-pot.png` | 256 | Ground. |
| `Camp/stepping-stones.png` | 256 | Ground, low and wide. |
| `Camp/bench.png` | 256 | Ground. Log bench. |
| `Camp/string-lights.png` | 256 | Light (hangs from the top corners). |
| `Camp/willow-arch.png` | 256 | Ground showpiece, drawn larger in-scene (0.26 of the width). |
| `Camp/firefly-jar.png` | 256 | Light. A special find from the Wander. |
| `Animations/string-lights-twinkle.png`, `Animations/firefly-jar-glow.png`, `Animations/reed-cluster-sway.png`, `Animations/lily-planter-bob.png` | 4 × 128 strips | Quiet loops (default durations). |

## 2. The Wander (spec 03)

| File | Size | Notes |
|---|---|---|
| `Wander/area-pond-shore.png`, `area-reed-bed.png`, `area-willow-grove.png`, `area-mossy-woods.png`, `area-mushroom-glade.png`, `area-meadow.png` | 512 × 256, opaque | Area banners for the trail map, in a consistent style that gets gradually leafier and further from the pond. |
| `Wander/node-found.png`, `node-next.png`, `node-locked.png` | 64 × 64 | Trail stepping-stone markers. |
| `Wander/find-egg.png`, `find-gift.png`, `find-pouch.png`, `find-visitor.png`, `find-scenery.png` | 64 × 64 | Icons on landmark nodes. |
| `Camp/nest.png` | 256 | A twig-and-moss nest for the camp's nest spot (the egg sits in it). |
| `Rewards/coin-pouch.png` | 256 | A small pouch, for pouch finds. |

## 3. Eggs and hatching (spec 03)

| File | Size | Notes |
|---|---|---|
| `Pet/moth-egg.png`, `Pet/turtle-egg.png`, `Pet/seal-egg.png`, `Pet/fox-egg.png` | 256 | Each patterned to hint at its species; same outline as `Pet/egg.png`. |
| `Animations/moth-egg-wiggle.png` (and turtle, seal, fox) | 4 × 128 | Like `egg-wiggle`. |
| `Animations/hatch.png` | 6 × 128 strip | A generic shell crack: frames 1–5 crack and burst, frame 6 is the empty broken shell. Durations 300, 120, 120, 120, 200, 400 ms. The new pet's sprite appears over the last frames in code. |

## 4. Pet moods for the alternates (spec 03)

The alternates have `happy` and `thriving`. Add the rest so every pet reacts gently:

| Files | Notes |
|---|---|
| `Pet/moth-okay.png`, `Pet/moth-concerned.png`, `Pet/moth-waiting.png` | `concerned` is sleepy/cozy, never sad (like the pondling's). `waiting` looks curious. |
| same three for `turtle`, `seal`, `fox` | |
| `Animations/moth-idle.png`, `turtle-idle.png`, `seal-idle.png`, `fox-idle.png` | 4 × 128 breathing loops matching `pet-idle` timing (480, 160, 250, 160 ms). |

## 5. Visitor (spec 03)

| File | Size | Notes |
|---|---|---|
| `Pet/fox-dusk.png` | 256 | The cinnamon fox as a visitor at dusk, sitting, friendly, with a soft lantern-lit palette. Clearly the same original fox as `fox-happy`, not Tipple's. |

## 6. Wander effects and touch-ups

The effects are species-independent, so they serve every current and future pet. Spec 03's movement plan uses
them when they exist and skips them when they don't.

| File | Size and frames | Durations (ms) | Use |
|---|---|---|---|
| `Animations/dust-puff.png` | 3 × 128 strip | 90, 90, 140 | A small puff under the pet on each landing (played once, not looped) |
| `Animations/sparkle.png` | 4 × 128 strip | 120, 120, 120, 200 | Burst over a landmark as its find is revealed; a "!" glint in frame 2 (played once) |
| `Animations/find-glow.png` | 4 × 128 strip | 650, 140, 140, 170 | A soft pulsing ring under the next node on the trail map (looped) |

The dusk fox carries a warm rim light beside a small lantern. The pond-shore and reed-bed banners leave the
route to the map's continuous path layer.

## 7. Immersive UI (spec 06)

The app moves to a full-screen pixel world (see [spec 06](./06-immersive-pixel-ui.md)). One world art pixel is about
3 pt on screen, so a 132 px wide scene spans the phone. Deliver at 4× like everything else: one art pixel is 4 × 4
image pixels.

| File | Art size | PNG size | Notes |
|---|---|---|---|
| `Camp/camp-tall-day.png`, `camp-tall-dusk.png`, `camp-tall-night.png` | 132 × 288 | 528 × 1152, opaque | The whole Home scene: sky at the top (about 70 px, empty enough for the HUD), a treeline, the pond camp in the middle with the spots at the spec 02 positions (relative to a 128 × 128 square starting at art y = 80, x = 2), and plain ground below (about 80 px) for the dock to sit on. The three times of day share every position. |
| `Camp/*` decorations at scene scale | about 20–32 px of content on a 40 × 40 canvas | 160 × 160 | The 13 decorations redrawn smaller for the scene (the current 256 px ones stay for the shop and sheets). Same IDs, suffix `-scene` (`lantern-scene.png`). |
| `Wander/trail-tall.png` | 132 × 1200 (or taller) | 528 × 4800 | One continuous vertical trail from the pond (bottom) to the meadow (top): no repeated skies, areas blending into each other, a path the map can follow. **With four side paths** ([spec 07](./07-wander-forks.md)): at main steps 11, 19, 33 and 49 a smaller path branches off to one side and loops back to the same spot (Heron's Inlet in the reeds, The Hollow Willow, Fern Hollow, The Toadstool Ring), each with room for its signpost and 2 finds. Mark the spots in a sidecar `trail-tall.json`: `{"landmarks": [{"id": "shore-shell", "x": 64, "y": 1150}, …], "forks": [{"id": "reeds-inlet", "x": 70, "y": 900, "path": [[70, 900], [96, 890], …], "landmarks": [{"id": "inlet-pouch", "x": 100, "y": 880}, …]}]}` (art pixels, origin top-left; each fork's `path` runs from the fork round the loop and back). |
| `Wander/signpost.png` | 24 × 24 | 96 × 96 | A wooden signpost for forks and area names; the name is drawn in code on its board. |
| `Camp/pebble-cairn.png`, `Camp/lily-bloom.png`, `Camp/glow-mushrooms.png` (and `-scene`) | 64 (and 40) | 256 (and 160) | Side-path finds for spec 07: a little stack of pond pebbles (ground), a lily in full bloom (water), a cluster of softly glowing mushrooms (light). Find-only, never in the shop. |
| `UI/panel-parchment.png`, `UI/panel-wood.png` | 12 × 12 | 48 × 48 | 9-slice panel frames: 4 px corners. They replace the drawn panels when present. |
| `UI/button-*.png` | 12 × 12 | 48 × 48 | 9-slice buttons (`primary`, `leaf`, `wood`, `parchment`), each with a `-pressed` variant. |
| `UI/dock.png` | 132 × 48 | 528 × 192 | The wooden dock, tileable horizontally. |
| `UI/icon-*.png` | 8 × 8 | 32 × 32 | `mug`, `leaf`, `map`, `paw`, `brush`, `bag`, `calendar`, `gear`, `coin`, `book`, plus a speech bubble 9-slice (`UI/bubble.png`, 12 × 12 with a tail). |

Until these land, the app draws all of them itself, from the existing pond background and the willow-grove banner,
on the same grids.

## Priority

1. `Camp/pond-background.png` and the 8 new decorations: these unblock the camp, the core loop she cares about most.
2. `Camp/nest.png`, the species eggs and `Animations/hatch.png`.
3. The Wander banners and node icons.
4. The alternates' mood poses and idle loops, and the fox at dusk.
5. The optional loops and the dusk background.
6. The effects and touch-ups in section 6.
7. The immersive UI art in section 7: the tall camp scene first, then the tall trail with its side paths.
