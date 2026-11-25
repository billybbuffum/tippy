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
    private let clock: Now
    let calendar: Calendar

    init(
        store: any JournalStore,
        reminders: any ReminderScheduling,
        calendar: Calendar,
        clock: @escaping Now
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

    // MARK: Change hook

    /// Downstream models (Rewards, Wander) subscribe here in the composition root.
    /// Called after every successful change, on refresh (app to the front), and once
    /// when a subscriber is added, always on the main actor.
    private var changeHandlers: [@MainActor (Journal, LocalDate) -> Void] = []

    func onJournalChange(_ handler: @escaping @MainActor (Journal, LocalDate) -> Void) {
        changeHandlers.append(handler)
        handler(journal, today)
    }

    private func notifyChange() {
        for handler in changeHandlers { handler(journal, today) }
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
    var currentGoal: Double { journal.goal(for: currentWeek) }
    var todaysDrinks: Double { journal.standardDrinks(on: today) }
    var isTodayDrinkFree: Bool { journal.isDrinkFree(today) }
    var isTodayLogged: Bool { journal.isCheckedIn(today) }

    /// After the first check-in, until she answers it once.
    var shouldOfferReminder: Bool { !settings.reminderOffered && !journal.loggedDays.isEmpty }

    /// Today's (or a day's) reflection prompt: it depends on whether the day had drinks.
    func prompt(for day: LocalDate) -> ReflectionPrompt {
        ReflectionPrompts.prompt(for: day, hadDrinks: journal.hasDrinks(on: day))
    }

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
        notifyChange()
    }

    /// Logs a new drink. True when it was saved.
    @discardableResult
    func log(_ draft: DrinkDraft, on day: LocalDate) -> Bool {
        let entry = DrinkEntry(
            day: day, loggedAt: now, kind: draft.kind, amount: draft.amount, unit: draft.unit,
            abvPercent: draft.abvPercent, standardDrinksOverride: draft.standardDrinksOverride
        )
        let today = today
        return mutate { try $0.log(entry, today: today) }
    }

    /// Saves an edited drink (same ID). True when it was saved.
    @discardableResult
    func update(_ entry: DrinkEntry, with draft: DrinkDraft, on day: LocalDate) -> Bool {
        var edited = entry
        edited.day = day
        edited.kind = draft.kind
        edited.amount = draft.amount
        edited.unit = draft.unit
        edited.abvPercent = draft.abvPercent
        edited.standardDrinksOverride = draft.standardDrinksOverride
        let today = today
        return mutate { try $0.update(edited, today: today) }
    }

    func isOnlyEntryOnItsDay(_ entry: DrinkEntry) -> Bool {
        journal.isOnlyEntryOnItsDay(entry.id)
    }

    /// Deletes a drink; `choice` decides the day's fate if it was the last.
    func delete(_ entry: DrinkEntry, ifDayEmpties choice: Journal.EmptyDayChoice) {
        mutate { try $0.removeEntry(id: entry.id, ifDayEmpties: choice) }
    }

    @discardableResult
    func markDrinkFree(_ day: LocalDate) -> Bool {
        let today = today
        return mutate { try $0.markDrinkFree(day, today: today) }
    }

    func clearDay(_ day: LocalDate) {
        mutate { $0.clearDay(day) }
    }

    @discardableResult
    func reflect(on day: LocalDate, answer: String) -> Bool {
        let dayPrompt = prompt(for: day)
        let now = now
        let today = today
        return mutate { try $0.reflect(on: day, prompt: dayPrompt, answer: answer, at: now, today: today) }
    }

    /// Sets the goal from this week on; earlier weeks keep theirs.
    func setWeeklyGoal(_ goal: Double) {
        let week = currentWeek
        mutate { $0.setWeeklyGoal(goal, from: week) }
    }

    func updateSettings(_ change: (inout ModerationSettings) -> Void) {
        mutate { change(&$0.settings) }
    }

    /// The one-time reminder offer, answered.
    func answerReminderOffer(accept: Bool) async {
        if accept { await setRemindersEnabled(true) }
        updateSettings { $0.reminderOffered = true }
    }

    func completeOnboarding(with draft: ModerationSettings, weeklyGoal: Double) {
        var settings = draft
        settings.petName = settings.petName.trimmingCharacters(in: .whitespacesAndNewlines)
        if settings.petName.isEmpty { settings.petName = ModerationSettings.defaultPetName }
        settings.hasOnboarded = true
        let week = currentWeek
        mutate {
            $0.settings = settings
            $0.setWeeklyGoal(weeklyGoal, from: week)
        }
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

    // MARK: Restore

    /// Replaces the journal wholesale (a restore). Saves first and throws if
    /// that fails, so BackupModel can roll every context back together.
    func replace(with journal: Journal) throws {
        try store.save(journal)
        self.journal = journal
        rescheduleReminders()
    }

    // MARK: Plumbing

    /// The single path for every change: apply it to a copy through the
    /// aggregate, commit on success, save, then run follow-up effects.
    /// Returns false (with `message` set) when the change was refused.
    @discardableResult
    private func mutate(_ change: (inout Journal) throws -> Void) -> Bool {
        var copy = journal
        do {
            try change(&copy)
        } catch let problem as Journal.Problem {
            message = problem.message
            return false
        } catch {
            message = error.localizedDescription
            return false
        }
        journal = copy
        do {
            try store.save(copy)
        } catch {
            message = "Couldn't save: \(error.localizedDescription)"
        }
        rescheduleReminders()
        notifyChange()
        return true
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
        case .invalidEntry: return "That amount or strength doesn't look right."
        case .unknownEntry: return "That drink was already removed."
        case .dayNotLogged: return "Log the day first, then add a reflection."
        case .emptyAnswer: return "Write something, or tap Skip."
        }
    }
}

/// A drink as the log form holds it, before it becomes an entry.
struct DrinkDraft: Equatable {
    var kind: DrinkKind
    var amount: Double
    var unit: VolumeUnit
    var abvPercent: Double
    var standardDrinksOverride: Double?

    /// The kind's typical serving, in `unit`, rounded to a friendly step.
    static func typical(_ kind: DrinkKind, in unit: VolumeUnit) -> DrinkDraft {
        let serving = kind.defaultServing
        let raw = serving.volumeMilliliters / unit.milliliters
        let amount = unit == .fluidOunce ? (raw * 2).rounded() / 2 : (raw / 5).rounded() * 5
        return DrinkDraft(kind: kind, amount: amount, unit: unit, abvPercent: serving.abvPercent)
    }

    init(kind: DrinkKind, amount: Double, unit: VolumeUnit, abvPercent: Double, standardDrinksOverride: Double? = nil) {
        self.kind = kind
        self.amount = amount
        self.unit = unit
        self.abvPercent = abvPercent
        self.standardDrinksOverride = standardDrinksOverride
    }

    init(_ entry: DrinkEntry) {
        self.init(kind: entry.kind, amount: entry.amount, unit: entry.unit, abvPercent: entry.abvPercent,
                  standardDrinksOverride: entry.standardDrinksOverride)
    }

    var entryPreview: DrinkEntry? {
        let preview = DrinkEntry(day: LocalDate(year: 2000, month: 1, day: 1)!, loggedAt: Date(timeIntervalSince1970: 0),
                                 kind: kind, amount: amount, unit: unit, abvPercent: abvPercent,
                                 standardDrinksOverride: standardDrinksOverride)
        return preview.isValid ? preview : nil
    }
}
