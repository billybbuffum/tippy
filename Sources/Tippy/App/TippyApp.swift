import SwiftUI

@main
struct TippyApp: App {
    @State private var models = TippyApp.makeModels()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .environment(models.journal)
        .environment(models.rewards)
        .environment(models.wander)
        .environment(models.backup)
    }

    /// The composition root: real adapters on the phone, demo ones under
    /// the UI smoke test.
    @MainActor
    static func makeModels() -> AppModels {
        if UISmokeMode.isActive { return UISmokeMode.makeModels() }
        let journalModel = JournalModel(
            store: FileJournalStore.standard(),
            reminders: NotificationReminderScheduler(),
            calendar: .autoupdatingCurrent,
            clock: { Date() }
        )
        let rewardsModel = RewardsModel(store: FileRewardsStore.standard(), clock: { Date() })
        let wanderModel = WanderModel(store: FileWanderStore.standard(), starterPetName: journalModel.settings.petName)
        AppCoordinator.wire(journal: journalModel, rewards: rewardsModel, wander: wanderModel)
        return AppModels(journal: journalModel, rewards: rewardsModel, wander: wanderModel)
    }
}
