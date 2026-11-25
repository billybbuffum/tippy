import SwiftUI
import TippyModeration

/// Her "one thing to try next week" from last week's recap, on Home all this
/// week, with an × to hide it. Hiding is a per-device presentation choice, so
/// it lives in `@AppStorage` (the week it was hidden for), not in the ledger.
struct NextWeekIdeaCard: View {
    @Environment(JournalModel.self) private var model
    @Environment(RewardsModel.self) private var rewards
    @AppStorage("recap-idea-hidden-week") private var hiddenWeek = ""

    var body: some View {
        let lastWeek = model.currentWeek.previous
        if let idea = rewards.nextWeekIdea(for: lastWeek), hiddenWeek != lastWeek.start.description {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.yellow)
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Your idea for this week")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(idea)
                        .accessibilityIdentifier("recap-idea-label")
                }
                Spacer(minLength: 0)
                Button {
                    hiddenWeek = lastWeek.start.description
                } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.semibold))
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Hide this idea")
                .accessibilityIdentifier("recap-idea-hide-button")
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("recap-idea-card")
        }
    }
}
