import Foundation
import TippyModeration

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
        /// drink-free, today not logged yet.
        case midWeek = "mid-week"
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
    static func makeModel() -> JournalModel {
        JournalModel(
            store: InMemoryJournalStore(journal(for: seed)),
            reminders: SilentReminderScheduler(),
            calendar: calendar,
            clock: { UISmokeMode.now }
        )
    }

    static func journal(for seed: Seed) -> Journal? {
        var settings = ModerationSettings()
        settings.hasOnboarded = true
        let today = LocalDate(now, calendar: calendar)
        switch seed {
        case .onboarding:
            return nil
        case .default:
            return Journal(settings: settings)
        case .midWeek:
            let monday = today.adding(days: -3)
            var entries: [DrinkEntry] = []
            for (dayOffset, count) in [(0, 3), (1, 3)] {
                let day = monday.adding(days: dayOffset)
                for n in 0..<count {
                    let at = day.startDate(in: calendar).addingTimeInterval(19 * 3600 + Double(n) * 1800)
                    entries.append(DrinkEntry(day: day, loggedAt: at, kind: .beer, serving: .beer))
                }
            }
            return Journal(settings: settings, entries: entries, drinkFreeDays: [monday.adding(days: 2)])
        }
    }
}
