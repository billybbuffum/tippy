import SwiftUI
import TippyWander

/// A visitor found on the Wander, shown once. Today there's one: the
/// cinnamon fox at dusk, who has kind things to say about the pond and never
/// mentions drinking. Closing it in any way marks the visit seen.
struct VisitorView: View {
    let visitorID: String
    let petName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 24)
            Group {
                if SpriteLibrary.image("Pet/fox-dusk") != nil {
                    SpriteImage(path: "Pet/fox-dusk")
                } else {
                    PetSprite(pose: .happy, species: .fox)
                }
            }
            .frame(width: 200, height: 200)
            .accessibilityLabel("A cinnamon fox sitting by a lantern")
            Text("A visitor at dusk")
                .font(.title2.bold())
                .accessibilityIdentifier("visitor-title-label")
            VStack(alignment: .leading, spacing: 12) {
                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
                }
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Text("Wave goodbye").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("visitor-done-button")
        }
        .padding()
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("visitor-dialog")
    }

    private var lines: [String] {
        [
            "Evening! I'm Cinnamon. I wander these reeds when the lanterns come on.",
            "I've seen \(petName) hopping about. Your pond is getting cozier by the day.",
            "I'll be off now. Keep wandering: the willow grove has a few secrets of its own.",
        ]
    }
}

/// A visitor waiting to be shown, usable as a sheet's item.
struct VisitorItem: Identifiable {
    let id: String
}
