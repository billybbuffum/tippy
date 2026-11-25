import Foundation
import TippyModeration
import TippyWander

/// For demo mode: nothing touches the disk.
final class InMemoryJournalStore: JournalStore {
    private var journal: Journal?

    init(_ journal: Journal?) {
        self.journal = journal
    }

    func load() throws -> Journal? { journal }
    func save(_ journal: Journal) throws { self.journal = journal }
}

/// For demo mode: the Wander kept in memory. Nil means no saved Wander, so
/// the app starts one with the starter egg.
final class InMemoryWanderStore: WanderStore {
    private var state: WanderState?

    init(_ state: WanderState?) {
        self.state = state
    }

    func load() throws -> WanderState? { state }
    func save(_ state: WanderState) throws { self.state = state }
}

/// For demo mode: no permission prompts, no notifications.
final class SilentReminderScheduler: ReminderScheduling {
    func requestAuthorization() async -> Bool { true }
    func schedule(days: [LocalDate], hour: Int, minute: Int, petName: String, calendar: Calendar) {}
    func cancelAll() {}
}
