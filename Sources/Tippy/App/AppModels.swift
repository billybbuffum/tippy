import Foundation

/// The app's models, one per bounded context, built once by the composition root
/// (`TippyApp.makeModels`, or `UISmokeMode.makeModels` under the UI smoke test) and
/// injected into the views one by one with `.environment(...)`. It only holds them:
/// the wiring between them happens where they are built.
@MainActor
final class AppModels {
    let journal: JournalModel
    let rewards: RewardsModel

    init(journal: JournalModel, rewards: RewardsModel) {
        self.journal = journal
        self.rewards = rewards
    }
}
