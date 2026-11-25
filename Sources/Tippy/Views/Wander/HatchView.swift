import SwiftUI
import TippyModeration
import TippyWander

/// A pet waiting for its hatch moment, usable as a cover's item.
struct PetItem: Identifiable {
    let id: String
}

/// The hatch moment, full screen: the egg cracks (the `hatch` strip, or a
/// scale-and-fade without it; a cross-fade under Reduce Motion), the new
/// pet appears, and she names it. The name starts as the species' name (the
/// starter's is the one she chose in onboarding). Done names the pet, which
/// ends the moment.
struct HatchView: View {
    let petID: String

    @Environment(WanderModel.self) private var wander
    @Environment(JournalModel.self) private var journal
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var name = ""
    @State private var crackFrame: Int?
    @State private var petShown = false

    private var pet: Pet? { wander.state.pet(id: petID) }
    private var species: Species { pet?.species ?? .pondling }
    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 24)
            art
                .frame(width: 220, height: 220)
            Text(petShown ? "Welcome, little \(species.name.lowercased())!" : "Something's hatching…")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("hatch-title-label")
            Text("What would you like to call it?")
                .foregroundStyle(.secondary)
            TextField(species.name, text: $name)
                .textFieldStyle(.roundedBorder)
                .multilineTextAlignment(.center)
                .font(.title3)
                .submitLabel(.done)
                .onSubmit(finish)
                .accessibilityIdentifier("hatch-name-field")
                .padding(.horizontal, 40)
            Button(action: finish) {
                Text("Done").frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(trimmedName.isEmpty)
            .accessibilityIdentifier("hatch-done-button")
            .padding(.horizontal, 40)
            Spacer()
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.teal.opacity(0.12).ignoresSafeArea())
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("hatch-view")
        .interactiveDismissDisabled()
        .onAppear {
            if name.isEmpty { name = pet?.name ?? species.name }
        }
        .task { await play() }
    }

    /// The egg, cracking through the strip's frames, with the pet appearing
    /// over the broken shell.
    private var art: some View {
        let frames = SpriteLibrary.frames(of: .hatch)
        return ZStack {
            if let crackFrame, crackFrame < frames.count {
                Image(decorative: frames[crackFrame], scale: 1)
                    .interpolation(.none)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else if !petShown {
                EggView(species: species, wiggles: false)
                    .transition(.scale(scale: 1.3).combined(with: .opacity))
            }
            if petShown {
                PetSprite(pose: .thriving, species: species)
                    .frame(width: 170, height: 170)
                    .offset(y: crackFrame == nil ? 0 : -30)
                    .transition(reduceMotion ? .opacity : .scale(scale: 0.4).combined(with: .opacity))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(petShown ? "A new \(species.name.lowercased()), just hatched" : "An egg, cracking")
    }

    private func play() async {
        try? await Task.sleep(for: .seconds(0.5))
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.6)) { petShown = true }
            return
        }
        let count = SpriteLibrary.frames(of: .hatch).count
        guard count > 0 else {
            withAnimation(.spring(duration: 0.6)) { petShown = true }
            return
        }
        let durations = SpriteAnimation.hatch.durations
        for index in 0..<count {
            if Task.isCancelled { return }
            crackFrame = index
            if index == max(count - 2, 0) {
                withAnimation(.spring(duration: 0.5, bounce: 0.4)) { petShown = true }
            }
            try? await Task.sleep(for: .seconds(durations[min(index, durations.count - 1)]))
        }
    }

    private func finish() {
        let chosen = trimmedName
        guard !chosen.isEmpty, wander.name(petID, chosen) else { return }
        // The active pet's name is also the journal's pet name, which the
        // reminders use.
        if wander.activePet?.id == petID, journal.settings.petName != chosen {
            journal.updateSettings { $0.petName = chosen }
        }
        dismiss()
    }
}
