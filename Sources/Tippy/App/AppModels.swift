import Foundation

/// The app's model graph, one model per bounded context, built once by the
/// composition root (`TippyApp.makeModels`, or `UISmokeMode.makeModels`
/// under the smoke test), which also wires them through the journal's change
/// hook. Each model reaches the views through `.environment(...)`.
@MainActor
final class AppModels {
    let journal: JournalModel
    let wander: WanderModel

    init(journal: JournalModel, wander: WanderModel) {
        self.journal = journal
        self.wander = wander
    }
}
