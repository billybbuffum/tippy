import SwiftUI

struct RootView: View {
    @Environment(JournalModel.self) private var model
    @Environment(RewardsModel.self) private var rewards
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
            Text(model.message ?? rewards.message ?? wander.message ?? "")
        }
    }

    /// One alert for either model's message (the journal's first).
    private var messageShown: Binding<Bool> {
        Binding(
            get: { model.message != nil || rewards.message != nil || wander.message != nil },
            set: {
                guard !$0 else { return }
                if model.message != nil { model.message = nil }
                else if rewards.message != nil { rewards.message = nil }
                else { wander.message = nil }
            }
        )
    }
}
