import Foundation
import TippyModeration

/// Which week's recap to show. A domain service: pure.
public enum RecapPolicy {
    /// The week to recap now, or nil: only the week just before the current one, if
    /// it had at least one check-in and its recap hasn't been seen. There is no queue
    /// of older weeks, so coming back after three weeks away shows only last week.
    public static func weekToRecap(journal: Journal, ledger: RewardsLedger, today: LocalDate) -> Week? {
        let lastWeek = journal.week(containing: today).previous
        guard !ledger.hasSeenRecap(for: lastWeek),
              journal.summary(of: lastWeek, today: today).checkedInDays > 0
        else { return nil }
        return lastWeek
    }
}
