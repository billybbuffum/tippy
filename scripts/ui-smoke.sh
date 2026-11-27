#!/usr/bin/env bash
# Builds Tippy for the iOS Simulator (the xcodegen project in UISmoke/),
# boots a simulator, runs the XCUITest scenarios in UISmoke/Tests once, and
# records a separate video per scenario. Used by
# .github/workflows/ui-smoke.yml, and runnable on any Mac with a modern
# Xcode, xcodegen and ffmpeg (`brew install xcodegen ffmpeg`):
#
#   scripts/ui-smoke.sh [output dir]        default: out/ui-smoke
#
# Environment:
#   UI_SMOKE_UDID     simulator to use (default: the newest plain iPhone)
#   UI_SMOKE_ONLY     scenarios to run, space-separated (default: all);
#                     names as scripts/smoke-scenarios.py list prints them
#   UI_SMOKE_SHARD    k/n: run only shard k of n (scripts/smoke-scenarios.py
#                     shard); CI runs the shards on parallel runners
#   UI_SMOKE_KEEP=1   leave the simulator booted afterwards
#   UI_SMOKE_FFMPEG_PID  a background ffmpeg install to wait for before making GIFs (CI)
#
# Writes to the output dir:
#   results.json             one entry per scenario: status, seed, duration,
#                            failure message, files
#   clips/<scenario>.mp4     the recording, and clips/<scenario>.gif, small
#   shots/<scenario>/NN-*.png one screenshot per screen
#   raw/<scenario>.mov       the recording as the simulator wrote it
#   signals/                 the recording handshake files (see SmokeSupport.swift)
#   device.txt, final.png, the xcodebuild logs and smoke.xcresult
# Exits 0 when every scenario passed, 1 otherwise. A scenario that fails
# never stops the others.
set -uo pipefail

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=${1:-out/ui-smoke}
case "$OUT" in /*) ;; *) OUT="$PWD/$OUT" ;; esac
DERIVED="$ROOT/out/DerivedData"
PROJECT="$ROOT/UISmoke/TippySmoke.xcodeproj"
SCHEME=TippySmoke
TEST_TARGET=TippySmokeUITests

rm -rf "$OUT"
mkdir -p "$OUT/shots" "$OUT/clips" "$OUT/raw" "$OUT/signals"
SIGNALS="$OUT/signals"

log() { printf '\n== %s\n' "$*"; }
fail() { echo "error: $*" >&2; exit 1; }
now() { python3 -c 'import time; print(time.time())'; }

log "Listing the scenarios"
python3 "$ROOT/scripts/smoke-scenarios.py" list --json > "$OUT/scenarios.json" || fail "could not list the scenarios"
if [ -n "${UI_SMOKE_SHARD:-}" ] && [ -z "${UI_SMOKE_ONLY:-}" ]; then
  UI_SMOKE_ONLY=$(python3 "$ROOT/scripts/smoke-scenarios.py" shard "$UI_SMOKE_SHARD" | tr '\n' ' ') || fail "bad UI_SMOKE_SHARD"
  echo "shard $UI_SMOKE_SHARD"
fi
ONLY_ARGS=()
if [ -n "${UI_SMOKE_ONLY:-}" ]; then
  while IFS= read -r line; do
    [ -n "$line" ] && ONLY_ARGS+=("-only-testing:$TEST_TARGET/$line")
  done < <(python3 - "$OUT/scenarios.json" $UI_SMOKE_ONLY <<'PY'
import json, sys
scenarios = {s["name"]: s for s in json.load(open(sys.argv[1]))}
for name in sys.argv[2:]:
    if name not in scenarios:
        sys.exit(f"unknown scenario {name!r}; known: {', '.join(sorted(scenarios))}")
    print(f"{scenarios[name]['class']}/{scenarios[name]['method']}")
PY
) || fail "bad UI_SMOKE_ONLY"
  echo "running only: $UI_SMOKE_ONLY"
else
  python3 -c 'import json,sys; print(", ".join(s["name"] for s in json.load(open(sys.argv[1]))))' "$OUT/scenarios.json"
fi

log "Generating the Xcode project"
xcodegen generate --spec "$ROOT/UISmoke/project.yml" --project "$ROOT/UISmoke" || fail "xcodegen failed"

log "Picking a simulator"
PICK=$(xcrun simctl list -j devices available | python3 -c '
import json, re, sys
best = None
for runtime, devices in json.load(sys.stdin)["devices"].items():
    m = re.search(r"iOS-(\d+)-(\d+)", runtime)
    if not m:
        continue
    version = (int(m.group(1)), int(m.group(2)))
    for d in devices:
        name = d["name"]
        if not d.get("isAvailable", True) or not re.match(r"^iPhone \d+", name):
            continue
        plain = 1 if re.match(r"^iPhone \d+$", name) else 0
        key = (version, plain, name)
        if best is None or key > best[0]:
            best = (key, d["udid"], name, "iOS %d.%d" % version)
if best is None:
    sys.exit("no iPhone simulator is available")
print("\t".join(best[1:]))
') || fail "no simulator"
UDID=${UI_SMOKE_UDID:-$(printf '%s' "$PICK" | cut -f1)}
DEVICE=$(printf '%s' "$PICK" | cut -f2-3 | tr '\t' ' ')
if [ -n "${UI_SMOKE_UDID:-}" ]; then DEVICE="$UI_SMOKE_UDID"; fi
echo "$DEVICE" | tee "$OUT/device.txt"
echo "UDID: $UDID"

log "Booting (in the background while the build runs)"
# A connected hardware keyboard hides the software one, and typing needs it.
defaults write com.apple.iphonesimulator ConnectHardwareKeyboard -bool false
xcrun simctl boot "$UDID" > "$OUT/boot.log" 2>&1 || true

XCODEBUILD=(
  xcodebuild
  -project "$PROJECT"
  -scheme "$SCHEME"
  -derivedDataPath "$DERIVED"
  CODE_SIGNING_ALLOWED=NO
  CODE_SIGNING_REQUIRED=NO
  CODE_SIGN_IDENTITY=
)

log "Building for the simulator"
if ! "${XCODEBUILD[@]}" -destination "generic/platform=iOS Simulator" build-for-testing > "$OUT/xcodebuild-build.log" 2>&1; then
  grep -E "error:|warning: .*(unresolved|not found)|\*\* BUILD" "$OUT/xcodebuild-build.log" | head -40
  tail -40 "$OUT/xcodebuild-build.log"
  fail "build failed (see xcodebuild-build.log)"
fi
APP="$DERIVED/Build/Products/Debug-iphonesimulator/Tippy.app"
[ -d "$APP" ] || fail "built app not found at $APP"
/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" -c "Print :CFBundleExecutable" "$APP/Info.plist"

log "Waiting for the simulator"
xcrun simctl bootstatus "$UDID" -b || fail "simulator did not boot"
xcrun simctl status_bar "$UDID" override --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3 2>/dev/null || true

log "Preparing the test run file"
XCTESTRUN=$(ls -t "$DERIVED"/Build/Products/*.xctestrun 2> /dev/null | head -n 1)
[ -n "$XCTESTRUN" ] || fail "no .xctestrun under $DERIVED/Build/Products"
# The output directories reach the test through the run file's environment;
# TEST_RUNNER_ variables are ignored by test-without-building.
python3 - "$XCTESTRUN" "$OUT/shots" "$SIGNALS" <<'PY'
import plistlib, sys
path, shots, signals = sys.argv[1:4]
with open(path, "rb") as f:
    plist = plistlib.load(f)
def visit(node):
    if isinstance(node, dict):
        if "TestBundlePath" in node:
            env = node.setdefault("EnvironmentVariables", {})
            env["UI_SMOKE_SHOTS_DIR"] = shots
            env["UI_SMOKE_SIGNALS_DIR"] = signals
        for value in node.values():
            visit(value)
    elif isinstance(node, list):
        for value in node:
            visit(value)
visit(plist)
with open(path, "wb") as f:
    plistlib.dump(plist, f)
PY
echo "$XCTESTRUN"

log "Running the scenarios (one recording each)"
rm -rf "$OUT/smoke.xcresult"
xcodebuild test-without-building -xctestrun "$XCTESTRUN" -destination "id=$UDID" \
  -resultBundlePath "$OUT/smoke.xcresult" ${ONLY_ARGS[@]+"${ONLY_ARGS[@]}"} > "$OUT/xcodebuild-test.log" 2>&1 &
TESTER=$!

# The handshake (see SmokeSupport.swift): a scenario writes <name>.start,
# this loop starts the recorder and answers with <name>.recording, the
# scenario writes <name>.done when it ends and the recorder is stopped.
RECORDER=""
RECORDING=""
start_recorder() {
  xcrun simctl io "$UDID" recordVideo --codec h264 --force "$OUT/raw/$1.mov" > "$OUT/record-$1.log" 2>&1 &
  RECORDER=$!
  RECORDING=$1
  # Give the recorder a moment to attach before the app launches.
  sleep 0.8
  now > "$SIGNALS/$1.recording"
  echo "recording $1"
}
stop_recorder() {
  [ -n "$RECORDER" ] || return 0
  # The last frame, then a clean stop so the file is finalized.
  sleep 0.5
  kill -INT "$RECORDER" 2> /dev/null
  wait "$RECORDER" 2> /dev/null
  now > "$SIGNALS/$RECORDING.stopped"
  echo "stopped recording $RECORDING"
  RECORDER=""
  RECORDING=""
}
while true; do
  for start in "$SIGNALS"/*.start; do
    [ -e "$start" ] || continue
    name=$(basename "$start" .start)
    [ -e "$SIGNALS/$name.recording" ] && continue
    stop_recorder
    start_recorder "$name"
  done
  if [ -n "$RECORDING" ] && [ -e "$SIGNALS/$RECORDING.done" ]; then
    stop_recorder
  fi
  kill -0 "$TESTER" 2> /dev/null || break
  sleep 0.25
done
wait "$TESTER"
TEST_STATUS=$?
stop_recorder
xcrun simctl io "$UDID" screenshot "$OUT/final.png" > /dev/null 2>&1 || true

grep -E "Test Case .*(passed|failed)|error:|Executed|failed to launch|crashed" "$OUT/xcodebuild-test.log" | head -60
if [ "$TEST_STATUS" -ne 0 ]; then
  echo "--- xcodebuild test-without-building exited $TEST_STATUS; tail of xcodebuild-test.log"
  tail -40 "$OUT/xcodebuild-test.log"
fi

log "Converting the recordings"
# CI installs ffmpeg in the background while the app builds (ui-smoke.yml);
# wait for that install to finish before looking for it.
if [ -n "${UI_SMOKE_FFMPEG_PID:-}" ]; then
  while kill -0 "$UI_SMOKE_FFMPEG_PID" 2> /dev/null; do sleep 2; done
fi
convert_clip() {
  local mov=$1 name
  name=$(basename "$mov" .mov)
  ffmpeg -loglevel error -y -i "$mov" \
    -vf "scale=540:-2" -c:v libx264 -preset veryfast -crf 28 -pix_fmt yuv420p -movflags +faststart \
    "$OUT/clips/$name.mp4" || echo "warning: mp4 conversion failed for $name"
  ffmpeg -loglevel error -y -i "$mov" \
    -vf "fps=6,scale=300:-1:flags=lanczos,split[a][b];[a]palettegen=max_colors=128:stats_mode=diff[p];[b][p]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" \
    -loop 0 "$OUT/clips/$name.gif" || echo "warning: gif conversion failed for $name"
}
if command -v ffmpeg > /dev/null; then
  # A few at a time; each clip is short and the runner has cores to spare.
  jobs_running=0
  for mov in "$OUT"/raw/*.mov; do
    [ -s "$mov" ] || continue
    convert_clip "$mov" &
    jobs_running=$((jobs_running + 1))
    if [ "$jobs_running" -ge 4 ]; then wait; jobs_running=0; fi
  done
  wait
else
  echo "note: ffmpeg missing; keeping only the raw recordings"
fi

log "Writing results.json"
python3 - "$OUT" "$DEVICE" "$TEST_STATUS" ${UI_SMOKE_ONLY:-} <<'PY'
import json, os, sys
out, device, test_status = sys.argv[1], sys.argv[2], int(sys.argv[3])
only = set(sys.argv[4:])
scenarios = json.load(open(os.path.join(out, "scenarios.json")))
if only:
    scenarios = [s for s in scenarios if s["name"] in only]
signals = os.path.join(out, "signals")
def read(path):
    try:
        with open(path) as f:
            return f.read().strip()
    except OSError:
        return None
results = []
for s in scenarios:
    name = s["name"]
    entry = {"scenario": name, "seed": s["seed"], "file": s["file"], "class": s["class"], "method": s["method"]}
    done = read(os.path.join(signals, name + ".done"))
    started = read(os.path.join(signals, name + ".start"))
    if done:
        try:
            entry.update(json.loads(done))
        except ValueError:
            entry["status"] = "failed"
            entry["failure"] = "unreadable result"
    elif started is not None:
        entry["status"] = "incomplete"
        entry["failure"] = "the scenario started but never reported; the test runner probably died"
    else:
        entry["status"] = "not-run"
    rec_start = read(os.path.join(signals, name + ".recording"))
    rec_stop = read(os.path.join(signals, name + ".stopped"))
    if rec_start and rec_stop:
        entry["clip_seconds"] = round(float(rec_stop) - float(rec_start), 1)
    files = {}
    for kind, path in (("mp4", f"clips/{name}.mp4"), ("gif", f"clips/{name}.gif"), ("mov", f"raw/{name}.mov")):
        full = os.path.join(out, path)
        if os.path.exists(full) and os.path.getsize(full) > 0:
            files[kind] = path
    shots = os.path.join(out, "shots", name)
    if os.path.isdir(shots):
        files["shots"] = f"shots/{name}"
        entry["screenshots"] = len([f for f in os.listdir(shots) if f.endswith(".png")])
    entry["files"] = files
    results.append(entry)
summary = {
    "device": device,
    "xcodebuild_status": test_status,
    "total": len(results),
    "passed": sum(1 for r in results if r["status"] == "passed"),
    "failed": sum(1 for r in results if r["status"] != "passed"),
    "scenarios": results,
}
with open(os.path.join(out, "results.json"), "w") as f:
    json.dump(summary, f, indent=2, sort_keys=True)
width = max(len(r["scenario"]) for r in results) if results else 8
for r in results:
    extra = f"  {r['failure']}" if r.get("failure") else ""
    print(f"{r['scenario']:<{width}}  {r['status']:<10} {r.get('duration', 0):>6}s{extra}")
print(f"{summary['passed']} of {summary['total']} scenarios passed")
sys.exit(0 if summary["failed"] == 0 and results else 1)
PY
STATUS=$?
ls -la "$OUT/clips"

if [ -z "${UI_SMOKE_KEEP:-}" ]; then
  xcrun simctl shutdown "$UDID" > /dev/null 2>&1 || true
fi

if [ "$STATUS" -ne 0 ]; then
  echo "error: not every scenario passed (see results.json)" >&2
fi
exit "$STATUS"
