import Foundation
import TippyModeration
import TippyBackup
import TippyRewards
import TippyWander

/// Demo mode for the simulator UI smoke scenarios (`.github/workflows/ui-smoke.yml`,
/// `UISmoke/`), as in ChoreLock. Launched with `-ui-smoke` on the simulator,
/// the app runs against an in-memory journal seeded by `-ui-smoke-seed <name>`
/// (or the `UI_SMOKE_SEED` environment variable), a clock fixed at
/// Thursday 19 November 2026, 6 PM, and no notifications, so every run
/// starts from the same state. Without `-ui-smoke` `isActive` is false and
/// nothing here runs; on a device it is compiled to a constant false.
enum UISmokeMode {
    static let launchArgument = "-ui-smoke"
    static let seedArgument = "-ui-smoke-seed"

    #if targetEnvironment(simulator)
    static let isActive = ProcessInfo.processInfo.arguments.contains(launchArgument)
    #else
    static let isActive = false
    #endif

    /// Explicit finite replay coverage; ordinary smoke scenarios still jump to
    /// the end, and looping sprite animations remain disabled.
    static let replaysWander = isActive && ProcessInfo.processInfo.arguments.contains("-ui-smoke-replay-wander")

    /// The named starting states a scenario can ask for. The names match
    /// `SmokeScenario.Seed` in UISmoke/Tests/SmokeSupport.swift.
    enum Seed: String, CaseIterable {
        /// Set up already (pet "Sprout", goal 14, Monday weeks), nothing logged.
        case `default`
        /// First launch: onboarding.
        case onboarding
        /// Thursday of a week with 3 beers Monday, 3 Tuesday, Wednesday
        /// drink-free with a reflection, today not logged yet; the reminder
        /// not offered yet.
        case midWeek = "mid-week"
        /// One beer logged today, nothing else; the reminder already offered.
        case oneDrink = "one-drink"
        /// Last week (Nov 9–15) logged on 6 of 7 days, 10 drinks against a goal of 14,
        /// Wednesday drink-free with a reflection. The ledger already holds those days'
        /// check-in and drink-free awards (as if synced live), not the week-goal bonus.
        /// The recap not seen yet; this week empty; the reminder already offered.
        case lastWeekDone = "last-week-done"
        /// The `default` seed plus 120 coins (synthetic awards). Spec 02 uses it.
        case coins
        /// 60 coins; owns the lantern, sprout, seashell, mushroom and lily planter,
        /// with all but the mushroom placed (spec 02).
        case furnishedCamp = "furnished-camp"
        /// Onboarded, nothing logged, and no Wander saved yet, so the
        /// starter egg is in the nest (every other seed has hatched it).
        case eggReady = "egg-ready"
        /// Nov 11-18 logged with one reflection: 9 steps on the Wander, the
        /// pondling out, the moth egg found and one check-in from hatching.
        case wanderMid = "wander-mid"
        /// `wander-mid`, but the moth has hatched (named Dot) and the nest is empty;
        /// the pondling is still out (spec 03b).
        case twoPets = "two-pets"
        /// `two-pets` one step further: the fox at dusk found on the trail and not met yet.
        case foxVisit = "fox-visit"
        /// `two-pets` with 16 steps and the fox met: the pet waits at the
        /// Heron's Inlet fork (step 11) with 5 steps saved (spec 07), enough
        /// to reach the heron down the side path.
        case atFork = "at-fork"
        /// 15 steps with Heron's Inlet passed: the pet at step 15, the side
        /// path open to explore from the map.
        case forkPassed = "fork-passed"
    }

