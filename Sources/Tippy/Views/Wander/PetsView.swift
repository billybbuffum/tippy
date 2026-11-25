import SwiftUI
import TippyModeration
import TippyWander

/// Every pet she has hatched, the egg in the nest, and the eggs waiting their
/// turn. Choosing a pet sends it out into the camp; it's free and instant.
struct PetsView: View {
    @Environment(WanderModel.self) private var wander
    @Environment(JournalModel.self) private var journal

    var body: some View {
        List {
            Section("Your pets") {
                ForEach(wander.state.pets) { pet in
                    row(for: pet)
                }
            }
            if let nest = wander.nest {
                Section("In the nest") {
                    eggRow(species: nest.species, detail: nest.countdownText, wiggles: nest.checkInsLeft == 1)
                        .accessibilityIdentifier("pets-nest-row")
                }
            }
            if !wander.state.basket.isEmpty {
                Section("Waiting for the nest") {
                    ForEach(wander.state.basket) { egg in
                        eggRow(species: egg.species ?? .pondling, detail: "Next in line for the nest", wiggles: false)
                            .accessibilityIdentifier("basket-\(egg.id)-row")
                    }
                }
            }
        }
        .navigationTitle("Pets")
    }

    private func row(for pet: Pet) -> some View {
        HStack(spacing: 12) {
            PetSprite(pose: .happy, species: pet.species)
                .frame(width: 56, height: 56)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(pet.name).font(.headline)
                Text("\(pet.species.name) · hatched \(journal.date(of: pet.hatchedOn).formatted(date: .abbreviated, time: .omitted))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if pet.id == wander.state.activePetID {
                Text("In the camp")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .accessibilityIdentifier("active-pet-label")
            } else {
                Button("Choose") {
                    withAnimation { _ = wander.setActive(pet.id) }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Send \(pet.name) out into the camp")
                .accessibilityIdentifier("choose-pet-\(pet.id)-button")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("pet-\(pet.id)-row")
    }

    private func eggRow(species: Species, detail: String, wiggles: Bool) -> some View {
        HStack(spacing: 12) {
            EggView(species: species, wiggles: wiggles)
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text("A \(species.name.lowercased()) egg").font(.subheadline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}
