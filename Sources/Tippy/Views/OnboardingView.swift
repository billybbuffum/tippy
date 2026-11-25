import SwiftUI
import TippyModeration

/// First launch: the pet introduces itself and asks five questions.
struct OnboardingView: View {
    @Environment(JournalModel.self) private var model
    @State private var step = 0
    @State private var draft: ModerationSettings = {
        var settings = ModerationSettings()
        settings.petName = ""
        return settings
    }()

    private let lastStep = 4

    var body: some View {
        VStack(spacing: 20) {
            PetView(mood: step == lastStep ? .thriving : .happy)
                .frame(maxWidth: 200)
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
            HStack {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                        .accessibilityIdentifier("onboarding-back-button")
                }
                Button(step == lastStep ? "Let's go" : "Next") { advance() }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .accessibilityIdentifier(step == lastStep ? "onboarding-finish-button" : "onboarding-next-button")
            }
            .padding()
        }
    }

    private var name: String {
        let trimmed = draft.petName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? ModerationSettings.defaultPetName : trimmed
    }

    @ViewBuilder
    private var question: some View {
        switch step {
        case 0:
            Text("Hi! I'm your new companion. I'll keep you company while you cut back. What would you like to call me?")
            TextField(ModerationSettings.defaultPetName, text: $draft.petName)
                .textFieldStyle(.roundedBorder)
                .submitLabel(.next)
                .onSubmit { advance() }
                .accessibilityIdentifier("onboarding-pet-name-field")
            Text("Tippy isn't medical advice. If you drink heavily every day, talk to a doctor before cutting back.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case 1:
            Text("Nice to meet you! I'm \(name). Roughly how many drinks do you have in a typical week?")
            Stepper(value: $draft.baselinePerWeek, in: 0...150, step: 1) {
                Text("\(Int(draft.baselinePerWeek)) drinks a week").font(.headline)
            }
            .accessibilityIdentifier("onboarding-baseline-stepper")
            Text("One drink is a 12 oz beer, a 5 oz glass of wine or a 1.5 oz shot.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case 2:
            Text("What weekly limit would you like to aim for? Cutting back a quarter is a good start.")
            Stepper(value: $draft.weeklyGoal, in: 0...70, step: 1) {
                Text("\(Int(draft.weeklyGoal)) drinks a week").font(.headline)
            }
            .accessibilityIdentifier("onboarding-goal-stepper")
        case 3:
            Text("About how much does a drink cost you? I'll keep track of what you save.")
            Stepper(value: $draft.costPerDrink, in: 0...100, step: 0.5) {
                Text(draft.costPerDrink.formatted(.currency(code: Locale.current.currency?.identifier ?? "USD")))
                    .font(.headline)
            }
            .accessibilityIdentifier("onboarding-cost-stepper")
        default:
            Text("Want me to check in each evening if you haven't logged the day yet?")
            Toggle("Evening reminder", isOn: $draft.reminderEnabled)
                .accessibilityIdentifier("onboarding-reminder-toggle")
            if draft.reminderEnabled {
                DatePicker("Time", selection: reminderTime, displayedComponents: .hourAndMinute)
            }
        }
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                model.calendar.date(bySettingHour: draft.reminderHour, minute: draft.reminderMinute, second: 0, of: model.now) ?? model.now
            },
            set: { date in
                let parts = model.calendar.dateComponents([.hour, .minute], from: date)
                draft.reminderHour = parts.hour ?? 20
                draft.reminderMinute = parts.minute ?? 0
            }
        )
    }

    private func advance() {
        if step == 1 {
            draft.weeklyGoal = max(0, (draft.baselinePerWeek * 0.75).rounded())
        }
        if step < lastStep {
            withAnimation { step += 1 }
        } else {
            let settings = draft
            Task { await model.completeOnboarding(with: settings) }
        }
    }
}
