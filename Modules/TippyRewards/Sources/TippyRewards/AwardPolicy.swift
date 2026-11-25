import Foundation
import TippyModeration

/// Which awards the journal earns. A domain service: pure, so syncing the same
/// journal twice gives the same list, and the ledger ignores keys it already has.
public enum AwardPolicy {
    /// Every award the journal currently qualifies for:
    /// - `checkIn(d)` for each logged day `d` in the back-fill window (`today - 7 ... today`);
    /// - `drinkFree(d)` on top, for each drink-free day in that window;
    /// - `weekGoal(w)` for each of the 4 weeks before the current one that was logged on
    ///   at least 5 days and stayed within the goal that week had.
    public static func eligibleAwards(journal: Journal, today: LocalDate, rules: EarningRules = .standard) -> [Award] {
        var awards: [Award] = []
        let earliest = today.adding(days: -rules.backfillDays)
        for day in journal.loggedDays.sorted() where day >= earliest && day <= today {
            if let award = Award(key: .checkIn(day), coins: rules.checkIn, earnedOn: day) {
                awards.append(award)
            }
            if journal.isDrinkFree(day), let award = Award(key: .drinkFree(day), coins: rules.drinkFreeBonus, earnedOn: day) {
                awards.append(award)
            }
        }
        var week = journal.week(containing: today)
        for _ in 0..<max(rules.goalBonusLookbackWeeks, 0) {
            week = week.previous
            let summary = journal.summary(of: week, today: today)
            guard week.end < today,
                  summary.checkedInDays >= rules.goalBonusMinDaysLogged,
                  summary.metGoal,
                  let award = Award(key: .weekGoal(week), coins: rules.weekGoalBonus, earnedOn: week.end)
            else { continue }
            awards.append(award)
        }
        return awards
    }
}
