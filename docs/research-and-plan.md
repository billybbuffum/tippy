# Tippy: research notes and build plan

Tippy is a personal, open-source, non-commercial alcohol-moderation app with a virtual pet,
inspired by **Tipple: Alcohol Moderation Pet** (iOS, by Myrtle).

> Research caveat: the App Store, the developer's site (moderation.pet) and screensdesign.com
> could not be opened directly from the research environment. Everything below comes from
> search-engine summaries of those pages, plus comparable apps. Items marked *(unconfirmed)*
> should be checked against the real app.

---

## 1. What Tipple is

| | |
|---|---|
| Name | Tipple: Alcohol Moderation Pet (App Store id 6762130998) |
| Developer | Myrtle (also publishes "Tipple - Make the Change", an "accountability pet" app) |
| Platform | iPhone only; Health & Fitness; rated 18+ |
| Released | ~May 15, 2026 |
| Ratings | 4.6★; counts vary by source and date (≈590–800) |
| Business model | Free download, "Pro" subscription (yearly plan, 7-day free trial); one directory says it shows ads |
| Tagline | "Drink less, live more, and find your Tipple balance" |
| Positioning | Track, moderate and reduce drinking. Aimed at moderation, "damp" living or full sobriety; sober-curious users; Dry January / Sober October |
| Tone | Non-judgmental and playful. Its site says it makes "moderation feel like a game, not a chore" |

### Core loop (as far as can be confirmed)

1. **Onboarding chat with a fox mascot** about your current drinking habits.
2. **Set a goal**: a weekly target and a daily drinking limit.
3. **Log drinks daily.** Logging "keeps the fox on track". Missing a day makes the fox
   "let you know, gently" (a reminder, not a punishment).
4. **Weekly progress tracker** with reward animations.
5. **Coins** are earned for hitting the weekly target, plus **free spins** that award objects.
6. **Spend coins upgrading the fox's camp.**
7. **Savings calculator** that shows money saved by drinking less.
8. **Chat feature** for writing out feelings *(reported by reviewers)*.

### What reviewers liked and disliked (use this as a design brief)

- 👍 Less judgmental and more upbeat than other apps; not loaded with "tasks, readings or assignments".
- 👍 The chat helps with processing feelings.
- 👎 **The reward loop runs dry.** The camp is fully upgraded after about a week, after which
  coins pile up with nothing to spend them on and the camp stops changing.
- 👎 It asks the same questions every day and gives no real insight.
- 👎 The features feel thin for the subscription price, and "there are a ton of free drink trackers".

### Comparable apps to borrow ideas from

- **Reboo** (by Reframe): an axolotl hatched from an egg. Coins from each check-in build and
  upgrade its pond. Offers a **6-week plan that steps weekly drinks down**, support for
  alcohol-free breaks, and a chat for planning nights out or handling cravings. It includes a
  clear **"not medical advice / heavy daily drinkers should consult a doctor before stopping"** warning.
- **SoberPal**: a bear companion for cravings, with drink tracking and daily limits.
- **DryDog**: a Tamagotchi-style streak pet that grows (abstinence-focused).
- **Finch**: the best-known self-care pet; a good reference for a gentle, never-punishing pet.
- **DrinkControl / DampDays**: standard-drink units, Apple Health sync, lock-screen widgets.

---

## 2. What you need to decide

### 2a. Platform (the biggest decision)

The right choice depends on what phone your wife uses and how much hassle you'll accept.

| Option | Cost | Pros | Cons |
|---|---|---|---|
| **PWA** (web app added to the home screen) ⭐ recommended to start | Free (GitHub Pages) | One codebase for iPhone and Android, no App Store, works offline, instant updates | On iOS, scheduled *local* notifications aren't possible. Reminders need web push (iOS 16.4+, installed to the home screen, plus a small push server) or simply opening the app. No widgets, no HealthKit |
| **Expo / React Native** | Free on Android. On iPhone: a free Apple ID (re-sign every 7 days) **or** the $99/yr Apple Developer Program for TestFlight | Real local notifications, widgets possible, feels native | Build tooling, Apple signing hassle |
| **Native SwiftUI** | Same Apple costs as above; needs a Mac with Xcode | Best iOS feel, widgets, HealthKit | iOS only, and a Mac is required |

