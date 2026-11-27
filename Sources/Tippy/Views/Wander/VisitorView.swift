import SwiftUI
import TippyWander

/// A visitor found on the Wander, shown once: the cinnamon fox at dusk, or
/// a creature met down a side path (`VisitorProfile`). Closing it in any way
/// marks the visit seen.
struct VisitorView: View {
    let visitorID: String
    let petName: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        let u = PixelGrid.uiPoint
        let profile = VisitorProfile.profile(for: visitorID)
        ParchmentSheet(title: profile.title, identifier: "visitor-dialog", titleIdentifier: "visitor-title-label") {
            EmptyView()
        } trailing: {
            EmptyView()
        } content: {
            VStack(spacing: 4 * u) {
                portrait(profile)
                    .frame(width: 180, height: 180)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(profile.description)
                ScrollView {
                    VStack(alignment: .leading, spacing: 3 * u) {
                        ForEach(profile.lines(petName), id: \.self) { line in
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

    @ViewBuilder
    private func portrait(_ profile: VisitorProfile) -> some View {
        if SpriteLibrary.image(profile.spritePath) != nil {
            SpriteImage(path: profile.spritePath)
        } else if visitorID == "fox-at-dusk" {
            PetSprite(pose: .happy, species: .fox)
        } else {
            Image(systemName: profile.placeholderSymbol)
                .resizable()
                .scaledToFit()
                .padding(40)
                .foregroundStyle(PixelPalette.tealDark)
                .background(Circle().fill(PixelPalette.parchmentLight))
        }
    }
}

/// A visitor waiting to be shown, usable as a sheet's item.
struct VisitorItem: Identifiable {
    let id: String
}
