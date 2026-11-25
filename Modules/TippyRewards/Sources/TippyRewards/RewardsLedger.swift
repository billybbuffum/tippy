import Foundation
import TippyModeration

/// The Rewards aggregate: every award she has earned and every weekly recap she
/// has seen. Its invariants:
/// - an award's coins are greater than 0 (`Award` guarantees it);
/// - keys are unique: recording a key that exists changes nothing;
/// - awards are never removed, so editing or deleting a day later never takes coins back;
/// - one recap per week; seeing it again only updates the next-week idea.
///
/// The balance is derived (earned minus spent), never stored.
/// Spec 02 adds purchases, owned items and placements; decode new fields with
/// `decodeIfPresent` defaults so files written now still load.
public struct RewardsLedger: Hashable, Sendable {
    public static let currentVersion = 1

    public private(set) var awards: [AwardKey: Award]
    /// Keyed by the week's start.
    public private(set) var recaps: [LocalDate: WeeklyRecap]

    public init(awards: [Award] = [], recaps: [WeeklyRecap] = []) {
        // The first award for a key wins: it was recorded first.
        self.awards = Dictionary(awards.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        self.recaps = Dictionary(recaps.map { ($0.weekStart, $0) }, uniquingKeysWith: { first, _ in first })
    }

    // MARK: Coins

    /// Every coin ever awarded.
    public var earned: Int { awards.values.reduce(0) { $0 + $1.coins } }

    /// Coins spent in the shop; nothing can be bought until spec 02.
    public var spent: Int { 0 }

    public var balance: Int { earned - spent }

    /// Records an award unless its key exists. Returns true if it was new.
    @discardableResult
    public mutating func record(_ award: Award) -> Bool {
        guard !hasAward(award.key) else { return false }
        awards[award.key] = award
        return true
    }

    public func hasAward(_ key: AwardKey) -> Bool { award(for: key) != nil }

    public func award(for key: AwardKey) -> Award? {
        if let exact = awards[key] { return exact }
        guard let week = RewardWeek.week(for: key) else { return nil }
        return awards.values.sorted { $0.key < $1.key }.first { award in
            guard let recorded = RewardWeek.week(for: award.key) else { return false }
            return RewardWeek.matches(recorded, week)
        }
    }

    /// Daily awards belong to their logged date; a goal bonus belongs to the
    /// same reward week even after switching the calendar's first weekday.
    public func coinsEarned(in week: Week) -> Int {
        awards.values.filter { award in
            if let recorded = RewardWeek.week(for: award.key) {
                return RewardWeek.matches(recorded, week)
            }
            return week.contains(award.earnedOn)
        }.reduce(0) { $0 + $1.coins }
    }

    // MARK: Recaps

    /// Marks `week`'s recap seen. The first time keeps `at`; seeing it again only
    /// updates the idea.
    public mutating func markRecapSeen(_ week: Week, at instant: Date, nextWeekIdea: String?) {
        if var recap = recap(for: week) {
            recap.nextWeekIdea = WeeklyRecap.cleaned(nextWeekIdea)
            recaps[recap.weekStart] = recap
        } else {
            recaps[week.start] = WeeklyRecap(weekStart: week.start, seenAt: instant, nextWeekIdea: nextWeekIdea)
        }
    }

    public func hasSeenRecap(for week: Week) -> Bool { recap(for: week) != nil }

    public func recap(for week: Week) -> WeeklyRecap? {
        recaps[week.start] ?? recaps.values.sorted { $0.weekStart < $1.weekStart }.first {
            RewardWeek.matches(Week(start: $0.weekStart), week)
        }
    }
}

extension RewardsLedger: Codable {
    enum CodingKeys: String, CodingKey {
        case version, awards, recaps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decodeIfPresent(Int.self, forKey: .version) ?? 1
        guard version <= RewardsLedger.currentVersion else {
            throw DecodingError.dataCorruptedError(
                forKey: .version, in: c,
                debugDescription: "Saved by a newer Tippy (format \(version)); update the app first."
            )
        }
        let awards = try c.decodeIfPresent([Award].self, forKey: .awards) ?? []
        let recaps = try c.decodeIfPresent([WeeklyRecap].self, forKey: .recaps) ?? []
        self.init(awards: awards, recaps: recaps)
    }

    /// Dictionaries are written as arrays sorted by key, so the file is stable.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(RewardsLedger.currentVersion, forKey: .version)
        try c.encode(awards.values.sorted { $0.key < $1.key }, forKey: .awards)
        try c.encode(recaps.values.sorted { $0.weekStart < $1.weekStart }, forKey: .recaps)
    }
}
