import SwiftUI
import TippyModeration
import TippyWander

/// The camp's nest with its egg sitting in it (spec 02's camp will give it a
/// spot; until then Home shows it under the pet, or on its own while the
/// starter hasn't hatched). The egg wiggles when it's one check-in from
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
                    .offset(y: -size * 0.13)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("An egg in the nest")
    }
}

/// The nest under the pet: the egg and its countdown.
struct NestRow: View {
    let nest: NestStatus

    var body: some View {
        HStack(spacing: 12) {
            NestView(species: nest.species, wiggles: nest.checkInsLeft == 1)
                .frame(width: 72, height: 72)
                .accessibilityIdentifier("nest-view")
            Text(nest.countdownText)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("nest-countdown-label")
        }
    }
}
