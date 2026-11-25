#!/usr/bin/env bash
# Re-signs an xtool-built (ad-hoc) IPA with a real development identity.
#
#   scripts/resign.sh <unsigned.ipa> <profiles-dir> "<codesign identity>" <signed.ipa>
#
# <profiles-dir> holds one <bundle id>.mobileprovision per bundle in the app
# (the app itself and every .appex under PlugIns). Each bundle is signed with
# the entitlements it declares, narrowed to what its profile grants, so the
# result exactly matches what the developer portal allows.
set -euo pipefail

IPA="$1"; PROFILES="$2"; IDENTITY="$3"; OUT="$4"

work="$(mktemp -d)"
unzip -q "$IPA" -d "$work"
APP="$(echo "$work"/Payload/*.app)"

sign_bundle() {
  local bundle="$1"
  local id
  id="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$bundle/Info.plist")"
  local profile="$PROFILES/$id.mobileprovision"
  if [ ! -f "$profile" ]; then
    echo "error: no profile for $id at $profile" >&2
    exit 1
  fi
  cp "$profile" "$bundle/embedded.mobileprovision"
  security cms -D -i "$profile" > "$work/profile.plist"
  /usr/libexec/PlistBuddy -x -c 'Print :Entitlements' "$work/profile.plist" > "$work/granted.plist"
  # What xtool baked in from Config/*.entitlements. The profile's grants are
  # a wildcard template; the concrete values must come from here (see
  # merge-entitlements.py for why CloudKit insists on it).
  # A bundle with no entitlements file prints nothing; that is fine.
  codesign -d --entitlements :- "$bundle" > "$work/declared.plist" 2>/dev/null || : > "$work/declared.plist"
  python3 "$(dirname "$0")/merge-entitlements.py" "$work/granted.plist" "$work/declared.plist" "$work/entitlements.plist"
  echo "== signing $id"
  /usr/libexec/PlistBuddy -c 'Print' "$work/entitlements.plist" | sed 's/^/   /'
  codesign --force --sign "$IDENTITY" --entitlements "$work/entitlements.plist" \
    --timestamp=none --generate-entitlement-der "$bundle"
}

# Nested bundles first, then the app that contains them.
for appex in "$APP"/PlugIns/*.appex; do
  [ -d "$appex" ] && sign_bundle "$appex"
done
sign_bundle "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

rm -f "$OUT"
(cd "$work" && zip -qr "$(cd "$(dirname "$OUT")" && pwd)/$(basename "$OUT")" Payload)
echo "Wrote $OUT"
