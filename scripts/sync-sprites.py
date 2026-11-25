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
