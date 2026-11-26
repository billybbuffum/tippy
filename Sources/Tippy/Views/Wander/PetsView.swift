import SwiftUI
import TippyModeration
import TippyWander

/// Every pet she has hatched, the egg in the nest, and the eggs waiting their
/// turn. Choosing a pet sends it out into the camp; it's free and instant.
struct PetsView: View {
    @Environment(WanderModel.self) private var wander
    @Environment(JournalModel.self) private var journal

    var body: some View {
        let u = PixelGrid.uiPoint
        ScrollView {
            VStack(alignment: .leading, spacing: 6 * u) {
                PixelSection(title: "Your pets") {
                    ForEach(wander.state.pets) { pet in
                        row(for: pet)
                    }
                }
                if let nest = wander.nest {
                    PixelSection(title: "In the nest") {
                        eggRow(species: nest.species, detail: nest.countdownText, wiggles: nest.checkInsLeft == 1)
                            .accessibilityIdentifier("pets-nest-row")
                    }
                }
                if !wander.state.basket.isEmpty {
                    PixelSection(title: "Waiting for the nest") {
                        ForEach(wander.state.basket) { egg in
                            eggRow(species: egg.species ?? .pondling, detail: "Next in line for the nest", wiggles: false)
                                .accessibilityIdentifier("basket-\(egg.id)-row")
                        }
                    }
                }
            }
            .padding(6 * u)
        }
        .parchmentFrame()
        .pixelScreen("Pets", identifier: "pets-screen")
    }

    private func row(for pet: Pet) -> some View {
        let u = PixelGrid.uiPoint
        return HStack(spacing: 4 * u) {
            PetSprite(pose: .happy, species: pet.species)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: u) {
                Text(pet.name)
                    .pixelFont(.body, 13)
                Text("\(pet.species.name) · hatched \(journal.date(of: pet.hatchedOn).formatted(date: .abbreviated, time: .omitted))")
                    .pixelFont(.body, 9)
                    .foregroundStyle(PixelPalette.plum.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            if pet.id == wander.state.activePetID {
                Text("IN THE CAMP")
                    .pixelFont(.labelBold, 8)
                    .foregroundStyle(PixelPalette.leafDark)
                    .accessibilityLabel("In the camp")
                    .accessibilityIdentifier("active-pet-label")
            } else {
                Button("Choose") {
                    withAnimation { _ = wander.setActive(pet.id) }
                }
                .buttonStyle(.pixel(.teal, size: 10, fill: false))
                .accessibilityLabel("Send \(pet.name) out into the camp")
                .accessibilityIdentifier("choose-pet-\(pet.id)-button")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pet-\(pet.id)-row")
    }

    private func eggRow(species: Species, detail: String, wiggles: Bool) -> some View {
        HStack(spacing: 4 * PixelGrid.uiPoint) {
            EggView(species: species, wiggles: wiggles)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: PixelGrid.uiPoint) {
                Text("A \(species.name.lowercased()) egg")
                    .pixelFont(.body, 11)
                Text(detail)
                    .pixelFont(.body, 9)
                    .foregroundStyle(PixelPalette.plum.opacity(0.7))
            }
        }
    }
}
