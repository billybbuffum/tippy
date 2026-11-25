# Tippy project plan

**Goal:** Help someone who wants to keep drinking by choice understand which drinking occasions they enjoy, which feel automatic, and what they want to try next. Tippy is a personal iPhone app with an original pixel-art pond and pet companion.

**First release:** A free, playable camp-decorating loop from the first session. Log a day, earn camp coins, pick an item, and place it in the pond camp. The first week also includes an optional reflection and a fox visitor. The daily check-in should fit in about 30 seconds when the user skips the optional prompt. A typical weekly review should fit in about two minutes. These are design targets to validate on a real device.

## What we learned from Tipple

| Evidence | Implication for Tippy |
| --- | --- |
| Tipple's developer describes a user-set weekly budget, daily logging, and coins for hitting a target that can be spent on the fox's campsite. | Keep the weekly goal and the earn → buy → decorate loop. |
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
| Pond home | See the pet, today's check-in action, the week's recorded total, and the optional goal. Open the camp editor, recent days, or previous reviews. | The UI distinguishes a recorded zero from an unlogged day. A goal of zero is distinct from observation mode. |
| Log a day | Pick today, yesterday, or an earlier date. Record zero or add one or more drinks. Offer common presets and a custom amount and ABV. | Save and edit both kinds of records, reopen them after relaunch, and show the updated total immediately. The form preserves the user's input if saving fails. |
| Reflect optionally | After logging, offer one short prompt and a skip action. For example, “Which drink did you most enjoy?” or “What did you want in that moment?” | Saving a drink log is independent of answering the prompt. Drink-free entries can use prompts such as “What did you notice about the evening?” |
| Review the week | Show recorded totals, explicitly drink-free days, and days with no entry. Resurface the user's own notes. Offer one experiment and the option to keep, change, or remove the next goal. | Partial weeks are marked as partial. The user can save the review and close the app without losing their experiment. |
| Decorate the camp | Open the shop, choose a decoration, then place or move it on the pond scene. | The first session supports a real choice between affordable items. Purchased items can be stored and placed again for free. |
| Return after a gap | Welcome the user back, offer today and yesterday, and keep earlier entries available. | Unlogged days do not reset pond progress or trigger guilt-based copy. Reminders are opt-in and use neutral notification text. |

Example experiment: “At Friday dinner, I’ll order the drink I actually want and decide about a second one after I finish eating.” Keep experiments user-authored or user-selected. The app should record what the user noticed without claiming that sparse data proves a pattern.

## Pond progression and story

The core loop is **check in → earn camp coins → pick a decoration → make the camp your own**. The full loop is free, with no subscription, paid currency, or paywall. The camp is visible on Home and the editor is one tap away.

| Feature | First-release behavior |
| --- | --- |
| Earn | One coin award per recorded date, regardless of drink count or goal. The first award covers a starter item and each subsequent check-in earns toward another choice. Reflection and numeric goals remain optional. |
| Shop | Start with at least eight original items across lighting, plants and furnishings. Offer at least three equally affordable starter items, such as a lantern, a lily planter and a bench. Price the rest across multiple check-ins and verify that a player can add several items in week one with choices still available in week two. |
| Decorate | Preview an item, choose an open compatible spot, and confirm placement. Use tap-to-select placement so drag gestures are optional. Allow moving, swapping compatible items, and storing decorations. Show owned and placed items. |
| Come back | Animate selected scenery with subtle ripples, swaying reeds and twinkles. The first weekly review can introduce an original fox visitor as a side story. Decorating works from day one, including in observation mode. |

Progress is cumulative across weeks. Edits, missed days and going over a goal do not remove coins or decorations. Use original pixel art, layouts and dialogue. Respect Reduce Motion with still poses or brief fades. Add more decorations and visitors after the pilot based on what the user enjoys placing.

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

### 3. Build the shop and camp editor

- Store a coin ledger keyed by recorded date and purchase ID. Apply the first save and earning event in one transaction. Apply the debit and ownership change in one transaction, checking available balance and ownership at commit time. Derive the balance from the ledger.
- Bundle a catalog with stable item IDs, prices, art anchors and compatible slots. Keep ownership separate from placement. Save layout edits atomically, reject incompatible placements, and keep owned items available even when the selected spot is occupied.
- Use deterministic simulator seeds for a fresh camp and a furnished camp. Verify the original sprites, optional animation and icon in the existing xtool build.

**Exit check:** A fresh user can log a day, afford a choice, buy an item, place it, and see it after relaunch. Buying twice cannot duplicate a debit, corrections cannot duplicate earnings, and moving or storing items costs nothing.

### 4. Deliver the weekly review

- Use a stable week identifier for the review, with the user's note, chosen experiment and any next-week goal. Save one review per week and allow editing it.
- Show the most recently completed week on return. Make previous reviews accessible through history. Avoid queues of prompts when a user comes back after a long break.
- Show each day's state in a short summary. Label partial data and resurface notes directly. Preview the week in simulator seeds so the review is testable without waiting seven days.

**Exit check:** A partially logged week can be reviewed, an experiment appears for the intended follow-up week, and the next goal cannot change historical comparisons.

### 5. Pilot and release

- Install on a registered iPhone via the documented signing and Pages workflow. Confirm that upgrading over the prior signed build preserves records.
- Before a multiweek pilot, add versioned JSON export and a validated restore flow. Back up the coin ledger, ownership and layout along with the logs and reviews. Preview what will be restored, handle duplicate IDs explicitly, and apply imports atomically. Explain that exports contain private notes.
- Run a voluntary two-week pilot. Ask whether the daily log was easy, whether the review surfaced something the user wanted to remember, and whether decorating gave the user a reason to return. Use direct feedback and optional notes, with no telemetry or automatic sharing.
- Prioritize changes based on feedback. Consider extra visitors, widgets, Apple Health, syncing, richer trends or revised prompts only after the core loop is useful.

**Exit check:** The pilot user can install, update, restore a backup and complete a first week on the phone. Capture feedback without committing any personal records to GitHub.

## Verification and release gates

| Area | Required checks |
| --- | --- |
| Domain | Standard-drink conversion and rounding; local day/week boundaries across DST, year rollover and travel; observation mode and zero goal; missing vs. zero; backfill and edits; once-only rewards, atomic purchases, insufficient funds and placement conflicts. |
| UI | Existing smoke coverage plus scenarios for first launch, zero and drink entry, editing an earlier day, first purchase, placement and repositioning, a partial weekly review, and the first fox visit. Follow the README's smoke-scenario rule for source changes. |
| Device | Signed install and update, reminder permission and delivery, persistence after termination, backup and restore, Dynamic Type, VoiceOver, Reduce Motion, and acceptable sprite animation performance. |
| Privacy | Keep logs and reflections on-device with no account or analytics in the pilot. Use synthetic values in fixtures, CI GIFs, issues and screenshots. Remain within the existing app's non-clinical scope and do not provide automated drinking targets or taper schedules. |

**Suggested PR order:** Local storage and domain rules → daily logging and onboarding → camp shop and editor → weekly review and fox visit → backup and release polish. Each PR should include its own verification, so art and signed-device setup can proceed while the data model is developed.

**Decisions to revisit after the pilot:** Whether Monday is the best review boundary, whether users want the numeric goal visible on the pond, and which decorations, layouts or visitors would make them more likely to return.
