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
        let u = PixelGrid.uiPoint
        ParchmentSheet(title: "A visitor at dusk", identifier: "visitor-dialog", titleIdentifier: "visitor-title-label") {
            EmptyView()
        } trailing: {
            EmptyView()
        } content: {
            VStack(spacing: 4 * u) {
                Group {
                    if SpriteLibrary.image("Pet/fox-dusk") != nil {
                        SpriteImage(path: "Pet/fox-dusk")
                    } else {
                        PetSprite(pose: .happy, species: .fox)
                    }
                }
                .frame(width: 180, height: 180)
                .accessibilityLabel("A cinnamon fox sitting by a lantern")
                ScrollView {
                    VStack(alignment: .leading, spacing: 3 * u) {
                        ForEach(lines, id: \.self) { line in
                            Text(line)
                                .pixelFont(.body, 11)
                                .fixedSize(horizontal: false, vertical: true)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .pixelPanel(.paper)
                        }
                    }
                }
                Button("Wave goodbye") { dismiss() }
                    .buttonStyle(.pixel(.teal))
                    .accessibilityIdentifier("visitor-done-button")
            }
            .padding(.horizontal, 6 * u)
            .padding(.bottom, 4 * u)
        }
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
