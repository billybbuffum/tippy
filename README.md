# Tippy

A personal, open-source, non-commercial iPhone app for drinking less, with a virtual pet. You log each
day's drinks (or a drink-free day) against a weekly goal, and the pet's mood follows how the week is going.
It never gets sick or guilt-trips. Inspired by "Tipple: Alcohol Moderation Pet", but with original
name, art and code. See `docs/research-and-plan.md` for the research and roadmap.

*Not medical advice. If you drink heavily every day, talk to a doctor before stopping: alcohol withdrawal can be
dangerous. US helpline: SAMHSA 1-800-662-4357.*

No Mac with Xcode is needed. The build system is the same as ChoreLock's: every merge to `main` is built by
GitHub Actions (with [xtool](https://xtool.sh) on a macOS runner), signed with the developer certificate, and
published to an install page that a registered iPhone installs from in Safari.

## Layout

```
Package.swift                      SwiftPM manifest: one library product per bundle (just the app today)
xtool.yml                          app (+ future extension) bundle wiring
Config/Info.plist                  keys merged on top of xtool's defaults
Assets/DefaultIcon.png             the home-screen icon (original placeholder art)
Modules/TippyModeration/           Moderation context (domain): Foundation-only, Swift 6 mode, unit-tested
Modules/TippyWander/               Wander context (domain): steps, the trail, eggs, hatching, pets; depends on Moderation
Sources/Tippy/App/                 composition root (TippyApp, AppModels) and RootView
Sources/Tippy/Model/               application layer: JournalModel, WanderModel, ports
Sources/Tippy/Adapters/            port implementations (file stores, notifications)
Sources/Tippy/Views/<Feature>/     SwiftUI, one folder per feature
Sources/Tippy/Demo/                UI smoke test demo mode: seeds, fixed clock, stand-in adapters
Sources/Tippy/Resources/Sprites/   the sprites the app ships, copied from Assets/Sprites by scripts/sync-sprites.py
Assets/Sprites/                    source pixel art (see its README)
scripts/resign.sh                  re-signs the CI-built IPA with a real development identity
scripts/merge-entitlements.py      the entitlements each bundle is signed with
scripts/install-page.sh            builds the GitHub Pages install page around that IPA
scripts/app-icon.sh                puts the icon in place before a build (optionally an encrypted private one)
UISmoke/                           xcodegen spec and the XCUITest scenarios of the simulator UI smoke test
scripts/ui-smoke.sh                builds for the simulator, runs the scenarios, one recording each
scripts/smoke-scenarios.py         lists the scenarios; which ones a PR changed; the required-scenario check
scripts/ui-smoke-comment.py        writes the PR comment from results.json
scripts/ui-smoke-publish.sh        keeps the GIFs on the pr-media branch, one directory per PR
scripts/check-architecture.py      enforces the layering rules of docs/architecture.md (CI: architecture.yml)
docs/                              architecture (read first), research and plan, build specs (docs/specs/), server rules
```

## Building and installing

The `Build` workflow (`.github/workflows/build.yml`) builds **every push to every branch**: it tests
`Modules/TippyModeration` and builds an unsigned IPA, so a branch shows whether it compiles before it's merged.
Only `main` (or "Run workflow") goes on to sign and publish. This repo is public, so GitHub-hosted macOS runners
are free. That's why Tippy builds and smoke-tests everything automatically, where ChoreLock (private, billed
minutes) keeps them opt-in.

The `ipa` job tests `Modules/TippyModeration` and `Modules/TippyWander`, then builds an unsigned IPA (artifact `Tippy-unsigned-ipa`). With
the repository secrets below in place, the `sign` job fetches (or creates) a development profile for
`com.billy.tippy`, re-signs the app (`scripts/resign.sh`), and uploads `Tippy-signed-ipa`. Then the `pages` job
publishes the install page. Profiles are regenerated on every run, so a newly registered phone is included in
the next build. `CFBundleVersion` is the run number, so each build installs over the last.

### One-time setup

It reuses the same paid Apple Developer account, certificate and API key as ChoreLock.

1. **Devices.** Each phone's UDID is registered in the portal. If it's already registered for ChoreLock, it's
   already done.
2. **Identifier.** At <https://developer.apple.com/account/resources> > Identifiers, create an explicit iOS
   App ID `com.billy.tippy`. No capabilities are needed yet.
3. **Repository secrets.** In this repo, go to Settings > Secrets and variables > Actions and add the same values ChoreLock uses:

   | Secret | Value |
   |---|---|
   | `APPLE_CERT_P12_BASE64` | the Apple Development certificate `.p12`, base64 |
   | `APPLE_CERT_PASSWORD` | its export password |
   | `ASC_KEY_ID` | App Store Connect API key ID |
   | `ASC_ISSUER_ID` | its issuer ID |
   | `ASC_KEY_P8` | the full `.p8` contents, BEGIN/END lines included |
   | `ICON_PASSPHRASE` | optional; only if you commit an encrypted `Assets/Icon.png.gpg` (see `scripts/app-icon.sh`) |

4. **Pages.** After the first build on `main`, go to Settings > Pages > Build and deployment, set Source to
   **Deploy from a branch**, branch `gh-pages`, folder `/`.

Unlike ChoreLock, which is private and so publishes to a separate public `chorelock-install` repo with a
deploy key, Tippy is public and serves its install page from its own `gh-pages` branch at
`https://billybbuffum.github.io/tippy/`. No deploy key is needed. The IPA there is signed for the registered
phones only and installs nowhere else.

### Installing over the air

Open `https://billybbuffum.github.io/tippy/` in **Safari** on a registered iPhone and tap **Install Tippy**.
The first time, turn on Developer Mode (Settings > Privacy & Security; the phone restarts). Then trust the
developer under Settings > General > VPN & Device Management. If that's already done for ChoreLock, it carries
over. Later builds install over the earlier one.

### Installing the signed IPA by cable

Download `Tippy-signed-ipa` from the run's Artifacts. Then:

```bash
idevicepair pair
ideviceinstaller install Tippy.ipa      # later builds: ideviceinstaller upgrade Tippy.ipa
```

## UI smoke test

This works as in ChoreLock, except that it runs **automatically on every pull request** (each push included)
that touches app code, tests or build config (`Sources/`, `Modules/`, `UISmoke/`, `Config/`, `Package.swift`,
`xtool.yml`, the smoke scripts), not behind a `smoke` label. Docs-only and art-only pull requests skip it, and the
`Build` workflow skips pushes that only change docs, Markdown or `Assets/Sprites/`. Every XCUITest scenario in `UISmoke/Tests/` runs on the simulator with a recording
each, and a sticky PR comment shows "Feature demo" first (the scenarios the PR added or changed, GIFs inline),
then the "Regression suite" table. **Smoke scenario present** (`smoke-scenario-check.yml`) fails a PR that
changes `Sources/` or `Modules/` without adding or changing a scenario or carrying a `Smoke-demo:` line in its
body. GIFs live on the orphan `pr-media` branch and are removed when the PR closes. A PR from a fork runs the
scenarios and uploads the artifacts but gets no comment, because its token is read-only.

Demo mode is the `-ui-smoke` launch argument, honoured only on the simulator (`Sources/Tippy/Demo/UISmokeMode.swift`).
`-ui-smoke-seed <name>` picks the starting state:

| Seed | Starts with |
|---|---|
| `default` | set up already (pet "Sprout", goal 14, Monday weeks), nothing logged |
| `onboarding` | first launch |
| `mid-week` | 3 beers Monday, 3 Tuesday, Wednesday drink-free with a reflection, today not logged, reminder not offered yet |
| `one-drink` | one beer logged today, nothing else |
| `egg-ready` | set up, nothing logged, no Wander saved yet: the starter egg is in the nest |
| `wander-mid` | Nov 11–18 logged with one reflection: 9 steps on the Wander, the pondling out, the moth egg nested one check-in from hatching |

Every seed fixes the clock at Thursday 19 November 2026, 6 PM, keeps the journal and the Wander in memory, and sends no
notifications, so runs are repeatable. Every seed except `onboarding` and `egg-ready` has already hatched the pondling
(named after the journal's pet name) and caught the Wander up with its journal, so it opens with nothing new to celebrate.

On a Mac with a current Xcode, run `brew install xcodegen ffmpeg`, then `scripts/ui-smoke.sh`. This writes `out/ui-smoke/`.
`UI_SMOKE_ONLY="home log-drink"` runs a subset.

## Testing the domain

```bash
swift test --package-path Modules/TippyModeration
swift test --package-path Modules/TippyWander
```

This needs only Foundation, so it runs on any Mac (or Linux) with a Swift toolchain.
