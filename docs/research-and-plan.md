# Tippy project plan

**Goal:** Help her drink less by caring for a little pond world. Every honest check-in earns coins for decorating
the camp and steps for her pet's wanders through the pond, reeds and woods, where eggs are waiting to be found,
hatched and raised. The tracking stays quick and kind. The cuteness is the reason to come back.

**First release:** A free, playable loop from the first session:
- log a day (about 30 seconds, skipping the optional prompt), earn coins and wander steps;
- decorate the camp;
- find and hatch a second egg within roughly the first week;
- see a weekly recap (about two minutes).

These are design targets to check on her phone.

Background research on Tipple, reviews and comparable apps is in [`research.md`](./research.md). How the app is
built is in [`architecture.md`](./architecture.md).

## What we keep from Tipple, and what we fix

| Tipple | Tippy |
| --- | --- |
| A user-set weekly budget, daily logging, and a fox that reacts to staying on track | Same shape, with an original teal pond creature. The pet reacts gently and is never sad, sick or guilt-tripping |
| Coins for hitting the target, spent on the fox's campsite | Coins for **every honest check-in**, with bonuses for drink-free days and weeks within the goal. A hard week still earns |
| A prize wheel and camp upgrades | No randomness and nothing paid. Every reward is earned and visible |
| Reviewers finished the camp in about a week and then had nothing to do | Three loops that keep going: decorating, **wandering to find eggs**, and **raising a growing collection of pets**. New areas and items can be added over time |
| The same questions every day | One optional prompt from a rotating set. Answering it adds a wander step, and answers come back in the weekly recap |

## The world

**The camp** is home: the pond, the active pet, and the decorations she has placed. It's the Home screen, and
the camp editor is one tap away.

**The Wander** is a trail that leads out from the pond through a series of areas: Pond Shore → Reed Bed →
Willow Grove → Mossy Woods → Mushroom Glade → Meadow, with more added over time. The active pet walks it one step
at a time:

| Earns a step | How often |
| --- | --- |
| Checking in a day (drinks or drink-free) | Once per date |
| Answering the day's reflection prompt | Once per date |

Landmarks along the trail hold **eggs** (a few per area), **found decorations** (free items for the camp),
small **coin pouches**, and the occasional **visitor**. One is an original cinnamon fox who appears at dusk
after the first weekly recap, as a side story.

**Eggs and pets:**
- The first egg is given at onboarding and hatches after the first check-in into the teal pond creature.
- Later eggs are found on the Wander and hatch after a few more check-ins in the camp's nest, wiggling as they
  get close. The first found egg lands in roughly week one, then about one a week.
- Hatched pets join the collection: the moth, turtle, seal and fox from the sprite pack, then new species as art
  arrives. She chooses which pet is out in the camp. The active pet shows the mood poses; the others idle around the pond.
- Pets grow with friendship hearts earned while they're out (later release).

**Mood** reacts gently to how the week is going: thriving or happy when on pace, "okay" a bit over, a sleepy
"concerned" further over, and "waiting" when today isn't logged after the reminder time. Weekly numbers are
written neutrally, separately from the pet.

**No-guilt rules:**
- Missed days, going over the goal and later edits never take away coins, steps, eggs, pets or decorations.
- Nothing resets.
- Returning after a gap gets a welcome and an offer to log today and yesterday.

## Product flow

| Moment | Experience | Acceptance criteria |
| --- | --- | --- |
| First launch | The pet's egg greets her. Name it, give a typical week, choose a weekly goal, and optionally a cost per drink. The reminder is offered after the first save. | A first check-in is possible without reminder permission or an account. Tippy never sets the goal for her; it pre-fills her typical week and she picks. |
| Camp (Home) | The active pet in the decorated camp, today's check-in action, the week's total against the goal, coins, and the next Wander landmark. | A recorded zero looks different from an unlogged day. |
| Log a day | Today, yesterday or an earlier date. Record zero, or add drinks from presets with a custom amount and ABV. | Entries can be saved, edited and deleted, survive relaunch, and update totals immediately. Removing the last drink asks whether to mark the day drink-free or clear it. A failed save keeps the form. |
| Reflect (optional) | After saving, one short prompt with Skip, such as "Which drink did you most enjoy?" or "What helped tonight?" | Saving never depends on answering. Answering adds a Wander step once per date. |
| Rewards | Coins and a step animate onto the camp after saving. | Each award is earned once per date or week and is never revoked or duplicated by retries or edits. |
| Decorate | Open the shop, buy an item, place it in a compatible spot. Move, swap or store items. | A real choice between affordable starter items in the first session. Moving and storing are free. |
| Wander | Open the trail map: areas, the pet's position, landmarks ahead, and what was found. | Steps come only from the rules above. Landmarks are collected once. |
| Hatch | An egg in the nest counts down in check-ins, then hatches with an animation, and the pet joins the collection. | Hatching survives relaunch. Choosing the active pet is free and instant. |
| Weekly recap | When a week ends: total against that week's goal, drink-free days, coins (including the goal bonus), steps and finds, her reflection answers, and an optional "one thing to try next week". | Shown once for the latest finished week; older recaps live in history. Partial weeks are labelled. A goal change applies from the current week on and never rewrites past weeks. |
| Return after a gap | A welcome, today and yesterday offered, nothing lost. | No queue of missed recaps. Reminders are opt-in with neutral text. |

## Economy (first release)

| Earn | Coins |
| --- | --- |
| Check in a date (any amount) | 5 |
| Drink-free day bonus | +3 |
| Week within its goal (at recap) | +15 |
| Coin pouch on the Wander | 5–10 |

