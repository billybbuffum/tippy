import Foundation
import TippyModeration
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
        /// Onboarded, nothing logged, and no Wander saved yet, so the
        /// starter egg is in the nest (every other seed has hatched it).
        case eggReady = "egg-ready"
        /// Nov 11-18 logged with one reflection: 9 steps on the Wander, the
        /// pondling out, the moth egg found and one check-in from hatching.
        case wanderMid = "wander-mid"
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
        let seededJournal = journal(for: seed)
        let journalModel = JournalModel(
            store: InMemoryJournalStore(seededJournal),
            reminders: SilentReminderScheduler(),
            calendar: calendar,
            clock: { UISmokeMode.now }
        )
        let wanderModel = WanderModel(
            store: InMemoryWanderStore(wander(for: seed, journal: journalModel.journal)),
            starterPetName: journalModel.settings.petName
        )
        journalModel.onJournalChange { journal, today in _ = wanderModel.sync(journal: journal, today: today) }
        return AppModels(journal: journalModel, wander: wanderModel)
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
        case .default:
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
        case .eggReady:
            journal = Journal(settings: settings)
        case .wanderMid:
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

    /// The Wander each seed starts with. Nil (nothing saved) gives the
    /// starter egg. The other seeds have already hatched the pondling and
    /// caught up with their journal, as if she'd been using the Wander, so
    /// their scenarios open on Home with nothing new to celebrate.
    static func wander(for seed: Seed, journal: Journal) -> WanderState? {
        let today = LocalDate(now, calendar: calendar)
        switch seed {
        case .onboarding, .eggReady:
            return nil
        case .default, .midWeek, .oneDrink:
            let pondling = Pet(
                id: WanderState.starterEggID,
                speciesID: Species.pondling.id,
                name: journal.settings.petName,
                hatchedOn: today.adding(days: -8)
            )
            var state = WanderState(pets: [pondling], activePetID: pondling.id)
            _ = state.sync(journal: journal, today: today)
            return state
        case .wanderMid:
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
            return WanderState(steps: steps, found: found, eggs: [moth], pets: [pondling], activePetID: pondling.id)
        }
    }
}
