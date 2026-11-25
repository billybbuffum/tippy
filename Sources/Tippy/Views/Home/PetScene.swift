import SwiftUI
import TippyModeration
import TippyWander

/// Home's scene: the active pet in its mood, with the nest under it while
/// an egg is nested, then its name and a caption. Before the starter hatches
/// (and until a new pet's hatch moment plays) the egg in its nest stands in
/// for the pet. Spec 02's camp scene will take this place.
struct PetScene: View {
    @Environment(JournalModel.self) private var model
    @Environment(WanderModel.self) private var wander

    var body: some View {
        VStack(spacing: 20) {
            if let pet = wander.shownPet {
                PetView(mood: model.mood, species: pet.species)
                    .frame(maxWidth: 240)
                    .accessibilityIdentifier("pet-view")
                if let nest = wander.nest {
                    NestRow(nest: nest)
                }
            } else {
                egg
            }
            VStack(spacing: 6) {
                Text(name)
                    .font(.title2.bold())
                    .accessibilityIdentifier("pet-name-label")
                Text(caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("pet-mood-label")
            }
        }
    }

    /// The pet's name: the active pet's, or (before it hatches) the one she
    /// chose in onboarding.
    private var name: String { wander.shownPet?.name ?? model.settings.petName }

    private var caption: String {
        if wander.shownPet != nil { return model.mood.caption(petName: name) }
        if wander.hatchingPet != nil { return "\(name) is hatching!" }
        return "\(name) is snug in the egg. Check in to help it hatch."
    }

    private var egg: some View {
        let hatching = wander.hatchingPet
        let nest = wander.nest
        return VStack(spacing: 8) {
            NestView(
                species: hatching?.species ?? nest?.species ?? .pondling,
                wiggles: hatching != nil || nest?.checkInsLeft == 1
            )
            .frame(maxWidth: 200)
            .accessibilityIdentifier("nest-view")
            Text(hatching != nil ? "Hatching now!" : (nest?.countdownText ?? ""))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("nest-countdown-label")
        }
    }
}
