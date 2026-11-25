import Foundation

/// How many coins each fact earns, and the windows that keep old history from
/// being farmed. `standard` is what the app uses; tests can vary it.
public struct EarningRules: Hashable, Sendable {
    /// Per logged day, with drinks or drink-free.
    public var checkIn: Int
    /// On top of the check-in, for a drink-free day.
    public var drinkFreeBonus: Int
    /// For a finished week within that week's goal.
    public var weekGoalBonus: Int
    /// The back-fill window: a day earns only if `day >= today - backfillDays`.
    public var backfillDays: Int
    /// A week must have been honestly logged to earn its bonus.
    public var goalBonusMinDaysLogged: Int
    /// Only the weeks just before the current one, this many of them, can earn a bonus.
    public var goalBonusLookbackWeeks: Int

    public init(
        checkIn: Int = 5,
        drinkFreeBonus: Int = 3,
        weekGoalBonus: Int = 15,
        backfillDays: Int = 7,
        goalBonusMinDaysLogged: Int = 5,
        goalBonusLookbackWeeks: Int = 4
    ) {
        self.checkIn = checkIn
        self.drinkFreeBonus = drinkFreeBonus
        self.weekGoalBonus = weekGoalBonus
        self.backfillDays = backfillDays
        self.goalBonusMinDaysLogged = goalBonusMinDaysLogged
        self.goalBonusLookbackWeeks = goalBonusLookbackWeeks
    }

    public static let standard = EarningRules()
}
