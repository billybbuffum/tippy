import Foundation
import Observation
import TippyBackup
import TippyModeration
import TippyRewards
import TippyWander

/// Backups across every context (spec 04): export one file, preview a restore,
/// and apply it all or nothing. The format lives in TippyBackup; this only
/// orchestrates the three models.
@MainActor
@Observable
final class BackupModel {
    /// Something to tell the user (an unreadable file, a failed restore).
    var message: String?
    /// When the last restore finished, for Settings' "Restored" line.
    private(set) var restoredAt: Date?

    private let journal: JournalModel
    private let rewards: RewardsModel
    private let wander: WanderModel

    init(journal: JournalModel, rewards: RewardsModel, wander: WanderModel) {
        self.journal = journal
        self.rewards = rewards
        self.wander = wander
    }

    var current: BackupBundle {
        BackupBundle(journal: journal.journal, rewards: rewards.ledger, wander: wander.state)
    }

    // MARK: Export

    /// Writes everything to a temporary file for the share sheet.
    func export() throws -> URL {
        let info = Bundle.main.infoDictionary
        let data = try BackupFormat.encode(
            current,
            exportedAt: journal.now,
            appVersion: info?["CFBundleShortVersionString"] as? String ?? "?",
            build: info?["CFBundleVersion"] as? String ?? "?"
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Tippy backup \(journal.today).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: Restore

    /// A restore waiting for her to confirm, with what it would change.
    struct PendingRestore: Identifiable {
        let id = UUID()
        let bundle: BackupBundle
        let preview: RestorePreview
    }

    /// Reads a backup and works out the preview. Nothing changes yet.
    func prepareRestore(from data: Data) -> PendingRestore? {
        do {
            let bundle = try BackupFormat.decode(data)
            return PendingRestore(bundle: bundle, preview: RestorePreview(current: current, backup: bundle))
        } catch BackupFormat.Problem.newerVersion {
            message = "That backup is from a newer Tippy. Update the app, then try again."
        } catch {
            message = "That file isn't a Tippy backup Tippy can read."
        }
        return nil
    }

    /// Replaces everything on this phone with the backup, all or nothing. A part
    /// the backup lacks (an old journal-only backup) starts fresh and is rebuilt
    /// from the restored journal by the sync that follows.
    func apply(_ pending: PendingRestore) {
        let before = current
        let incoming = pending.bundle
        do {
            try journal.replace(with: incoming.journal)
            try rewards.replace(with: incoming.rewards ?? RewardsLedger())
            try wander.replace(with: incoming.wander ?? WanderState.starting(petName: incoming.journal.settings.petName))
        } catch {
            // Put every part back as it was; the original files were intact
            // until their own save, so these saves restore what was there.
            try? journal.replace(with: before.journal)
            try? rewards.replace(with: before.rewards ?? RewardsLedger())
            try? wander.replace(with: before.wander ?? WanderState.starting(petName: before.journal.settings.petName))
            message = "Couldn't restore the backup, so nothing was changed. (\(error.localizedDescription))"
            return
        }
        // Catch Rewards and the Wander up with the restored journal.
        journal.refresh()
        rewards.acknowledgeEarned()
        restoredAt = journal.now
    }
}
