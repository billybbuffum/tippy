import Foundation

/// How the pet feels. It never gets sick or dies: the lowest it goes is
/// "concerned", and "waiting" only means today has not been logged yet.
public enum PetMood: String, Sendable, CaseIterable {
    case thriving
    case happy
    case okay
    case concerned
    case waiting
}

/// Derives the pet's mood from the week so far. A domain service: pure,
/// no clock, no storage.
public enum MoodPolicy {
    /// Standard drinks so far divided by the share of the weekly goal that
    /// the days elapsed allow. 1.0 is exactly on budget.
    ///
    /// `daysElapsed` counts today (1 on the first day of the week) and is
    /// clamped to 1...7. A goal of zero makes any drink infinitely over.
    public static func pace(drinksSoFar: Double, weeklyGoal: Double, daysElapsed: Int) -> Double {
        let days = min(max(daysElapsed, 1), 7)
        guard weeklyGoal > 0 else { return drinksSoFar > 0 ? .infinity : 0 }
        let budgetSoFar = weeklyGoal * Double(days) / 7
        return max(drinksSoFar, 0) / budgetSoFar
    }

    public static func mood(
        drinksSoFar: Double,
        weeklyGoal: Double,
        daysElapsed: Int,
        checkedInToday: Bool,
        reminderTimePassed: Bool = false
    ) -> PetMood {
        if !checkedInToday && reminderTimePassed { return .waiting }
        let pace = pace(drinksSoFar: drinksSoFar, weeklyGoal: weeklyGoal, daysElapsed: daysElapsed)
        switch pace {
        case ...0.8: return .thriving
        case ...1.0: return .happy
        case ...1.3: return .okay
        default: return .concerned
        }
    }
}
