# Tipple research

Background for [the plan](./research-and-plan.md): what Tipple: Alcohol Moderation Pet does, what its users
like and dislike, and which other apps are worth borrowing from.

> Research caveat: most of this comes from search-engine summaries of the App Store listing, the developer's site
> (moderation.pet) and a captured screen walkthrough, plus comparable apps. Nobody on the project has played the
> current version through. Treat details as indicative and check them against the real app.

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

### Screen walkthrough

A captured screen sequence shows, in order:
- a baseline questionnaire;
- drink logging;
- an optional chat and daily intentions;
- weekly progress;
- a prize wheel;
- camp upgrades.

The public evidence supports cosmetic progression and repairing a campsite. It doesn't establish an ongoing plot,
branching quests, or how much content the latest build has.

## 2. Standard drinks

### Standard drinks

```
grams_alcohol  = volume_ml × (ABV% / 100) × 0.789
us_std_drinks  = grams_alcohol / 14      // US standard drink = 14 g
uk_units       = grams_alcohol / 8       // UK unit = 8 g
```
Presets (US): 12 oz / 355 ml beer @ 5% ≈ 1.0 · 5 oz / 148 ml wine @ 12% ≈ 1.0 ·
1.5 oz / 44 ml spirit @ 40% ≈ 1.0. Note that many craft beers and pours are 1.5–2+ drinks.

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
- Screen walkthrough: https://screensdesign.com/apps/tipple-alcohol-moderation-pet/
