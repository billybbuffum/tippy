import SwiftUI
import TippyModeration

struct ContentView: View {
    @Environment(WeekModel.self) private var week

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                PetView(mood: week.mood)
                    .accessibilityIdentifier("pet-view")
                Text(week.summary)
                    .font(.headline)
                    .monospacedDigit()
                    .accessibilityIdentifier("week-total-label")
                Text(week.mood.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("pet-mood-label")
                Spacer()
                Button {
                    week.log(.beer)
                } label: {
                    Label("Log a drink", systemImage: "wineglass")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier("log-drink-button")
                Button {
                    week.logDrinkFreeDay()
                } label: {
                    Label("No drinks today", systemImage: "leaf")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .accessibilityIdentifier("drink-free-button")
            }
            .padding()
            .navigationTitle("Tippy")
        }
    }
}

/// A placeholder pet until real art arrives: an original round critter
/// whose colour and expression follow its mood.
struct PetView: View {
    let mood: PetMood

    var body: some View {
        ZStack {
            Circle()
                .fill(mood.color.gradient)
                .frame(width: 180, height: 180)
            Image(systemName: mood.symbol)
                .font(.system(size: 72))
                .foregroundStyle(.white)
        }
        .animation(.spring, value: mood)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Your pet is \(mood.rawValue)")
    }
}

extension PetMood {
    var caption: String {
        switch self {
        case .thriving: return "Feeling fantastic. Keep it up!"
        case .happy: return "Right on track this week."
        case .okay: return "A little over pace. A drink-free day would help."
        case .concerned: return "Ahead of the budget this week. Tomorrow is a fresh start."
        case .waiting: return "How was today?"
        }
    }

    var symbol: String {
        switch self {
        case .thriving: return "sparkles"
        case .happy: return "face.smiling"
        case .okay: return "cloud.sun"
        case .concerned: return "moon.zzz"
        case .waiting: return "ellipsis.bubble"
        }
    }

    var color: Color {
        switch self {
        case .thriving: return .green
        case .happy: return .teal
        case .okay: return .orange
        case .concerned: return .indigo
        case .waiting: return .gray
        }
    }
}
