import Foundation
import TippyModeration

// Application-layer ports: what the app needs from the platform, stated in
// domain terms. Adapters in Sources/Tippy/Adapters implement them with Apple
// frameworks; Sources/Tippy/Demo has stand-ins for the UI smoke test. The
// journal's own port, `JournalStore`, is a repository and lives with its
// aggregate in TippyModeration.

/// Port for the evening check-in reminder.
protocol ReminderScheduling {
    func requestAuthorization() async -> Bool
    /// Replaces every pending reminder with one per day in `days`.
    func schedule(days: [LocalDate], hour: Int, minute: Int, petName: String, calendar: Calendar)
    func cancelAll()
}

/// The current instant. Injected so the app (and demo mode) control "now".
typealias Now = () -> Date
