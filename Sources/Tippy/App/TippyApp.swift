import SwiftUI

@main
struct TippyApp: App {
    @State private var model = TippyApp.makeModel()

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .environment(model)
    }

    /// The composition root: real adapters on the phone, demo ones under
    /// the UI smoke test.
    @MainActor
    static func makeModel() -> JournalModel {
        if UISmokeMode.isActive { return UISmokeMode.makeModel() }
        return JournalModel(
            store: FileJournalStore.standard(),
            reminders: NotificationReminderScheduler(),
            calendar: .autoupdatingCurrent,
            clock: { Date() }
        )
    }
}