**Recommendation:** build a **PWA with Vite + React + TypeScript**, storing everything on the
device. If daily reminders turn out to matter a lot, wrap the same code later (with Capacitor)
or port it to Expo.

### 2b. Name and art (IP hygiene)

For a private app for your wife, anything goes. Because this repo is **public and open source**, though:
- Don't reuse Tipple's name, fox character art, camp art, screenshots or copy text. "Tippy" is close to
  "Tipple", so consider a distinct name and an original pet (a different animal or a made-up creature) if
  you ever share it more widely.
- Use original art or CC0 assets (e.g. Kenney.nl), or draw simple SVGs. Copying *mechanics*
  (log drinks → pet reacts → earn coins → decorate) is fine.

### 2c. Safety and tone

- Show a short "not medical advice" note. Also warn that heavy daily drinkers shouldn't
  stop suddenly without a doctor, because alcohol withdrawal can be dangerous. Link to a helpline
  (US: SAMHSA 1-800-662-4357).
- The pet should **never die, get sick or guilt-trip**. Its moods should range from "cozy/happy" to "a bit sleepy/concerned", with a gentle nudge.
- Logging an over-limit day should still earn a check-in coin. Honesty is the habit being rewarded.

---

## 3. MVP feature list

**Onboarding (about 5 screens, styled as a chat with the pet)**
1. Hatch or name the pet.
2. "How many drinks in a typical week?" (baseline)
3. Weekly goal in standard drinks (suggest baseline −20–30%), plus optional drink-free-days target.
4. Typical cost per drink (for the savings calculator).
5. Reminder time (if notifications are supported).

**Daily use**
- **Quick log**: preset buttons (beer, glass of wine, cocktail, shot, seltzer) with editable size and ABV,
  and a big **"No drinks today"** button. Drinks can be edited or deleted, and past days can be back-filled.
- **Home screen**: the pet in its home, this week's progress ring (drinks used / budget), drink-free days
  so far, coins, and the check-in streak.
- **Gentle reminder** if today hasn't been logged.

**Progress**
- Weekly bar chart of standard drinks per day; week-over-week trend.
- Money saved vs baseline, approximate calories, drink-free day count.
- Weekly recap card when the week rolls over: goal met? coins awarded; pet celebration animation.

