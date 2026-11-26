import SwiftUI
import TippyModeration
import TippyRewards

/// The short, warm look back at a finished week: its total against that week's
/// goal, the days, the coins (with the goal bonus if it was earned), her
/// reflections, and an optional idea for the week ahead. Neutral numbers; the
/// pet is never sad here.
struct WeeklyRecapView: View {
    let week: Week

    @Environment(JournalModel.self) private var model
    @Environment(RewardsModel.self) private var rewards
    @Environment(WanderModel.self) private var wander
    @Environment(\.dismiss) private var dismiss
    @State private var idea = ""

    var body: some View {
        let summary = model.journal.summary(of: week, today: model.today)
        let u = PixelGrid.uiPoint
        ParchmentSheet(title: "Weekly recap", identifier: "recap-sheet") {
            EmptyView()
        } trailing: {
            Button("Done") {
                rewards.markRecapSeen(week, nextWeekIdea: idea)
                dismiss()
            }
            .buttonStyle(.pixel(.teal, size: 10, fill: false))
            .accessibilityIdentifier("recap-done-button")
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 6 * u) {
                    Text("Your week, \(week.rangeText(in: model.calendar))")
                        .pixelFont(.body, 14)
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("recap-title-label")
                    PetView(mood: summary.metGoal ? .thriving : .happy, species: wander.activeSpecies)
                        .frame(width: 120, height: 120)
                        .frame(maxWidth: .infinity)
                    RecapNumbers(summary: summary, coins: rewards.coinsEarned(in: week), bonus: rewards.goalBonus(for: week))
                    RecapReflections(week: week)
                    PixelSection(title: "One thing to try next week") {
                        TextField("Optional", text: $idea, axis: .vertical)
                            .lineLimit(2...4)
                            .pixelField()
                            .accessibilityIdentifier("recap-idea-field")
                    }
                }
                .padding(.horizontal, 6 * u)
                .padding(.bottom, 8 * u)
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("weekly-recap-view")
            }
        }
        .onAppear { idea = rewards.nextWeekIdea(for: week) ?? "" }
    }
}

/// The week's numbers, in neutral words.
private struct RecapNumbers: View {
    let summary: WeekSummary
    let coins: Int
    let bonus: Award?

    var body: some View {
        PixelSection(title: nil) {
            row(PixelIcon.drop, totalText, "recap-total-label")
            row(PixelIcon.leaf, daysText, "recap-days-label")
            HStack(alignment: .top, spacing: 3 * PixelGrid.uiPoint) {
                PixelIcon.coin
                VStack(alignment: .leading, spacing: PixelGrid.uiPoint) {
                    Text("\(coins.coinsText) earned")
                        .accessibilityIdentifier("recap-coins-label")
                    if let bonus {
                        Text("+\(bonus.coins) for staying within your goal")
                            .pixelFont(.body, 9)
                            .foregroundStyle(PixelPalette.tealDark)
                            .accessibilityIdentifier("recap-goal-bonus-label")
                    }
                }
            }
        }
        .pixelFont(.body, 11)
    }

    // The identifier goes on the text, so it reads as its words.
    private func row(_ icon: PixelIcon, _ text: String, _ identifier: String) -> some View {
        HStack(alignment: .top, spacing: 3 * PixelGrid.uiPoint) {
            icon
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityIdentifier(identifier)
        }
    }

    private var totalText: String {
        String(format: "%.1f of %.0f drinks", summary.standardDrinks, summary.weeklyGoal)
    }

    private var daysText: String {
        let free = summary.drinkFreeDays == 1 ? "1 drink-free day" : "\(summary.drinkFreeDays) drink-free days"
        return "\(summary.checkedInDays) of 7 days logged, \(free)"
    }
}

/// Her reflections from the week, oldest first, or a gentle line if there are none.
private struct RecapReflections: View {
    let week: Week
    @Environment(JournalModel.self) private var model

    var body: some View {
        let reflections = week.days.compactMap { model.journal.reflection(on: $0) }
        PixelSection(title: "Your reflections") {
            if reflections.isEmpty {
                Text("No reflections this week. They're always optional.")
                    .pixelFont(.body, 10)
                    .accessibilityIdentifier("recap-no-reflections-label")
            }
            ForEach(reflections, id: \.day) { reflection in
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title(for: reflection.day))
                        .pixelFont(.labelBold, 8)
                        .foregroundStyle(PixelPalette.tealDark)
                    ReflectionRow(reflection: reflection)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("recap-reflection-row")
            }
        }
    }
}
