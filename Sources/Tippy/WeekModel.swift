import Foundation
import Observation
import TippyModeration

/// This week's numbers for the home screen. A first scaffold: kept in
/// memory only, until persistence (SwiftData) arrives.
@Observable
final class WeekModel {
    var weeklyGoal: Double = 14
    private(set) var drinksThisWeek: Double = 0
    private(set) var checkedInToday = false
    /// Days of the week so far, today included (Monday is day 1).
    private(set) var daysElapsed: Int

    init(seed: UISmokeMode.Seed?, now: Date = Date(), calendar: Calendar = .current) {
        // Calendar weekday: 1 is Sunday ... 7 is Saturday. Monday-start week.
        let weekday = calendar.component(.weekday, from: now)
        daysElapsed = ((weekday + 5) % 7) + 1
        if seed == .midWeek {
            drinksThisWeek = 6
            daysElapsed = 4
            checkedInToday = true
        }
    }

    var mood: PetMood {
        MoodPolicy.mood(
            drinksSoFar: drinksThisWeek,
            weeklyGoal: weeklyGoal,
            daysElapsed: daysElapsed,
            checkedInToday: checkedInToday
        )
    }

    var summary: String {
        String(format: "%.1f of %.0f drinks this week", drinksThisWeek, weeklyGoal)
    }

    func log(_ serving: DrinkServing) {
        drinksThisWeek += serving.standardDrinks
        checkedInToday = true
    }

    func logDrinkFreeDay() {
        checkedInToday = true
    }
}
