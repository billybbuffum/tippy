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
                PixelIcon.bulb
                VStack(alignment: .leading, spacing: 4) {
                    Text("YOUR IDEA FOR THIS WEEK")
                        .pixelFont(.labelBold, 8)
                        .foregroundStyle(PixelPalette.tealDark)
                    Text(idea)
                        .pixelFont(.body, 10)
                        .accessibilityIdentifier("recap-idea-label")
                }
                Spacer(minLength: 0)
                Button {
                    hiddenWeek = lastWeek.start.description
                } label: {
                    PixelIcon.close
                }
                .buttonStyle(.pixel(.parchment, fill: false))
                .accessibilityLabel("Hide this idea")
                .accessibilityIdentifier("recap-idea-hide-button")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(PixelPalette.plum)
            .pixelPanel(.parchment)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("recap-idea-card")
        }
    }
}
