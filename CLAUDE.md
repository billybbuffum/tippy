# Tippy: notes for agents

A personal, open-source, non-commercial iPhone app (SwiftUI) for drinking less, with a virtual pet. It is built as
a SwiftPM package with [xtool](https://xtool.sh) on GitHub Actions, using **the same build system as
ChoreLock** (`billybbuffum/ChoreLock`). See README.md for how the pieces fit,
`docs/research-and-plan.md` for the product plan, **`docs/architecture.md` for the app's architecture (read it
before changing code)**, and `docs/server-architecture.md` for the server rules.

## Rules

- **All server-side code must follow a strict hexagonal (ports and adapters) and DDD structure**, exactly as
  described in `docs/server-architecture.md`: bounded contexts, the domain → application → adapters layering
  with dependencies pointing inward only, a single composition root, no cross-context imports, and the
  ubiquitous-language table kept up to date. Don't take shortcuts (no business logic in routes or repositories,
  no framework imports in the domain), even for small features.
- **The app follows `docs/architecture.md`**: DDD with ports and adapters in Swift. Business rules live in
  Foundation-only context packages under `Modules/` (Swift 6 mode, unit-tested); `Sources/Tippy/Model/` holds
  `@MainActor @Observable` models that are the only place state changes; `Adapters/` implement ports with Apple
  frameworks; `Views/<Feature>/` are SwiftUI with no business logic; `App/TippyApp.swift` is the only composition
  root; `Demo/` is the smoke-test stand-ins. Work in the order of its section 12, and keep its ubiquitous
  language table current. `scripts/check-architecture.py` (CI: `architecture.yml`) must pass.
- No drink entries, notes or pet state may leave the phone except through a feature the user explicitly turns on.
- Don't reuse Tipple's name, art, screenshots or copy; use original or CC0 assets.

## Building and checking

- Real builds happen on CI. `.github/workflows/build.yml` runs on **every push to every branch** (domain tests
  + unsigned device IPA via xtool; only `main` signs and publishes). `.github/workflows/ui-smoke.yml` runs on
  **every pull request that touches app code, tests or build config** (simulator, XCUITest); docs-only and
  art-only changes skip it, and the build skips docs-only pushes. The repo is public, so macOS runners are free. Push your branch
  and read the run's result rather than guessing whether it compiles. Keep the build path in step with
  ChoreLock's; don't restructure it.
- Keep `swift-tools-version: 6.0` and the `Package.swift` product layout (one `.library` per bundle, the app's
  product name matching `product:` in xtool.yml).
- `Modules/TippyModeration` builds and tests anywhere with Swift: `swift test --package-path Modules/TippyModeration`.
- `scripts/check-architecture.py` checks the layering locally in a second; run it before pushing.
- Work on a branch, open a pull request, and watch its checks.

## When you add a feature or fix a bug

Every pull request gets a **UI smoke test** run automatically: the app is built for the simulator, each
scenario in `UISmoke/Tests/` is driven by XCUITest and recorded, and a comment on the PR shows the result.
The reviewer must be able to watch your change, so:

1. **Give new controls accessibility identifiers.** Use kebab-case, on the control itself
   (`.accessibilityIdentifier("log-drink-button")`). Scenarios tap by identifier, never by visible text
   (navigation titles excepted).
2. **Add or update a scenario.** Write one `test…` method on a `SmokeScenario` subclass in `UISmoke/Tests/`. It calls
   `launch(seed:)` once, taps through the one feature, and names each screen with `screen("name", marker)`.
   Keep it under 40 seconds and self-contained. The method name is the scenario's name (`testLogDrink` is `log-drink`).
3. **Seed what it needs.** If no seed gives the starting state you need, add one to `UISmokeMode.Seed` and
   `SmokeScenario.Seed`, and apply it. Everything in demo mode stays behind `UISmokeMode.isActive`, which is
   a constant `false` off the simulator.
4. **Name the demo, or let the diff do it.** If an existing scenario already shows the change, put
   `Smoke-demo: <scenario>, …` on its own line in the PR body. A change with nothing to show on screen gets
   `Smoke-demo: none`. The `Smoke scenario present` check fails a PR that changes `Sources/` or `Modules/` with
   neither a changed scenario nor a `Smoke-demo:` line.
5. **Check the smoke comment before marking the PR ready.** The "Feature demo" section should show your change
   doing what it claims, and the "Regression suite" table should be all green. Fix what is red rather than
   deleting a scenario.

`scripts/smoke-scenarios.py list` prints the scenarios. `scripts/smoke-scenarios.py changed --base origin/main`
prints the ones your branch touched.

## Commits and pull requests

Use an imperative subject and a short body saying why. Don't merge your own PR; mark it ready and report.
