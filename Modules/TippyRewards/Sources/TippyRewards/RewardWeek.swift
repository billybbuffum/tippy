import Foundation
import TippyModeration

/// Reward identity survives the Sunday/Monday calendar preference. The middle
/// day of either representation belongs to the same Monday-start week.
/// Existing award keys and recap dates are kept as originally recorded.
enum RewardWeek {
    static func identity(of week: Week) -> LocalDate {
        Week(containing: week.start.adding(days: 3), firstWeekday: 2).start
    }

    static func week(for key: AwardKey) -> Week? {
        let prefix = "weekGoal:"
        guard key.rawValue.hasPrefix(prefix),
              let start = LocalDate(String(key.rawValue.dropFirst(prefix.count))) else { return nil }
        return Week(start: start)
    }

    static func matches(_ first: Week, _ second: Week) -> Bool {
        identity(of: first) == identity(of: second)
    }
}
