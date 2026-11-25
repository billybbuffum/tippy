#!/usr/bin/env bash
# Builds the over-the-air install page that GitHub Pages serves.
#
#   scripts/install-page.sh <site base url> <signed.ipa> <out-dir>
#
# The page's Install button is an itms-services link to the manifest, which
# points iOS at Tippy.ipa on the same site. Safari on a phone whose UDID
# is in the development profiles installs it from there; no computer.
#
# The manifest is named manifest.xml, not .plist: iOS wants it served as
# XML (Apple's in-house distribution notes list text/xml for the manifest
# and application/octet-stream for the IPA), and GitHub Pages picks the
# content type from the extension, giving .plist application/octet-stream.
set -euo pipefail

BASE="${1%/}"; IPA="$2"; OUT="$3"
VERSION="$(python3 -c 'import plistlib,sys; print(plistlib.load(open(sys.argv[1], "rb"))["CFBundleShortVersionString"])' Config/Info.plist)"
BUILD="${GITHUB_RUN_NUMBER:-0}"
COMMIT="${GITHUB_SHA:-unknown}"
DATE="$(date -u '+%Y-%m-%d %H:%M UTC')"
MANIFEST_URL="$BASE/manifest.xml"
INSTALL_URL="itms-services://?action=download-manifest&amp;url=$MANIFEST_URL"

mkdir -p "$OUT"
cp "$IPA" "$OUT/Tippy.ipa"
touch "$OUT/.nojekyll"

# The manifest's two icon sizes, from the default icon (the page is
# public; see scripts/app-icon.sh). Resized with sips on a Mac,
# ImageMagick on Linux (the workflow installs it). Without either the
# full-size icon is used for both, which iOS tolerates but downloads slowly.
resize() {
  local size="$1" out="$2"
  if command -v sips >/dev/null 2>&1; then
    sips -z "$size" "$size" Assets/DefaultIcon.png --out "$out" >/dev/null
  elif command -v convert >/dev/null 2>&1; then
    convert Assets/DefaultIcon.png -resize "${size}x${size}" "$out"
  else
    echo "warning: no sips or convert; using the full-size icon for $out" >&2
    cp Assets/DefaultIcon.png "$out"
  fi
}
resize 512 "$OUT/icon-512.png"
resize 57 "$OUT/icon-57.png"

cat > "$OUT/manifest.xml" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>items</key>
  <array>
    <dict>
      <key>assets</key>
      <array>
        <dict>
          <key>kind</key>
          <string>software-package</string>
          <key>url</key>
          <string>$BASE/Tippy.ipa</string>
        </dict>
        <dict>
          <key>kind</key>
          <string>display-image</string>
          <key>url</key>
          <string>$BASE/icon-57.png</string>
        </dict>
        <dict>
          <key>kind</key>
          <string>full-size-image</string>
          <key>url</key>
          <string>$BASE/icon-512.png</string>
        </dict>
      </array>
      <key>metadata</key>
      <dict>
        <key>bundle-identifier</key>
        <string>com.billy.tippy</string>
        <key>bundle-version</key>
        <string>$VERSION</string>
        <key>kind</key>
        <string>software</string>
        <key>title</key>
        <string>Tippy</string>
      </dict>
    </dict>
  </array>
</dict>
</plist>
PLIST

cat > "$OUT/index.html" <<HTML
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Install Tippy</title>
<style>
  :root { color-scheme: light dark; }
  body { font-family: -apple-system, system-ui, sans-serif; margin: 0; padding: 32px 20px; max-width: 480px; margin-inline: auto; line-height: 1.5; }
  img { width: 96px; height: 96px; border-radius: 22px; display: block; margin-bottom: 16px; }
  h1 { font-size: 28px; margin: 0 0 4px; }
  .meta { color: #8e8e93; margin: 0 0 24px; font-variant-numeric: tabular-nums; }
  a.install { display: block; text-align: center; background: #0a84ff; color: #fff; text-decoration: none; font-weight: 600; font-size: 18px; padding: 14px; border-radius: 12px; }
  ol { padding-left: 20px; }
  li { margin: 8px 0; }
  .small { font-size: 14px; color: #8e8e93; }
  code { font-size: 0.9em; }
</style>
</head>
<body>
<img src="icon-512.png" alt="">
<h1>Tippy</h1>
<p class="meta">Version $VERSION, build $BUILD<br>$DATE<br><code>${COMMIT:0:10}</code></p>
<a class="install" href="$INSTALL_URL">Install Tippy</a>
<ol>
  <li>Open this page in <b>Safari</b> on the iPhone (other browsers can't install apps).</li>
  <li>Tap <b>Install Tippy</b>, then <b>Install</b> on the prompt. The icon appears on the home screen and fills in as it downloads.</li>
  <li>First time only: turn on <b>Developer Mode</b> under Settings &gt; Privacy &amp; Security (the phone restarts), then trust the developer under Settings &gt; General &gt; VPN &amp; Device Management.</li>
</ol>
<p class="small">Only works on phones registered with the developer account. Later builds install over the earlier one and keep your drink history. Builds come from <a href="https://github.com/${GITHUB_REPOSITORY:-}/actions">GitHub Actions</a>.</p>
</body>
</html>
HTML

ls -la "$OUT"
