import Foundation

/// How one week is going (or went).
public struct WeekSummary: Equatable, Sendable {
    public let week: Week
    public let standardDrinks: Double
    public let weeklyGoal: Double
    public let drinkFreeDays: Int
    public let checkedInDays: Int
    /// Days of the week up to and including today: 0 before it starts, 7 once it is over.
    public let daysElapsed: Int

    public var remaining: Double { max(weeklyGoal - standardDrinks, 0) }
    public var isOver: Bool { daysElapsed >= 7 }
    public var metGoal: Bool { standardDrinks <= weeklyGoal + 0.0001 }

    /// 0...1 share of the weekly goal used, for a progress ring.
    public var progress: Double {
        guard weeklyGoal > 0 else { return standardDrinks > 0 ? 1 : 0 }
        return min(standardDrinks / weeklyGoal, 1)
    }

    public var pace: Double {
        MoodPolicy.pace(drinksSoFar: standardDrinks, weeklyGoal: weeklyGoal, daysElapsed: daysElapsed)
    }
}
