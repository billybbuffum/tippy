import Foundation
import Observation
import TippyModeration
import TippyRewards

/// The Rewards context's model: the coin ledger and weekly recaps, and the one
/// place they change and are saved. It follows the journal through
/// `JournalModel.onJournalChange` (wired in the composition root), recording
/// whatever awards the journal newly earns. Rules live in TippyRewards.
@MainActor
@Observable
final class RewardsModel {
    private(set) var ledger: RewardsLedger
    /// Something to tell the user (an unreadable file, a failed save).
    var message: String?
    /// Coins from syncs that recorded something new, not yet shown. Home shows the
    /// "+N coins" toast, then calls `acknowledgeEarned()`.
    private(set) var lastEarned: Int?
    /// The finished week whose recap is due, refreshed on every sync.
    private(set) var pendingRecap: Week?

    private let store: any RewardsStore
    private let rules: EarningRules
    private let clock: Now

    init(store: any RewardsStore, clock: @escaping Now, rules: EarningRules = .standard) {
        self.store = store
        self.clock = clock
        self.rules = rules
        var loaded = RewardsLedger()
        var problem: String?
        do {
            loaded = try store.load() ?? RewardsLedger()
        } catch {
            problem = "Tippy couldn't read its saved coins, so they started fresh. The unreadable file was kept aside."
        }
        self.ledger = loaded
        self.message = problem
    }

    // MARK: Derived state

    var balance: Int { ledger.balance }

    func coinsEarned(in week: Week) -> Int { ledger.coinsEarned(in: week) }

    /// The goal bonus `week` earned, if it did.
    func goalBonus(for week: Week) -> Award? { ledger.award(for: .weekGoal(week)) }

    func hasSeenRecap(for week: Week) -> Bool { ledger.hasSeenRecap(for: week) }

    /// What she wrote at the end of `week` to try the week after.
    func nextWeekIdea(for week: Week) -> String? { ledger.recap(for: week)?.nextWeekIdea }

    // MARK: Commands

    /// Records every award the journal newly qualifies for and works out the due recap.
    func sync(journal: Journal, today: LocalDate) {
        let new = AwardPolicy.eligibleAwards(journal: journal, today: today, rules: rules)
            .filter { !ledger.hasAward($0.key) }
        if !new.isEmpty, mutate({ ledger in for award in new { ledger.record(award) } }) {
            noteEarned(new.reduce(0) { $0 + $1.coins })
        }
        pendingRecap = RecapPolicy.weekToRecap(journal: journal, ledger: ledger, today: today)
    }

    /// Awards coins for a fact outside the journal (a pouch found on the Wander).
    /// Idempotent by key. True when the award was new.
    @discardableResult
    func award(coins: Int, key: AwardKey, on day: LocalDate) -> Bool {
        guard let award = Award(key: key, coins: coins, earnedOn: day), !ledger.hasAward(key) else { return false }
        guard mutate({ _ = $0.record(award) }) else { return false }
        noteEarned(coins)
        return true
    }

    /// Grants a decoration found on the Wander, once per key. True if it was new.
    @discardableResult
    func grant(itemID: String, key: AwardKey) -> Bool {
        var granted = false
        mutate { granted = $0.grant(itemID, key: key) }
        return granted
    }

    // MARK: Camp

    func owns(_ itemID: String) -> Bool { ledger.owns(itemID) }

    func canAfford(_ item: CatalogItem) -> Bool { ledger.balance >= item.price }

    func item(in slotID: String) -> CatalogItem? { ledger.item(in: slotID).flatMap(CampCatalog.item) }

    /// Owned items not placed anywhere, optionally only those that fit `kind`.
    func storedItems(fitting kind: SlotKind? = nil) -> [CatalogItem] {
        ledger.storedItems().compactMap(CampCatalog.item).filter { kind == nil || $0.kind == kind }
    }

    /// Buys an item. A repeat tap on something already bought is ignored
    /// quietly rather than reported. True when the purchase was recorded.
    @discardableResult
    func buy(_ itemID: String) -> Bool {
        guard !ledger.owns(itemID) else { return false }
        let now = clock()
        return mutate { try $0.buy(itemID, at: now) }
    }

    @discardableResult
    func place(_ itemID: String, in slotID: String) -> Bool {
        mutate { try $0.place(itemID, in: slotID) }
    }

    func store(slotID: String) {
        mutate { $0.store(slotID: slotID) }
    }

    /// The recap was seen; `nextWeekIdea` is her optional idea for the week after.
    func markRecapSeen(_ week: Week, nextWeekIdea: String?) {
        let now = clock()
        mutate { $0.markRecapSeen(week, at: now, nextWeekIdea: nextWeekIdea) }
        if pendingRecap == week { pendingRecap = nil }
    }

    /// The toast for `lastEarned` has been shown.
    func acknowledgeEarned() {
        lastEarned = nil
    }

    // MARK: Plumbing

    private func noteEarned(_ coins: Int) {
        lastEarned = (lastEarned ?? 0) + coins
    }

    /// The single path for every change: apply it to a copy through the aggregate,
    /// commit it, and save only if something changed. Returns false (with `message`
    /// set) when the change was refused.
    @discardableResult
    private func mutate(_ change: (inout RewardsLedger) throws -> Void) -> Bool {
        var copy = ledger
        do {
            try change(&copy)
        } catch let problem as RewardsLedger.Problem {
            message = problem.message
            return false
        } catch {
            message = error.localizedDescription
            return false
        }
        guard copy != ledger else { return true }
        ledger = copy
        do {
            try store.save(copy)
        } catch {
            message = "Couldn't save your coins: \(error.localizedDescription)"
        }
        return true
    }
}

extension RewardsLedger.Problem {
    var message: String {
        switch self {
        case .unknownItem: return "That decoration isn't in the catalog."
        case .notForSale: return "That one can't be bought; it's found on the Wander."
        case .alreadyOwned: return "You already have that one."
        case .insufficientCoins: return "Not enough coins for that yet. Every check-in earns more."
        case .notOwned: return "Buy or find that decoration first."
        case .unknownSlot: return "That spot isn't in the camp."
        case .wrongSlotKind: return "That decoration doesn't fit in that spot."
        }
    }
}
