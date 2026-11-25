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
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityIdentifier("find-card-label")
            Button(action: dismiss) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
            .accessibilityIdentifier("find-card-dismiss-button")
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("find-card")
    }
}
