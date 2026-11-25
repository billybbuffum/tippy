import SwiftUI

@main
struct TippyApp: App {
    @State private var models = TippyApp.makeModels()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .environment(models.journal)
        .environment(models.wander)
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
        let wanderModel = WanderModel(store: FileWanderStore.standard(), starterPetName: journalModel.settings.petName)
        journalModel.onJournalChange { journal, today in _ = wanderModel.sync(journal: journal, today: today) }
        return AppModels(journal: journalModel, wander: wanderModel)
    }
}
