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
        let u = PixelGrid.uiPoint
        ParchmentSheet(title: model.title(for: day), identifier: "reflection-sheet") {
            Button("Skip") { done() }
                .buttonStyle(.pixel(.paper, size: 10, fill: false))
                .accessibilityIdentifier("reflection-skip-button")
        } trailing: {
            Button("Save") {
                if model.reflect(on: day, answer: answer) { done() }
            }
            .buttonStyle(.pixel(.teal, size: 10, fill: false))
            .disabled(answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .accessibilityIdentifier("reflection-save-button")
        } content: {
            VStack(alignment: .leading, spacing: 5 * u) {
                // The pet asks, in its bubble.
                HStack(alignment: .bottom, spacing: 2 * u) {
                    Group {
                        if let pet = wander.shownPet {
                            PetView(mood: .happy, species: pet.species)
                        } else {
                            EggView(species: wander.hatchingPet?.species ?? wander.nest?.species ?? .pondling, wiggles: false)
                        }
                    }
                    .frame(width: 72, height: 72)
                    Text(model.prompt(for: day).text)
                        .pixelFont(.body, 12)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .pixelPanel(.paper)
                        .accessibilityIdentifier("reflection-prompt-label")
                }
                TextField("A few words", text: $answer, axis: .vertical)
                    .lineLimit(3...6)
                    .focused($focused)
                    .pixelField()
                    .accessibilityIdentifier("reflection-answer-field")
                Text("Optional. Your answers stay on this phone and come back in your weekly recap.")
                    .pixelFont(.body, 9)
                    .foregroundStyle(PixelPalette.plum.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6 * u)
        }
    }
}

/// The reflection on its own, for a check-in that has no sheet of its own
/// (the drink-free button on Home).
struct ReflectionSheet: View {
    let day: LocalDate
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ReflectionView(day: day) { dismiss() }
            .presentationDetents([.medium, .large])
    }
}