**Rewards (fix Tipple's biggest complaint)**
- Coins: +1 per daily check-in, +bonus for a drink-free day, +big bonus for meeting the weekly goal.
- Shop of decorations, outfits and pet food, with **a long, tiered catalog** and seasonal or rotating items so
  there's always something to save for.
- Pet growth stages unlocked by *weeks on target* (egg → baby → teen → adult), plus milestone badges.
- Optional: a short reflection prompt that varies daily ("What helped today?") instead of the same questions.

**Plans (later)**
- Optional step-down plan, like Reboo's 6 weeks (e.g. reduce the weekly budget by 1–2 drinks per week).
- Optional "break" mode (e.g. a 30-day dry challenge).

**Data and settings**
- Everything stored on the device (IndexedDB). No account, no server, no analytics.
- **Export/import JSON backup** (important: clearing browser data would otherwise wipe history).
- Units: US standard drinks by default; UK units as an option.

---

## 4. Key logic

### Standard drinks

```
grams_alcohol  = volume_ml × (ABV% / 100) × 0.789
us_std_drinks  = grams_alcohol / 14      // US standard drink = 14 g
uk_units       = grams_alcohol / 8       // UK unit = 8 g
```
Presets (US): 12 oz / 355 ml beer @ 5% ≈ 1.0 · 5 oz / 148 ml wine @ 12% ≈ 1.0 ·
1.5 oz / 44 ml spirit @ 40% ≈ 1.0. Note that many craft beers and pours are 1.5–2+ drinks.

### Pet mood (example)

```
weekPace   = drinksThisWeek / (weeklyGoal × daysElapsed / 7)
loggedToday, streak = consecutive days with a check-in

mood =
  !loggedToday && afterReminderTime → "waiting"    (looks at you, speech bubble: "how was today?")
  weekPace <= 0.8                   → "thriving"   (bouncy, sparkles)
  weekPace <= 1.0                   → "happy"
  weekPace <= 1.3                   → "okay"       (calm, encouraging line)
  else                              → "concerned"  (sleepy/cozy, never sad-crying; offers tips)
```

### Data model (sketch)

```ts
Settings   { petName, petSpecies, weeklyGoal, drinkFreeDaysGoal, costPerDrink,
             baselinePerWeek, unitSystem, weekStartsOn, reminderTime }
DrinkEntry { id, date, timestamp, presetId?, name, volumeMl, abv, stdDrinks, cost? }
DayCheckIn { date, drinkFree: boolean, note?, mood? }
Wallet     { coins }  +  CoinEvent { id, date, amount, reason }
Inventory  { itemId, placed: boolean, position? }
WeekSummary{ weekStart, totalStd, goal, metGoal, coinsAwarded }   // derived/cached
```

---

## 5. Suggested tech stack (PWA path)

- **Vite + React + TypeScript**
- **vite-plugin-pwa** (service worker, offline, installable manifest)
- **Dexie.js** (IndexedDB) for local storage
- **Zustand** or React context for UI state
- **Framer Motion** or CSS animations plus SVG/Lottie for the pet
- **A small chart library** (Recharts) or hand-rolled SVG bars
- **Vitest** for the unit/mood/coin logic
- **GitHub Pages** via a GitHub Action for free hosting at `billybbuffum.github.io/tippy`

---

## 6. Build roadmap

1. **Scaffold**: Vite/React/TS, PWA manifest + icons, deploy to GitHub Pages, confirm "Add to Home Screen" works on her phone.
2. **Data layer**: Dexie schema, standard-drink math, week boundaries (with tests).
3. **Logging**: quick-log presets, "no drinks today", edit/delete, back-fill.
4. **Home + pet**: static pet with 4–5 mood poses, weekly progress ring, streak.
5. **Coins + weekly recap**: coin events, week rollover, celebration.
6. **Shop + home decoration**: catalog of items, placing them in the pet's home.
7. **Stats**: weekly chart, savings, drink-free days.
8. **Onboarding chat flow.**
9. **Backup**: export/import JSON.
10. **Reminders**: web push (or a Capacitor/Expo wrapper) if wanted.
11. **Polish**: growth stages, badges, varied reflection prompts, step-down plan, dark mode.

---

## Sources

- App Store listing: https://apps.apple.com/us/app/tipple-alcohol-moderation-pet/id6762130998
- App Store reviews: https://apps.apple.com/us/app/tipple-alcohol-moderation-pet/id6762130998?see-all=reviews
- Developer site: https://www.moderation.pet/
- Screens Design: https://screensdesign.com/discover/apps/tipple-alcohol-moderation-pet/
- AppShunter: https://appshunter.io/ios/app/tipple-alcohol-moderation-pet/id6762130998
- AppBrain: https://www.appbrain.com/appstore/tipple-alcohol-moderation-pet/ios-6762130998
- Tipple - Make the Change: https://apps.apple.com/us/app/tipple-make-the-change/id6795887020
- Reboo (Google Play): https://play.google.com/store/apps/details?id=com.reframe.reboo
- SoberPal: https://apps.apple.com/us/app/id6759593525
- DryDog: https://apps.apple.com/us/app/id6769381741
- DrinkControl: https://apps.apple.com/us/app/id456207840
