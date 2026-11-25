import SwiftUI
import TippyModeration

/// First launch: the egg asks four short questions. Tippy never picks the
/// goal: it starts at her typical week and she chooses. The reminder is
/// offered later, after the first check-in (Home's ReminderOfferCard).
struct OnboardingView: View {
    @Environment(JournalModel.self) private var model
    @State private var step = 0
    @State private var name = ""
    @State private var baseline: Double = 14
    @State private var goal: Double = 14
    @State private var cost: Double = 8

    private let lastStep = 3

    var body: some View {
        VStack(spacing: 20) {
            EggView()
                .frame(maxWidth: 160)
                .padding(.top, 24)
            ProgressView(value: Double(step + 1), total: Double(lastStep + 1))
                .padding(.horizontal, 40)
            VStack(alignment: .leading, spacing: 14) {
                question
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal)
            Spacer()
            buttons
                .padding()
        }
    }

    private var petName: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ModerationSettings.defaultPetName : trimmed
    }

    @ViewBuilder
    private var question: some View {
        switch step {
        case 0:
            Text("Hi! I'm still in my egg, but I'll hatch soon and keep you company while you cut back. What would you like to call me?")
            TextField(ModerationSettings.defaultPetName, text: $name)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.next)
                .onSubmit { advance() }
                .accessibilityIdentifier("onboarding-pet-name-field")
            Text("Tippy isn't medical advice. If you drink heavily every day, talk to a doctor before cutting back.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case 1:
            Text("\(petName) it is! Roughly how many drinks do you have in a typical week?")
            Stepper(value: $baseline, in: 0...150, step: 1) {
                Text("\(Int(baseline)) drinks a week").font(.headline)
            }
            .accessibilityIdentifier("onboarding-baseline-stepper")
            Text("One drink is a 12 oz beer, a 5 oz glass of wine or a 1.5 oz shot.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case 2:
            Text("What weekly limit would you like to aim for? You can change it any time.")
            Stepper(value: $goal, in: 0...70, step: 1) {
                Text("\(Int(goal)) drinks a week").font(.headline)
            }
            .accessibilityIdentifier("onboarding-goal-stepper")
        default:
            Text("If you like, tell me what a drink usually costs and I'll keep track of what you spend. You can skip this.")
            Stepper(value: $cost, in: 0...100, step: 0.5) {
                Text(cost.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                    .font(.headline)
            }
            .accessibilityIdentifier("onboarding-cost-stepper")
        }
    }

    private var buttons: some View {
        HStack {
            if step > 0 {
                Button("Back") { withAnimation { step -= 1 } }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("onboarding-back-button")
            }
            if step == lastStep {
                Button("Skip") { finish(withCost: false) }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .accessibilityIdentifier("onboarding-skip-cost-button")
                Button("Let's go") { finish(withCost: true) }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("onboarding-finish-button")
            } else {
                Button("Next") { advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier("onboarding-next-button")
            }
        }
    }

    private func advance() {
        // The goal starts at her typical week; she decides whether to change it.
        if step == 1 { goal = min(baseline, 70) }
        withAnimation { step = min(step + 1, lastStep) }
    }

    private func finish(withCost: Bool) {
        var settings = ModerationSettings()
        settings.petName = petName
        settings.baselinePerWeek = baseline
        settings.costPerDrink = withCost ? cost : nil
        model.completeOnboarding(with: settings, weeklyGoal: goal)
    }
}
