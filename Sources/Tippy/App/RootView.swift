import SwiftUI

struct RootView: View {
    @Environment(JournalModel.self) private var model
    @Environment(WanderModel.self) private var wander
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if model.settings.hasOnboarded {
                HomeView()
            } else {
                OnboardingView()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { model.refresh() }
        }
        .alert("Tippy", isPresented: messageShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.message ?? wander.message ?? "")
        }
    }

    /// One alert for either model's message (the journal's first).
    private var messageShown: Binding<Bool> {
        Binding(
            get: { model.message != nil || wander.message != nil },
            set: {
                if !$0 {
                    if model.message != nil { model.message = nil } else { wander.message = nil }
                }
            }
        )
    }
}
