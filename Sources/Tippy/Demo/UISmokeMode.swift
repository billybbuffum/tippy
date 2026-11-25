import Foundation
import TippyModeration
import TippyRewards

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
        /// Last week (Nov 9–15) logged on 6 of 7 days, 10 drinks against a goal of 14,
        /// Wednesday drink-free with a reflection. The ledger already holds those days'
        /// check-in and drink-free awards (as if synced live), not the week-goal bonus.
        /// The recap not seen yet; this week empty; the reminder already offered.
        case lastWeekDone = "last-week-done"
        /// The `default` seed plus 120 coins (synthetic awards). Spec 02 uses it.
        case coins
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
        let journalModel = JournalModel(
            store: InMemoryJournalStore(journal(for: seed)),
            reminders: SilentReminderScheduler(),
            calendar: calendar,
            clock: { UISmokeMode.now }
        )
        let rewardsModel = RewardsModel(store: InMemoryRewardsStore(ledger(for: seed)), clock: { UISmokeMode.now })
        journalModel.onJournalChange { rewardsModel.sync(journal: $0, today: $1) }
        return AppModels(journal: journalModel, rewards: rewardsModel)
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
        case .default, .coins:
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
        }
        journal.setWeeklyGoal(14, from: journal.week(containing: today))
        return journal
    }

    /// The rewards ledger a seed starts with; nil (nothing saved) for most.
    static func ledger(for seed: Seed) -> RewardsLedger? {
        switch seed {
        case .default, .onboarding, .midWeek, .oneDrink:
            return nil
        case .coins:
            // Six synthetic pouches of 20: 120 coins with no journal behind them.
            let awards = (1...6).compactMap { number in
                Award(key: .pouch("demo-\(number)"), coins: 20, earnedOn: LocalDate(year: 2026, month: 10, day: number)!)
            }
            return RewardsLedger(awards: awards)
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
}
