import Foundation
import TippyModeration

/// The Rewards aggregate: every award she has earned and every weekly recap she
/// has seen. Its invariants:
/// - an award's coins are greater than 0 (`Award` guarantees it);
/// - keys are unique: recording a key that exists changes nothing;
/// - awards are never removed, so editing or deleting a day later never takes coins back;
/// - one recap per week; seeing it again only updates the next-week idea.
///
/// The camp (spec 02) adds:
/// - one of each decoration: buying an owned item is refused;
/// - a purchase is recorded only if the balance covers it, so it never goes negative;
/// - grants (decorations found on the Wander) are once per key and cost nothing;
/// - a placement puts an owned item in a spot of its kind; an item is in at most
///   one spot, and placing into an occupied spot puts the previous item away.
///
/// The balance (earned minus spent) and what she owns (bought plus granted) are
/// derived, never stored.
public struct RewardsLedger: Hashable, Sendable {
    public static let currentVersion = 1

    public enum Problem: Error, Equatable, Sendable {
        case unknownItem
        case notForSale
        case alreadyOwned
        case insufficientCoins
        case notOwned
        case unknownSlot
        case wrongSlotKind
    }

    public private(set) var awards: [AwardKey: Award]
    /// Keyed by the week's start.
    public private(set) var recaps: [LocalDate: WeeklyRecap]
    /// Every shop purchase, oldest first.
    public private(set) var purchases: [Purchase]
    /// Decorations found on the Wander: `find:<landmark>` to item ID.
    public private(set) var grants: [AwardKey: String]
    /// Slot ID to the item placed there.
    public private(set) var placements: [String: String]

    public init(
        awards: [Award] = [],
        recaps: [WeeklyRecap] = [],
        purchases: [Purchase] = [],
        grants: [AwardKey: String] = [:],
        placements: [String: String] = [:]
    ) {
        // The first award for a key wins: it was recorded first.
        self.awards = Dictionary(awards.map { ($0.key, $0) }, uniquingKeysWith: { first, _ in first })
        self.recaps = Dictionary(recaps.map { ($0.weekStart, $0) }, uniquingKeysWith: { first, _ in first })
        // Purchases are history: kept even if their item left the catalog.
        self.purchases = purchases
        self.grants = grants.filter { CampCatalog.item($0.value) != nil }
        self.placements = [:]
        // Repair placements: known spot and item, owned, the right kind, one spot per item.
        for slotID in placements.keys.sorted() {
            guard let itemID = placements[slotID],
                  let slot = CampCatalog.slot(slotID),
                  let item = CampCatalog.item(itemID),
                  item.kind == slot.kind,
                  owned.contains(itemID),
                  !self.placements.values.contains(itemID) else { continue }
            self.placements[slotID] = itemID
        }
    }

    // MARK: Coins

    /// Every coin ever awarded.
    public var earned: Int { awards.values.reduce(0) { $0 + $1.coins } }

    /// Coins spent in the shop.
    public var spent: Int { purchases.reduce(0) { $0 + $1.price } }

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

    // MARK: Camp

    /// Decorations she has: bought or found.
    public var owned: Set<String> { Set(purchases.map(\.itemID)).union(grants.values) }

    public func owns(_ itemID: String) -> Bool { owned.contains(itemID) }

    /// Buys a shop item. Refused if unknown, not sold, already owned, or more than the balance.
    public mutating func buy(_ itemID: String, at instant: Date) throws {
        guard let item = CampCatalog.item(itemID) else { throw Problem.unknownItem }
        guard item.inShop else { throw Problem.notForSale }
        guard !owns(itemID) else { throw Problem.alreadyOwned }
        guard balance >= item.price else { throw Problem.insufficientCoins }
        purchases.append(Purchase(itemID: itemID, price: item.price, at: instant))
    }

    /// Grants a found decoration, once per key. True if the grant was new.
    @discardableResult
    public mutating func grant(_ itemID: String, key: AwardKey) -> Bool {
        guard grants[key] == nil, CampCatalog.item(itemID) != nil else { return false }
        grants[key] = itemID
        return true
    }

    /// Places an owned item in a spot of its kind. If it's already placed
    /// elsewhere it moves; if the spot is taken, the item there is put away.
    public mutating func place(_ itemID: String, in slotID: String) throws {
        guard let slot = CampCatalog.slot(slotID) else { throw Problem.unknownSlot }
        guard let item = CampCatalog.item(itemID) else { throw Problem.unknownItem }
        guard owns(itemID) else { throw Problem.notOwned }
        guard item.kind == slot.kind else { throw Problem.wrongSlotKind }
        for (otherSlot, placed) in placements where placed == itemID { placements[otherSlot] = nil }
        placements[slotID] = itemID
    }

    /// Empties a spot; its item stays owned, in storage.
    public mutating func store(slotID: String) {
        placements[slotID] = nil
    }

    public func item(in slotID: String) -> String? { placements[slotID] }

    /// Owned items not placed anywhere, in catalog order.
    public func storedItems() -> [String] {
        let placed = Set(placements.values)
        return CampCatalog.items.map(\.id).filter { owns($0) && !placed.contains($0) }
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
        case version, awards, recaps, purchases, grants, placements
    }

    private struct GrantRecord: Codable {
        let key: AwardKey
        let itemID: String
    }

    private struct PlacementRecord: Codable {
        let slotID: String
        let itemID: String
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
        // Fields added by spec 02 default to empty, so files from before it still load.
        let purchases = try c.decodeIfPresent([Purchase].self, forKey: .purchases) ?? []
        let grants = try c.decodeIfPresent([GrantRecord].self, forKey: .grants) ?? []
        let placements = try c.decodeIfPresent([PlacementRecord].self, forKey: .placements) ?? []
        self.init(
            awards: awards,
            recaps: recaps,
            purchases: purchases,
            grants: Dictionary(grants.map { ($0.key, $0.itemID) }, uniquingKeysWith: { first, _ in first }),
            placements: Dictionary(placements.map { ($0.slotID, $0.itemID) }, uniquingKeysWith: { first, _ in first })
        )
    }

    /// Dictionaries are written as arrays sorted by key, so the file is stable.
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(RewardsLedger.currentVersion, forKey: .version)
        try c.encode(awards.values.sorted { $0.key < $1.key }, forKey: .awards)
        try c.encode(recaps.values.sorted { $0.weekStart < $1.weekStart }, forKey: .recaps)
        try c.encode(purchases, forKey: .purchases)
        try c.encode(grants.map { GrantRecord(key: $0.key, itemID: $0.value) }.sorted { $0.key < $1.key }, forKey: .grants)
        try c.encode(placements.map { PlacementRecord(slotID: $0.key, itemID: $0.value) }.sorted { $0.slotID < $1.slotID }, forKey: .placements)
    }
}
