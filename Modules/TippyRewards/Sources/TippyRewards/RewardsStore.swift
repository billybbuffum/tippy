import Foundation

/// Port (repository): where the rewards ledger is kept. The app supplies the adapter
/// (`rewards.json` in Application Support on the phone, memory in UI tests).
public protocol RewardsStore {
    /// Nil when nothing has been saved yet.
    func load() throws -> RewardsLedger?
    func save(_ ledger: RewardsLedger) throws
}
