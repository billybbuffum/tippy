import SwiftUI
import TippyModeration
import TippyWander

/// The camp's nest with its egg sitting in it, at the nest's spot in the camp
/// scene (or at the pet's spot while the starter hasn't hatched). The egg wiggles when it's one check-in from
/// hatching, motion permitting.
struct NestView: View {
    let species: Species
    let wiggles: Bool

    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height)
            ZStack {
                if SpriteLibrary.image("Camp/nest") != nil {
                    SpriteImage(path: "Camp/nest")
                } else {
                    Ellipse()
                        .fill(Color.brown.opacity(0.6))
                        .frame(width: size * 0.8, height: size * 0.4)
                        .offset(y: size * 0.1)
                }
                EggView(species: species, wiggles: wiggles)
                    .frame(width: size * 0.6, height: size * 0.6)
                    .offset(y: -size * 0.09)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("An egg in the nest")
    }
}
