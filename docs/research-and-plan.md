# Tippy project plan

**Goal:** Help someone who wants to keep drinking by choice understand which drinking occasions they enjoy, which feel automatic, and what they want to try next. Tippy is a personal iPhone app with an original pixel-art pond and pet companion.

**First release:** A complete first week, from choosing an intention or observing a baseline to reviewing the week and meeting the pond's fox visitor. The daily check-in should fit in about 30 seconds when the user skips the optional prompt. A typical weekly review should fit in about two minutes. These are design targets to validate on a real device.

## What we learned from Tipple

| Evidence | Implication for Tippy |
| --- | --- |
| Tipple's developer describes a user-set weekly budget, daily logging, and coins for hitting a target that can be spent on the fox's campsite. | Keep a simple weekly goal and a world that visibly changes. |
| A captured screen sequence shows a baseline questionnaire, drink logging, optional chat and daily intentions, weekly progress, a prize wheel, and camp upgrades. | Keep the daily actions short and offer reflection after saving. |
| Some App Store reviewers liked the playful tone. Others reported repetitive questions and finishing the camp within roughly a week. | Give each prompt a purpose and let the app remain useful after the last unlock. |

The public evidence supports cosmetic progression and a campsite repair setup. It does not establish an ongoing plot, branching quests, or how much content the latest build contains. This review used the [developer site](https://www.moderation.pet/), [App Store listing](https://apps.apple.com/us/app/tipple-alcohol-moderation-pet/id6762130998), [screen walkthrough](https://screensdesign.com/apps/tipple-alcohol-moderation-pet/), and [App Store reviews](https://apps.apple.com/us/app/tipple-alcohol-moderation-pet/id6762130998?see-all=reviews). The current app was not independently played through.

## Repository baseline

- [Package.swift](../Package.swift) targets iOS 17+ with SwiftUI and depends on the Foundation-only [TippyModeration package](../Modules/TippyModeration).
- [ContentView.swift](../Sources/Tippy/ContentView.swift) shows a placeholder pet, weekly summary, a button that logs a beer, and a drink-free action. [TippyApp.swift](../Sources/Tippy/TippyApp.swift) supplies the existing week model. Audit the model and any persisted data before replacing its storage or wiring.
- The [README](../README.md) documents xtool builds, the macOS CI workflow, simulator GIF smoke tests, signing, and over-the-air installation for registered iPhones. Use that pipeline for the pilot. Confirm device registration, signing and a real install early.
- Inventory the merged art and open asset work before integrating it. The existing placeholder should provide a fallback until production assets are ready.

## Product flow

| Moment | User experience | Acceptance criteria |
| --- | --- | --- |
| First launch | Meet and optionally name the pond pet. Choose what to explore, then set an optional weekly drink goal or start in observation mode. Offer a reminder after the first save. | The user can complete a first check-in without a drink goal, reminder permission, or account. |
| Pond home | See the pet, today's check-in action, the week's recorded total, and the optional goal. Open recent days or previous reviews. | The UI distinguishes a recorded zero from an unlogged day. A goal of zero is distinct from observation mode. |
| Log a day | Pick today, yesterday, or an earlier date. Record zero or add one or more drinks. Offer common presets and a custom amount and ABV. | Save and edit both kinds of records, reopen them after relaunch, and show the updated total immediately. The form preserves the user's input if saving fails. |
| Reflect optionally | After logging, offer one short prompt and a skip action. For example, “Which drink did you most enjoy?” or “What did you want in that moment?” | Saving a drink log is independent of answering the prompt. Drink-free entries can use prompts such as “What did you notice about the evening?” |
| Review the week | Show recorded totals, explicitly drink-free days, and days with no entry. Resurface the user's own notes. Offer one experiment and the option to keep, change, or remove the next goal. | Partial weeks are marked as partial. The user can save the review and close the app without losing their experiment. |
| Return after a gap | Welcome the user back, offer today and yesterday, and keep earlier entries available. | Unlogged days do not reset pond progress or trigger guilt-based copy. Reminders are opt-in and use neutral notification text. |

Example experiment: “At Friday dinner, I’ll order the drink I actually want and decide about a second one after I finish eating.” Keep experiments user-authored or user-selected. The app should record what the user noticed without claiming that sparse data proves a pattern.

## Pond progression and story

The pond gradually becomes a gathering place. Tippy finds a dim lantern on the first check-in. After three unique checked-in dates, the lantern lights and the reeds start to move. After the first completed weekly review, an original fox visitor appears at dusk for a brief conversation. The review milestone works in observation mode and with incomplete weeks. Animations can be replayed from the pond once unlocked.

Progress is cumulative across weeks. A recorded day can count once, regardless of drink count. Edits do not replay rewards or revoke earned scenes. The companion stays friendly in every state, and weekly totals use neutral copy separate from the pet's mood. Use idle animations, swaying reeds, ripples and occasional twinkles to bring the scene to life. Support Reduce Motion with still poses and brief fades.

Ship the starter pet and first fox visit in the pilot. Additional original pets, seasonal pond changes, outfits and longer story arcs are later content. Keep paid features, randomized rewards, an economy, and mandatory streaks outside the first release. The weekly reflection remains available after the first story arc ends.

## Implementation plan

### 1. Store reliable check-ins

- Introduce a versioned local store, with SwiftData as the proposed persistence layer. Keep date, drink conversion and weekly aggregation logic in `TippyModeration`. Keep view state and persistence adapters under `Sources/Tippy`.
- Model a day with a stable local calendar date, an explicit record state (zero drinks or one or more drinks), optional reflection, and timestamps. Absence of a day record represents missing data. Each drink has a stable ID and stores the input amount, volume unit, ABV and any explicit standard-drink override. Reuse the current domain conversion and aggregate before display rounding.
- Define the pilot's weeks as Monday–Sunday in the user's calendar time zone. Keep recorded date keys stable while traveling. Snapshot weekly goals so changes apply going forward. Totals may update after backfill; past targets and earned milestones remain stable. Derive weekly totals from records instead of persisting a second count.
- Save edits atomically. Adding a drink to a zero day changes its record state. Removing the last drink requires an explicit choice to mark the day drink-free or clear the entry. Ensure repeat taps, retries and relaunches cannot create duplicate check-ins or milestones. Preserve existing records during migration if the baseline has durable user data.

**Exit check:** Zero, multiple drinks, corrections and backfill survive a relaunch. The UI handles a missing record, partial week, goal of zero and observation mode distinctly.

### 2. Close the daily loop

- Replace the placeholder one-tap beer action with presets and custom entry. Add a history view for date selection and editing.
- Add brief first-launch setup and a settings path for editing the current intention and next week's goal. Present the optional reflection after save and draw prompts from a small, locally bundled set.
- Add local reminders only after opt-in. Reconcile scheduling when the app becomes active and when preferences, calendar conditions or the current day's entry change. Check how permission denial and already-delivered reminders behave.

**Exit check:** A fresh user can record a day using VoiceOver, skip reflection, edit the entry from history, and understand their weekly total. The pilot timing target is met for a routine check-in.

### 3. Deliver the weekly review

- Use a stable week identifier for the review, with the user's note, chosen experiment and any next-week goal. Save one review per week and allow editing it.
- Show the most recently completed week on return. Make previous reviews accessible through history. Avoid queues of prompts when a user comes back after a long break.
- Show each day's state in a short summary. Label partial data and resurface notes directly. Preview the week in simulator seeds so the review is testable without waiting seven days.

**Exit check:** A partially logged week can be reviewed, an experiment appears for the intended follow-up week, and the next goal cannot change historical comparisons.

### 4. Integrate pond art and milestones

- Confirm frame dimensions, timing, anchors and sprite IDs with the asset contributors. Use original art, original dialogue and Tippy's own layout.
- Drive the pond from explicit milestone IDs and record the award once, together with the relevant check-in or review. Keep the milestone condition independent of drinks logged or goals reached.
- Add the lantern, reeds and fox visit, then verify asset bundling and the app icon through the existing xtool packaging flow.

**Exit check:** The same milestones appear after equivalent check-ins regardless of drink totals. Earlier scenes and art remain available after relaunch, and the pond is usable with Reduce Motion enabled.

### 5. Pilot and release

- Install on a registered iPhone via the documented signing and Pages workflow. Confirm that upgrading over the prior signed build preserves records.
- Before a multiweek pilot, add versioned JSON export and a validated restore flow. Preview what will be restored, handle duplicate IDs explicitly, and apply imports atomically. Explain that exports contain private notes.
- Run a voluntary two-week pilot. Ask whether the daily log was easy, whether the review surfaced something the user wanted to remember, and whether the pond felt encouraging. Use direct feedback and optional notes, with no telemetry or automatic sharing.
- Prioritize changes based on feedback. Consider extra visitors, widgets, Apple Health, syncing, richer trends or revised prompts only after the core loop is useful.

**Exit check:** The pilot user can install, update, restore a backup and complete a first week on the phone. Capture feedback without committing any personal records to GitHub.

## Verification and release gates

| Area | Required checks |
| --- | --- |
| Domain | Standard-drink conversion and rounding; local day/week boundaries across DST, year rollover and travel; observation mode and zero goal; missing vs. zero; backfill and edits; once-only milestone awards. |
| UI | Existing smoke coverage plus scenarios for first launch, zero and drink entry, editing an earlier day, a partial weekly review, and the first fox visit. Follow the README's smoke-scenario rule for source changes. |
| Device | Signed install and update, reminder permission and delivery, persistence after termination, backup and restore, Dynamic Type, VoiceOver, Reduce Motion, and acceptable sprite animation performance. |
| Privacy | Keep logs and reflections on-device with no account or analytics in the pilot. Use synthetic values in fixtures, CI GIFs, issues and screenshots. Remain within the existing app's non-clinical scope and do not provide automated drinking targets or taper schedules. |

**Suggested PR order:** Local storage and domain rules → daily logging and onboarding → weekly review → art and milestone wiring → backup and release polish. Each PR should include its own verification, so art and signed-device setup can proceed while the data model is developed.

**Decisions to revisit after the pilot:** Whether Monday is the best review boundary, whether users want the numeric goal visible on the pond, and whether additional visitors or better reflection prompts would make them more likely to return.
