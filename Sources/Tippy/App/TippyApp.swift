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
        journalModel.onJournalChange { rewardsModel.sync(journal: $0, today: $1) }
        return AppModels(journal: journalModel, rewards: rewardsModel)
    }
}
