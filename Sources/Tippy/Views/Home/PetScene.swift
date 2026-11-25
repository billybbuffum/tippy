import SwiftUI
import TippyModeration
import TippyRewards
import TippyWander

/// Home's scene: the pet's name and a caption, then the pond camp with her
/// decorations, the active pet at its spot and the nest at its spot while an
/// egg is nested. Before the starter hatches (and until a new pet's hatch
/// moment plays) the egg in its nest stands at the pet's spot instead.
/// Decorate mode (spec 02) outlines the spots: tap one to place, move or put
/// away a decoration, or, with an item waiting, to put it there.
struct PetScene: View {
    @Binding var decorating: Bool
    /// An item waiting for a spot ("Place it now", or "Move to another spot").
    @Binding var placingItem: String?
    let openShop: () -> Void

    @Environment(JournalModel.self) private var model
    @Environment(RewardsModel.self) private var rewards
    @Environment(WanderModel.self) private var wander
    @State private var slotSheet: CampSlot?
    @State private var shopAfterSheet = false

    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text(name)
                    .font(.title2.bold())
                    .accessibilityIdentifier("pet-name-label")
                Text(caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("pet-mood-label")
            }
            CampSceneView(
                isDusk: isDusk,
                decorating: decorating,
                placingKind: placingItem.flatMap(CampCatalog.item)?.kind,
                onTapSlot: tapped
            ) {
                if let pet = wander.shownPet {
                    PetView(mood: model.mood, species: pet.species)
                        .accessibilityIdentifier("pet-view")
                } else {
                    let hatching = wander.hatchingPet
                    let nest = wander.nest
                    NestView(
                        species: hatching?.species ?? nest?.species ?? .pondling,
                        wiggles: hatching != nil || nest?.checkInsLeft == 1
                    )
                    .accessibilityIdentifier("nest-view")
                }
            } nest: {
                if wander.shownPet != nil, let nest = wander.nest {
                    NestView(species: nest.species, wiggles: nest.checkInsLeft == 1)
                        .accessibilityIdentifier("nest-view")
                }
            }
            .frame(maxWidth: 340)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("camp-scene")
            if let countdown {
                Text(countdown)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("nest-countdown-label")
            }
            campControls
        }
        .sheet(item: $slotSheet, onDismiss: {
            if shopAfterSheet {
                shopAfterSheet = false
                openShop()
            }
        }) { slot in
            SlotSheet(slot: slot, move: { placingItem = $0 }, wantsShop: { shopAfterSheet = true })
        }
    }

    // MARK: Decorating

    @ViewBuilder
    private var campControls: some View {
        if decorating {
            HStack(spacing: 10) {
                Button {
                    openShop()
                } label: {
                    Label("Shop", systemImage: "bag")
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("shop-button")
                Text(hint)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("decorate-hint-label")
                Button("Done") {
                    withAnimation {
                        decorating = false
                        placingItem = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("decorate-done-button")
            }
        } else {
            Button {
                withAnimation { decorating = true }
            } label: {
                Label("Decorate", systemImage: "paintbrush.pointed")
            }
            .buttonStyle(.bordered)
            .accessibilityIdentifier("decorate-button")
        }
    }

    private var hint: String {
        if let item = placingItem.flatMap(CampCatalog.item) { return "Tap a spot for the \(item.name.lowercased())" }
        return "Tap a spot to place or move things"
    }

    private func tapped(_ slot: CampSlot) {
        if let item = placingItem {
            if rewards.place(item, in: slot.id) {
                withAnimation { placingItem = nil }
            }
        } else {
            slotSheet = slot
        }
    }

    // MARK: Pet and nest

    /// Evenings use the dusk background, like the demo clock's 6 PM.
    private var isDusk: Bool {
        let hour = model.calendar.component(.hour, from: model.now)
        return hour >= 18 || hour < 6
    }

    private var countdown: String? {
        if wander.shownPet == nil {
            return wander.hatchingPet != nil ? "Hatching now!" : (wander.nest?.countdownText ?? "")
        }
        return wander.nest?.countdownText
    }

    /// The pet's name: the active pet's, or (before it hatches) the one she
    /// chose in onboarding.
    private var name: String { wander.shownPet?.name ?? model.settings.petName }

    private var caption: String {
        if wander.shownPet != nil { return model.mood.caption(petName: name) }
        if wander.hatchingPet != nil { return "\(name) is hatching!" }
        return "\(name) is snug in the egg. Check in to help it hatch."
    }
}
