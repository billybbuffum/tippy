import SwiftUI
import TippyModeration
import TippyWander

/// The day's optional reflection: one prompt, a short answer, and Skip.
/// Saving the day never depends on it.
struct ReflectionView: View {
    @Environment(JournalModel.self) private var model
    @Environment(WanderModel.self) private var wander
    let day: LocalDate
    let done: () -> Void

    @State private var answer = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .top, spacing: 12) {
                Group {
                    if let pet = wander.shownPet {
                        PetView(mood: .happy, species: pet.species)
                    } else {
                        EggView(species: wander.hatchingPet?.species ?? wander.nest?.species ?? .pondling, wiggles: false)
                    }
                }
                .frame(width: 72, height: 72)
                Text(model.prompt(for: day).text)
                    .font(.title3.weight(.semibold))
                    .accessibilityIdentifier("reflection-prompt-label")
            }
            TextField("A few words", text: $answer, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .accessibilityIdentifier("reflection-answer-field")
            Text("Optional. Your answers stay on this phone and come back in your weekly recap.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
        .navigationTitle(model.title(for: day))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Skip") { done() }
                    .accessibilityIdentifier("reflection-skip-button")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") {
                    if model.reflect(on: day, answer: answer) { done() }
                }
                .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                .accessibilityIdentifier("reflection-save-button")
            }
        }
    }
}

/// The reflection on its own, for a check-in that has no sheet of its own
/// (the drink-free button on Home).
struct ReflectionSheet: View {
    let day: LocalDate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ReflectionView(day: day) { dismiss() }
        }
        .presentationDetents([.medium, .large])
    }
}
