#!/usr/bin/env bash
# Puts the app icon at Assets/Icon.png, the path xtool.yml names, before a
# build. That file is git-ignored and never committed.
#
# Normally that is a copy of Assets/DefaultIcon.png. To use a private
# picture instead (a photo of your own pet, say) without publishing it in
# this public repo, commit it only encrypted as Assets/Icon.png.gpg (gpg,
# symmetric AES-256) and set the ICON_PASSPHRASE repository secret. With
# both present it is decrypted; a wrong passphrase fails the build.
#
# To make one: a 1024x1024 PNG with no transparency, then
#   gpg --symmetric --cipher-algo AES256 --output Assets/Icon.png.gpg photo.png
# and commit only Assets/Icon.png.gpg.
set -euo pipefail
cd "$(dirname "$0")/.."

OUT=Assets/Icon.png
if [ -n "${ICON_PASSPHRASE:-}" ] && [ -f Assets/Icon.png.gpg ]; then
  printf '%s' "$ICON_PASSPHRASE" \
    | gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 0 \
        --output "$OUT" --decrypt Assets/Icon.png.gpg
  echo "App icon: decrypted Assets/Icon.png.gpg"
else
  cp Assets/DefaultIcon.png "$OUT"
  echo "App icon: Assets/DefaultIcon.png"
fi
# The hash, so a build log shows which icon went in without showing it.
if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$OUT"; else sha256sum "$OUT"; fi
