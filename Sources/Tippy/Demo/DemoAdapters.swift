import Foundation
import TippyModeration

/// For demo mode: nothing touches the disk.
final class InMemoryJournalStore: JournalStore {
    private var journal: Journal?

    init(_ journal: Journal?) {
        self.journal = journal
    }

    func load() throws -> Journal? { journal }
    func save(_ journal: Journal) throws { self.journal = journal }
}

/// For demo mode: no permission prompts, no notifications.
final class SilentReminderScheduler: ReminderScheduling {
    func requestAuthorization() async -> Bool { true }
    func schedule(days: [LocalDate], hour: Int, minute: Int, petName: String, calendar: Calendar) {}
    func cancelAll() {}
}
