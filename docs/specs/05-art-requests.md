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

## Priority

1. `Camp/pond-background.png` and the 8 new decorations: these unblock the camp, the core loop she cares about most.
2. `Camp/nest.png`, the species eggs and `Animations/hatch.png`.
3. The Wander banners and node icons.
4. The alternates' mood poses and idle loops, and the fox at dusk.
5. The optional loops and the dusk background.
