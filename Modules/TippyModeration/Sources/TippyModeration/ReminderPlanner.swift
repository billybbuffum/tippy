import Foundation

/// Which days get an evening reminder: every day in the horizon that is not
/// already logged, skipping today once its reminder time has passed.
public enum ReminderPlanner {
    public static func reminderDays(
        today: LocalDate,
        reminderPassedToday: Bool,
        horizon: Int = 28,
        isCheckedIn: (LocalDate) -> Bool
    ) -> [LocalDate] {
        var days: [LocalDate] = []
        for offset in 0..<max(horizon, 0) {
            if offset == 0 && reminderPassedToday { continue }
            let day = today.adding(days: offset)
            if !isCheckedIn(day) { days.append(day) }
        }
        return days
    }
}
