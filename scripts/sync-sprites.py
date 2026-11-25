#!/usr/bin/env python3
"""Copies the sprites the app uses from Assets/Sprites (the source art) into
the app target's resources (Sources/Tippy/Resources/Sprites), which SwiftPM
bundles and xtool packs into the app. Only the files in MANIFEST are copied,
so the app doesn't ship art it doesn't use.

    scripts/sync-sprites.py           copy
    scripts/sync-sprites.py --check   fail if a copy is missing or differs (CI)

To use a new sprite: add its path to MANIFEST, run the script, commit both.
"""
import filecmp
import pathlib
import shutil
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
SOURCE = ROOT / "Assets" / "Sprites"
TARGET = ROOT / "Sources" / "Tippy" / "Resources" / "Sprites"

MANIFEST = [
    # The teal pet's mood poses (256 x 256) and its egg.
    "Pet/thriving.png",
    "Pet/happy.png",
    "Pet/okay.png",
    "Pet/concerned.png",
    "Pet/waiting.png",
    "Pet/egg.png",
    # Four-frame strips (128 x 128 frames); durations live in SpriteLibrary.swift.
    "Animations/pet-idle.png",
    "Animations/pet-hop.png",
    "Animations/egg-wiggle.png",
    # Drink kinds on the log form.
    "Drinks/beer.png",
    "Drinks/wine.png",
    "Drinks/cocktail.png",
    # Rewards: the coin (256 x 256) and its four-frame shimmer.
    "Rewards/coin.png",
    "Animations/coin-shimmer.png",
    # The Wander (spec 03): the other species' mood poses and eggs, their
    # idle, delight and egg-wiggle strips, the hatch, the trail map's
    # banners, stones, find icons and effects, and the nest.
    *[f"Pet/{pet}-{pose}.png" for pet in ("moth", "turtle", "seal", "fox")
      for pose in ("thriving", "happy", "okay", "concerned", "waiting", "egg")],
    *[f"Animations/{pet}-{loop}.png" for pet in ("moth", "turtle", "seal", "fox")
      for loop in ("idle", "delight", "egg-wiggle")],
    "Pet/fox-dusk.png",
    "Animations/hatch.png",
    "Animations/dust-puff.png",
    "Animations/sparkle.png",
    "Animations/find-glow.png",
    *[f"Wander/area-{area}.png" for area in
      ("pond-shore", "reed-bed", "willow-grove", "mossy-woods", "mushroom-glade", "meadow")],
    "Wander/node-found.png",
    "Wander/node-next.png",
    "Wander/node-locked.png",
    *[f"Wander/find-{kind}.png" for kind in ("egg", "gift", "pouch", "visitor", "scenery")],
    "Camp/nest.png",
    # The camp (spec 02): the scene by day and at dusk, every decoration, and
    # the decorations' quiet loops (650, 140, 140, 170 ms).
    "Camp/pond-background.png",
    "Camp/pond-background-dusk.png",
    *[f"Camp/{item}.png" for item in (
        "lantern", "sprout", "seashell", "mushroom", "watering-can", "lily-planter", "flower-pot",
        "stepping-stones", "reed-cluster", "bench", "string-lights", "willow-arch", "firefly-jar")],
    *[f"Animations/{loop}.png" for loop in (
        "lantern-glow", "sprout-sway", "mushroom-bob", "watering-can-tilt", "seashell-glint",
        "string-lights-twinkle", "firefly-jar-glow", "reed-cluster-sway", "lily-planter-bob")],
]


def main() -> int:
    check = "--check" in sys.argv
    problems = []
    for rel in MANIFEST:
        src, dst = SOURCE / rel, TARGET / rel
        if not src.exists():
            problems.append(f"missing source art: Assets/Sprites/{rel}")
            continue
        if dst.exists() and filecmp.cmp(src, dst, shallow=False):
            continue
        if check:
            problems.append(f"out of date: Sources/Tippy/Resources/Sprites/{rel} (run scripts/sync-sprites.py)")
        else:
            dst.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(src, dst)
            print(f"copied {rel}")
    expected = {TARGET / rel for rel in MANIFEST}
    for extra in sorted(p for p in TARGET.rglob("*") if p.is_file() and p not in expected):
        if check:
            problems.append(f"not in the manifest: {extra.relative_to(ROOT)}")
        else:
            extra.unlink()
            print(f"removed {extra.relative_to(TARGET)}")
    for problem in problems:
        print(problem)
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
