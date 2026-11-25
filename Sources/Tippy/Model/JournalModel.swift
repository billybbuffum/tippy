import Foundation
import Observation
import TippyModeration

/// The app's single source of truth: the journal plus the clock, and the
/// one place changes are made, saved and reminders rescheduled. Domain
/// rules live in TippyModeration; this only orchestrates.
@MainActor
@Observable
final class JournalModel {
    private(set) var journal: Journal
    /// Something to tell the user (a refused change, a failed save).
    var message: String?
    /// Bumped when the app comes to the front, so "today" is re-read.
    private var tick = 0

    private let store: any JournalStore
    private let reminders: any ReminderScheduling
    private let clock: () -> Date
    let calendar: Calendar

    init(
        store: any JournalStore,
        reminders: any ReminderScheduling,
        calendar: Calendar = .current,
        clock: @escaping () -> Date = { Date() }
    ) {
        self.store = store
        self.reminders = reminders
        self.calendar = calendar
        self.clock = clock
        var loaded = Journal()
        var problem: String?
        do {
            loaded = try store.load() ?? Journal()
        } catch {
            problem = "Tippy couldn't read its saved data, so it started fresh. The unreadable file was kept aside."
        }
        self.journal = loaded
        self.message = problem
    }

    // MARK: Time

    var now: Date {
        _ = tick
        return clock()
    }

    var today: LocalDate { LocalDate(now, calendar: calendar) }

    func day(of date: Date) -> LocalDate { LocalDate(date, calendar: calendar) }

    func date(of day: LocalDate) -> Date { day.startDate(in: calendar) }

    // MARK: Derived state

    var settings: ModerationSettings { journal.settings }
    var currentWeek: Week { journal.week(containing: today) }
    var summary: WeekSummary { journal.summary(of: currentWeek, today: today) }
    var streak: Int { journal.streak(today: today) }
    var todaysDrinks: Double { journal.standardDrinks(on: today) }
    var isTodayDrinkFree: Bool { journal.isDrinkFree(today) }
    var isTodayLogged: Bool { journal.isCheckedIn(today) }

    var reminderTimeToday: Date {
        calendar.date(bySettingHour: settings.reminderHour, minute: settings.reminderMinute, second: 0, of: now) ?? now
    }

    var mood: PetMood {
        let week = summary
        return MoodPolicy.mood(
            drinksSoFar: week.standardDrinks,
            weeklyGoal: week.weeklyGoal,
            daysElapsed: week.daysElapsed,
            checkedInToday: isTodayLogged,
            reminderTimePassed: settings.reminderEnabled && now >= reminderTimeToday
        )
    }

    func title(for day: LocalDate) -> String {
        if day == today { return "Today" }
        if day == today.adding(days: -1) { return "Yesterday" }
        return date(of: day).formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }

    // MARK: Commands

    func refresh() {
        tick += 1
        rescheduleReminders()
    }

    func log(kind: DrinkKind, serving: DrinkServing, on day: LocalDate) {
        let entry = DrinkEntry(day: day, loggedAt: now, kind: kind, serving: serving)
        let today = today
        mutate { try $0.log(entry, today: today) }
    }

    func delete(_ entry: DrinkEntry) {
        mutate { $0.removeEntry(id: entry.id) }
    }

    func markDrinkFree(_ day: LocalDate) {
        let today = today
        mutate { try $0.markDrinkFree(day, today: today) }
    }

    func clearDrinkFree(_ day: LocalDate) {
        mutate { $0.clearDrinkFree(day) }
    }

    func updateSettings(_ change: (inout ModerationSettings) -> Void) {
        mutate { change(&$0.settings) }
    }

    func completeOnboarding(with draft: ModerationSettings) async {
        var settings = draft
        settings.petName = settings.petName.trimmingCharacters(in: .whitespacesAndNewlines)
        if settings.petName.isEmpty { settings.petName = ModerationSettings.defaultPetName }
        if settings.reminderEnabled {
            settings.reminderEnabled = await reminders.requestAuthorization()
        }
        settings.hasOnboarded = true
        updateSettings { $0 = settings }
    }

    func setRemindersEnabled(_ enabled: Bool) async {
        guard enabled else {
            updateSettings { $0.reminderEnabled = false }
            return
        }
        let granted = await reminders.requestAuthorization()
        if !granted {
            message = "Notifications are turned off for Tippy. You can allow them in the Settings app under Notifications."
        }
        updateSettings { $0.reminderEnabled = granted }
    }

    // MARK: Backup

    /// Writes the journal to a temporary file for the share sheet.
    func exportBackup() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tippy backup \(today).json")
        try JournalCodec.encode(journal).write(to: url, options: .atomic)
        return url
    }

    func importBackup(_ data: Data) {
        do {
            let imported = try JournalCodec.decode(data)
            mutate { $0 = imported }
            message = "Backup restored."
        } catch {
            message = "That file isn't a Tippy backup Tippy can read."
        }
    }

    // MARK: Plumbing

    private func mutate(_ change: (inout Journal) throws -> Void) {
        var copy = journal
        do {
            try change(&copy)
        } catch let problem as Journal.Problem {
            message = problem.message
            return
        } catch {
            message = error.localizedDescription
            return
        }
        journal = copy
        do {
            try store.save(copy)
        } catch {
            message = "Couldn't save: \(error.localizedDescription)"
        }
        rescheduleReminders()
    }

    private func rescheduleReminders() {
        guard settings.reminderEnabled else {
            reminders.cancelAll()
            return
        }
        let journal = journal
        let days = ReminderPlanner.reminderDays(
            today: today,
            reminderPassedToday: now >= reminderTimeToday
        ) { journal.isCheckedIn($0) }
        reminders.schedule(
            days: days,
            hour: settings.reminderHour,
            minute: settings.reminderMinute,
            petName: settings.petName,
            calendar: calendar
        )
    }
}

extension Journal.Problem {
    var message: String {
        switch self {
        case .futureDay: return "That day hasn't happened yet."
        case .dayHasDrinks: return "That day already has drinks logged. Delete them in History first."
        }
    }
}