Starter items cost 10–15, so the first check-ins already buy a real choice between three. Most items cost
20–60, and showpieces 80–150. The first catalog has at least 12 items across lighting, plants, furnishings and
pond details, starting from the sprite pack (lantern, mushroom, seashell, sprout, watering can) plus new art.
Week two must still have things to want.

Back-filled dates earn the same as same-day check-ins, for up to 7 days back, so a forgotten day isn't punished
and old history can't be farmed.

## Implementation plan

Detailed, agent-ready specs for steps 2–5 and the art are in [`specs/`](./specs/README.md). Each step is a pull request with its own domain tests, smoke scenarios and seeds, following
[`architecture.md`](./architecture.md).

### 1. Core loop (PR #3, then aligned with this plan)

Already in PR #3:
- the Journal domain (drinks, drink-free days, weeks, mood);
- logging and back-filling;
- history;
- settings;
- reminders;
- JSON backup;
- onboarding.

To align before it merges, so the stored format starts right:
- **Edits:** edit drinks; removing the last drink asks "drink-free or clear?".
- **Drink entries:** store the amount and unit as entered, plus an optional standard-drink override.
- **Weekly goal:** each week keeps the goal it started with; changes apply from the current week on.
- **Reflection:** the optional prompt after saving, with the answer stored per date.
- **Onboarding:** pre-fill the goal with her typical week (no automatic cut), cost optional, reminder offered
  after the first save.
- **The pet:** use the sprite pack's mood poses for the teal pet (pixel-perfect scaling, idle animation) instead
  of the drawn placeholder.
- **Reduce Motion:** still poses.

**Exit check:** zero days, multiple drinks, edits and back-fill survive relaunch. The pet shows the right sprite
for each mood.

### 2. Rewards: coins and the weekly recap (new `TippyRewards` context)

- An award ledger keyed by fact (`checkIn:<date>`, `drinkFree:<date>`, `weekGoal:<week>`, `pouch:<landmark>`), so
  an award is recorded once and never revoked. The balance is earned minus spent.
- The weekly recap screen, shown once per finished week, with the goal bonus awarded there.

**Exit check:** retries, edits and relaunches never duplicate or remove coins. A seeded finished week shows its
recap.

### 3. Camp: shop and decorating

- A bundled catalog with stable item IDs, prices, art and compatible slots. Ownership is kept separate from placement.
- Buying checks the balance and records the purchase in one atomic change. Placement uses tap-to-select spots,
  with move, swap and store.
- Seeds for a fresh camp and a furnished camp.

**Exit check:** log, afford, buy, place, relaunch, still there. Buying twice can't double-charge.

### 4. The Wander and pets (new `TippyWander` context)

- A step ledger keyed by fact (`checkIn:<date>`, `reflection:<date>`). The trail is bundled data (areas,
  landmarks, contents). The pet's position is derived from total steps.
- Eggs: found, nesting with a check-in countdown, hatched. The pet collection and choosing the active pet.
- Trail map screen, hatching animation, and the fox visitor after the first recap.

**Exit check:** the same steps always reach the same landmarks, an egg found in week one hatches on schedule,
and nothing found is lost on relaunch.

### 5. Backup, polish and pilot

- Back up every context (journal, ledgers, purchases, layout, pets) in one versioned file. Restore shows a
  preview of what will change, applies atomically, and warns that exports contain private notes.
- Run a two-week pilot on both phones. Questions: was logging easy, did the pets and decorating make her want to
  come back, and did anything feel like nagging? Feedback is direct; no telemetry.

**Exit check:** install, update over the last build, restore a backup, and complete two weeks.

## Art needed

The sprite pack covers the teal pet's moods, idle and hop animations, the egg wiggle, four alternate pets, a coin,
five camp props and four drinks. Still to make (original art; Reduce Motion gets still frames):
- **Camp:** the pond background, with placement spots marked, plus about 7 more decorations to reach 12.
- **Wander:** a background or tileset for each of the six areas, path markers, landmark icons, and a nest.
- **Pets:** eggs patterned for each species, a hatching animation, and mood poses for the alternate pets (they
  have happy and thriving now; okay, concerned and waiting are still to come).
- **The fox visitor:** a dusk pose and a short dialogue bubble.

## Verification and release gates

| Area | Checks |
| --- | --- |
| Domain | Standard-drink maths; day and week boundaries across DST, year rollover and travel; missing vs zero; back-fill limits; edits; weekly goal kept per week; once-only awards and steps; atomic purchases; insufficient funds; placement conflicts; egg countdowns. |
| UI | Smoke scenarios for: onboarding, a zero day, a drink day, editing, reflection, first purchase and placement, the Wander map, a hatch, and a weekly recap. Seeds for each. |
| Device | Signed install and update keep data; reminder permission and delivery; backup and restore; Dynamic Type, VoiceOver, Reduce Motion; smooth sprite animation. |
| Privacy and safety | Everything stays on the phone, with no account or analytics. Fixtures and GIFs use made-up data. The not-medical-advice note and helpline stay in Settings. No automatic drinking targets or taper schedules. |

## Decisions

Settled:
- **Storage** is one versioned JSON file per context, not SwiftData. It meets every requirement here (atomic,
  versioned, migratable), and the backup format is the stored format.
- **Weeks** run Monday to Sunday by default, with a setting to change it.

To revisit after the pilot:
- the coin amounts and prices;
- how often eggs turn up;
- whether a "no goal yet" mode is wanted;
- whether to show money saved on the camp screen.
