import SwiftUI

struct RootView: View {
    @Environment(JournalModel.self) private var model
    @Environment(RewardsModel.self) private var rewards
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
            Text(model.message ?? rewards.message ?? "")
        }
    }

    private var messageShown: Binding<Bool> {
        Binding(
            get: { model.message != nil || rewards.message != nil },
            set: {
                guard !$0 else { return }
                if model.message != nil { model.message = nil } else { rewards.message = nil }
            }
        )
    }
}
