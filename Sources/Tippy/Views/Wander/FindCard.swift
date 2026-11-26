import SwiftUI
import TippyWander

/// A find, announced once: on Home after a sync, or on the trail map as
/// the pet reaches it.
struct FindCard: View {
    let landmark: Landmark
    let petName: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            FindIcon(content: landmark.content)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            Text(landmark.findSentence(petName: petName))
                .pixelFont(.body, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("find-card-label")
            if case .pouch(let coins) = landmark.content {
                HStack(spacing: 2 * PixelGrid.uiPoint) {
                    PixelIcon.coin
                    Text("+\(coins)")
                        .pixelFont(.body, 11)
                }
                .accessibilityHidden(true)
            }
            Button(action: dismiss) {
                PixelIcon.close
            }
            .buttonStyle(.pixel(.parchment, fill: false))
            .accessibilityLabel("Dismiss")
            .accessibilityIdentifier("find-card-dismiss-button")
        }
        .foregroundStyle(PixelPalette.plum)
        .pixelPanel(.parchment)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("find-card")
    }
}
