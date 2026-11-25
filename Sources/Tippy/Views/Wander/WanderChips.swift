import SwiftUI
import TippyWander

/// Home's Wander chips, under the pet's name: how far the next landmark is
/// ("4 steps to the Reed Bed") and the Wander button. Both open the map.
/// They sit high on Home, clear of the bottom action bar.
struct WanderChips: View {
    @Environment(WanderModel.self) private var wander
    let open: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Button(action: open) {
                Label(wander.state.nextLandmarkCaption, systemImage: "flag")
                    .font(.subheadline)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .buttonStyle(.bordered)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("wander-next-label")
            Button(action: open) {
                Label("Wander", systemImage: "map")
                    .font(.subheadline.weight(.semibold))
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .accessibilityIdentifier("wander-button")
        }
    }
}
