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
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    Text("Your week, \(week.rangeText(in: model.calendar))")
                        .font(.title2.bold())
                        .accessibilityAddTraits(.isHeader)
                        .accessibilityIdentifier("recap-title-label")
                    PetView(mood: summary.metGoal ? .thriving : .happy, species: wander.activeSpecies)
                        .frame(width: 120, height: 120)
                        .frame(maxWidth: .infinity)
                    RecapNumbers(summary: summary, coins: rewards.coinsEarned(in: week), bonus: rewards.goalBonus(for: week))
                    RecapReflections(week: week)
                    VStack(alignment: .leading, spacing: 6) {
                        Text("One thing to try next week")
                            .font(.headline)
                        TextField("Optional", text: $idea, axis: .vertical)
                            .lineLimit(2...4)
                            .textFieldStyle(.roundedBorder)
                            .accessibilityIdentifier("recap-idea-field")
                    }
                }
                .padding()
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("weekly-recap-view")
            }
            .navigationTitle("Weekly recap")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        rewards.markRecapSeen(week, nextWeekIdea: idea)
                        dismiss()
                    }
                    .accessibilityIdentifier("recap-done-button")
                }
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
        VStack(alignment: .leading, spacing: 10) {
            // One element each, read as its text (otherwise the icon can take the identifier).
            Label(totalText, systemImage: "drop")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(totalText)
                .accessibilityIdentifier("recap-total-label")
            Label(daysText, systemImage: "leaf")
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(daysText)
                .accessibilityIdentifier("recap-days-label")
            HStack(spacing: 8) {
                CoinIcon()
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(coins.coinsText) earned")
                        .accessibilityIdentifier("recap-coins-label")
                    if let bonus {
                        Text("+\(bonus.coins) for staying within your goal")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .accessibilityIdentifier("recap-goal-bonus-label")
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Your reflections")
                .font(.headline)
            if reflections.isEmpty {
                Text("No reflections this week. They're always optional.")
                    .foregroundStyle(.secondary)
                    .accessibilityIdentifier("recap-no-reflections-label")
            }
            ForEach(reflections, id: \.day) { reflection in
                VStack(alignment: .leading, spacing: 2) {
                    Text(model.title(for: reflection.day))
                        .font(.caption.weight(.semibold))
                    ReflectionRow(reflection: reflection)
                }
                .accessibilityElement(children: .combine)
                .accessibilityIdentifier("recap-reflection-row")
            }
        }
    }
}