    /// The seed this launch asked for; `default` when none was named. An
    /// unknown name is logged and treated as `default`.
    static let seed: Seed = {
        let process = ProcessInfo.processInfo
        var name: String?
        if let index = process.arguments.firstIndex(of: seedArgument), index + 1 < process.arguments.endIndex {
            name = process.arguments[index + 1]
        }
        name = name ?? process.environment["UI_SMOKE_SEED"]
        guard let name, !name.isEmpty else { return .default }
        guard let seed = Seed(rawValue: name) else {
            NSLog("Tippy: unknown ui-smoke seed '\(name)'; known: \(Seed.allCases.map(\.rawValue)); using default")
            return .default
        }
        return seed
    }()

    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .current
        return calendar
    }()

    /// Thursday 19 November 2026, 6 PM local time.
    static let now: Date = calendar.date(from: DateComponents(year: 2026, month: 11, day: 19, hour: 18))!

    @MainActor
    static func makeModels() -> AppModels {
        if replaysWander {
            UserDefaults.standard.removeObject(forKey: "wander-last-seen-position")
        }
        let seededJournal = journal(for: seed)
        let journalModel = JournalModel(
            store: InMemoryJournalStore(seededJournal),
            reminders: SilentReminderScheduler(),
            calendar: calendar,
            clock: { UISmokeMode.now }
        )
        let rewardsModel = RewardsModel(store: InMemoryRewardsStore(ledger(for: seed)), clock: { UISmokeMode.now })
        let wanderModel = WanderModel(
            store: InMemoryWanderStore(wander(for: seed, journal: journalModel.journal)),
            starterPetName: journalModel.settings.petName
        )
        AppCoordinator.wire(journal: journalModel, rewards: rewardsModel, wander: wanderModel)
        // Seeds are "as if she'd been using the app": anything the first sync
        // earns from finds already made (a pouch on the trail) isn't news, so no toast.
        rewardsModel.acknowledgeEarned()
        return AppModels(journal: journalModel, rewards: rewardsModel, wander: wanderModel)
    }

    static func journal(for seed: Seed) -> Journal? {
        var settings = ModerationSettings()
        settings.hasOnboarded = true
        let today = LocalDate(now, calendar: calendar)
        func beer(on day: LocalDate, number: Int) -> DrinkEntry {
            let at = day.startDate(in: calendar).addingTimeInterval(19 * 3600 + Double(number) * 1800)
            return DrinkEntry(day: day, loggedAt: at, kind: .beer, amount: 12, unit: .fluidOunce, abvPercent: 5)
        }
        var journal: Journal
        switch seed {
        case .onboarding:
            return nil
        case .default, .coins, .furnishedCamp:
            journal = Journal(settings: settings)
        case .midWeek:
            let monday = today.adding(days: -3)
            let wednesday = monday.adding(days: 2)
            var entries: [DrinkEntry] = []
            for dayOffset in 0..<2 {
                for number in 0..<3 { entries.append(beer(on: monday.adding(days: dayOffset), number: number)) }
            }
            let reflection = Reflection(
                day: wednesday,
                promptID: ReflectionPrompts.prompt(for: wednesday, hadDrinks: false).id,
                answer: "A long walk by the river.",
                answeredAt: wednesday.startDate(in: calendar).addingTimeInterval(21 * 3600)
            )
            journal = Journal(settings: settings, entries: entries, drinkFreeDays: [wednesday], reflections: [reflection])
        case .oneDrink:
            settings.reminderOffered = true
            journal = Journal(settings: settings, entries: [beer(on: today, number: 0)])
        case .lastWeekDone:
            settings.reminderOffered = true
            let lastWeek = Week(containing: today, firstWeekday: settings.firstWeekday).previous
            let wednesday = lastWeek.start.adding(days: 2)
            // Two beers each Monday, Tuesday, Thursday, Friday and Saturday; Sunday not logged.
            let entries = [0, 1, 3, 4, 5].flatMap { offset in
                (0..<2).map { beer(on: lastWeek.start.adding(days: offset), number: $0) }
            }
            let reflection = Reflection(
                day: wednesday,
                promptID: ReflectionPrompts.prompt(for: wednesday, hadDrinks: false).id,
                answer: "Cooked dinner with friends instead.",
                answeredAt: wednesday.startDate(in: calendar).addingTimeInterval(21 * 3600)
            )
            journal = Journal(settings: settings, entries: entries, drinkFreeDays: [wednesday], reflections: [reflection])
            journal.setWeeklyGoal(14, from: lastWeek)
        case .eggReady:
            journal = Journal(settings: settings)
        case .wanderMid, .twoPets, .foxVisit, .atFork, .forkPassed:
            // Nov 11-18: drink-free days, two beers on alternate days, and
            // one reflection on Sunday the 15th.
            settings.reminderOffered = true
            let first = today.adding(days: -8)
            var entries: [DrinkEntry] = []
            var free: Set<LocalDate> = []
            for offset in 0..<8 {
                let day = first.adding(days: offset)
                if offset % 2 == 0 {
                    free.insert(day)
                } else {
                    entries.append(beer(on: day, number: 0))
                    entries.append(beer(on: day, number: 1))
                }
            }
            let sunday = first.adding(days: 4)
            let reflection = Reflection(
                day: sunday,
                promptID: ReflectionPrompts.prompt(for: sunday, hadDrinks: false).id,
                answer: "Made soup and called my sister.",
                answeredAt: sunday.startDate(in: calendar).addingTimeInterval(21 * 3600)
            )
            journal = Journal(settings: settings, entries: entries, drinkFreeDays: free, reflections: [reflection])
        }
        journal.setWeeklyGoal(14, from: journal.week(containing: today))
        return journal
    }

    /// A synthetic backup for the restore scenarios (the system file picker can't
    /// be driven from XCUITest): the `two-pets` journal and Wander with Dot out in
    /// the camp, and the `furnished-camp` coins and decorations.
    static func demoBackup() -> Data? {
        guard let journal = journal(for: .twoPets) else { return nil }
        var wander = wander(for: .twoPets, journal: journal)
        _ = try? wander?.setActive(petID: "reeds-egg-moth")
        // Two-pets' coins and seen recap, with the furnished camp's purchases and
        // placements on top, so nothing is due when the restored app opens.
        let base = ledger(for: .twoPets) ?? RewardsLedger()
        let camp = ledger(for: .furnishedCamp) ?? RewardsLedger()
        let rewards = RewardsLedger(
            awards: Array(base.awards.values) + Array(camp.awards.values),
            recaps: Array(base.recaps.values),
            purchases: camp.purchases,
            placements: camp.placements
        )
        let bundle = BackupBundle(journal: journal, rewards: rewards, wander: wander)
        return try? BackupFormat.encode(bundle, exportedAt: now, appVersion: "0.2.0", build: "demo")
    }

    /// The rewards ledger a seed starts with; nil (nothing saved) for most.
    static func ledger(for seed: Seed) -> RewardsLedger? {
        switch seed {
        case .default, .onboarding, .midWeek, .oneDrink, .eggReady:
            return nil
        case .wanderMid, .twoPets, .foxVisit, .atFork, .forkPassed:
            // This is an established journal, so last week's recap was seen.
            guard let seeded = journal(for: seed) else { return nil }
            let today = LocalDate(now, calendar: calendar)
            var ledger = RewardsLedger(awards: AwardPolicy.eligibleAwards(journal: seeded, today: today))
            ledger.markRecapSeen(seeded.week(containing: today).previous, at: now, nextWeekIdea: nil)
            return ledger
        case .coins:
            // Six synthetic pouches of 20: 120 coins with no journal behind them.
            let awards = (1...6).compactMap { number in
                Award(key: .pouch("demo-\(number)"), coins: 20, earnedOn: LocalDate(year: 2026, month: 10, day: number)!)
            }
            return RewardsLedger(awards: awards)
        case .furnishedCamp:
            // Seven synthetic pouches of 22 (154 coins), 94 spent on five items.
            let awards = (1...7).compactMap { number in
                Award(key: .pouch("demo-\(number)"), coins: 22, earnedOn: LocalDate(year: 2026, month: 10, day: number)!)
            }
            let bought = ["lantern", "sprout", "seashell", "mushroom", "lily-planter"].compactMap(CampCatalog.item)
            let purchases = bought.map { Purchase(itemID: $0.id, price: $0.price, at: now.addingTimeInterval(-86_400)) }
            return RewardsLedger(
                awards: awards,
                purchases: purchases,
                placements: ["light-1": "lantern", "ground-1": "sprout", "ground-4": "seashell", "water-1": "lily-planter"]
            )
        case .lastWeekDone:
            // As if the app had synced on each day of last week as she logged it:
            // every check-in and drink-free award, but not the week's goal bonus,
            // which only becomes due once the week is over.
            guard let seeded = journal(for: seed) else { return nil }
            let lastWeek = seeded.week(containing: LocalDate(now, calendar: calendar)).previous
            var ledger = RewardsLedger()
            for day in lastWeek.days {
                for award in AwardPolicy.eligibleAwards(journal: seeded, today: day) { ledger.record(award) }
            }
            return ledger
        }
    }

    /// The Wander each seed starts with. Nil (nothing saved) gives the
    /// starter egg. The other seeds have already hatched the pondling and
    /// caught up with their journal, as if she'd been using the Wander, so
    /// their scenarios open on Home with nothing new to celebrate.
    static func wander(for seed: Seed, journal: Journal) -> WanderState? {
        let today = LocalDate(now, calendar: calendar)
        switch seed {
        case .onboarding, .eggReady:
            return nil
        case .default, .midWeek, .oneDrink, .lastWeekDone, .coins, .furnishedCamp:
            let pondling = Pet(
                id: WanderState.starterEggID,
                speciesID: Species.pondling.id,
                name: journal.settings.petName,
                hatchedOn: today.adding(days: -8)
            )
            var state = WanderState(pets: [pondling], activePetID: pondling.id)
            _ = state.sync(journal: journal, today: today)
            return state
        case .wanderMid, .twoPets, .foxVisit, .atFork, .forkPassed:
            // Built directly, as the journal seeds are: 9 steps (8 check-ins
            // and the reflection), the shore and the moth egg found, and the
            // moth egg nested at check-in 6, so one more check-in hatches
            // it. (Synced day by day it would have been nested at check-in
            // 7: 9 steps can't leave an egg found at step 8 one check-in
            // from a 3-check-in hatch. The seed favours the scenario.)
            let first = today.adding(days: -8)
            var steps: [StepAward] = []
            for offset in 0..<8 {
                let day = first.adding(days: offset)
                steps.append(StepAward(key: StepKey(.checkIn, day), awardedOn: day))
            }
            let sunday = first.adding(days: 4)
            steps.append(StepAward(key: StepKey(.reflection, sunday), awardedOn: sunday))
            let found: [String: LocalDate] = [
                "shore-shell": first.adding(days: 1),
                "shore-pouch": first.adding(days: 3),
                "shore-bench": sunday,
                "reeds-egg-moth": first.adding(days: 6),
            ]
            let moth = Egg(id: "reeds-egg-moth", speciesID: Species.moth.id, nestedAtCheckIn: 6)
            let pondling = Pet(
                id: WanderState.starterEggID,
                speciesID: Species.pondling.id,
                name: journal.settings.petName,
                hatchedOn: first
            )
            switch seed {
            case .atFork, .forkPassed:
                // Dot hatched and the fox met, then more reflections than the
                // journal shows (steps are never taken back), to reach the fork.
                let dot = Pet(id: moth.id, speciesID: Species.moth.id, name: "Dot", hatchedOn: today.adding(days: -1))
                var foundHere = found
                foundHere["reeds-fox"] = today.adding(days: -1)
                let extra = seed == .atFork ? [0, 1, 2, 3, 5, 6, 7] : [0, 1, 2, 3, 5, 6]
                for offset in extra {
                    let day = first.adding(days: offset)
                    steps.append(StepAward(key: StepKey(.reflection, day), awardedOn: day))
                }
                var route: [RouteChoice] = []
                if seed == .forkPassed {
                    foundHere["reeds-pouch"] = today.adding(days: -1)
                    route = [.pass(forkID: "reeds-inlet")]
                }
                return WanderState(
                    steps: steps, found: foundHere, eggs: [], pets: [pondling, dot], activePetID: pondling.id,
                    seenVisitors: ["fox-at-dusk"], route: route
                )
            case .twoPets, .foxVisit:
                // The moth hatched yesterday and was named Dot.
                let dot = Pet(id: moth.id, speciesID: Species.moth.id, name: "Dot", hatchedOn: today.adding(days: -1))
                var foundHere = found
                if seed == .foxVisit {
                    // One more step (today's walk) reached the fox.
                    steps.append(StepAward(key: StepKey(.checkIn, today), awardedOn: today))
                    foundHere["reeds-fox"] = today
                }
                return WanderState(steps: steps, found: foundHere, eggs: [], pets: [pondling, dot], activePetID: pondling.id)
            default:
                return WanderState(steps: steps, found: found, eggs: [moth], pets: [pondling], activePetID: pondling.id)
            }
        }
    }
}
