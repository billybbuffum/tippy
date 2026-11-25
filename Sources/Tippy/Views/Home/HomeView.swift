import SwiftUI
import TippyModeration

struct HomeView: View {
    @Environment(JournalModel.self) private var model
    @State private var showingLog = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    PetView(mood: model.mood)
                        .frame(maxWidth: 240)
                        .accessibilityIdentifier("pet-view")
                    VStack(spacing: 6) {
                        Text(model.settings.petName)
                            .font(.title2.bold())
                            .accessibilityIdentifier("pet-name-label")
                        Text(model.mood.caption(petName: model.settings.petName))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .accessibilityIdentifier("pet-mood-label")
                    }
                    WeekCard(summary: model.summary, streak: model.streak)
                    todayCard
                }
                .padding()
            }
            .safeAreaInset(edge: .bottom) { actions }
            .navigationTitle("Tippy")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        HistoryView()
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("History")
                    .accessibilityIdentifier("history-button")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                    .accessibilityIdentifier("settings-button")
                }
            }
            .sheet(isPresented: $showingLog) { LogDrinkView() }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
    }

    private var todayLine: String {
        if model.isTodayDrinkFree { return "Today is a drink-free day" }
        if model.isTodayLogged { return "Today: \(model.todaysDrinks.drinksText) standard drinks" }
        return "Today isn't logged yet"
    }

    private var todayCard: some View {
        HStack {
            Image(systemName: model.isTodayDrinkFree ? "leaf.fill" : (model.isTodayLogged ? "checkmark.circle.fill" : "circle.dashed"))
                .foregroundStyle(model.isTodayLogged ? Color.green : Color.secondary)
            Text(todayLine)
                .accessibilityIdentifier("today-status-label")
            Spacer()
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
    }

    private var actions: some View {
        VStack(spacing: 10) {
            Button {
                showingLog = true
            } label: {
                Label("Log a drink", systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .accessibilityIdentifier("log-drink-button")
            Button {
                model.markDrinkFree(model.today)
            } label: {
                Label(model.isTodayDrinkFree ? "Drink-free today" : "No drinks today", systemImage: "leaf")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(model.isTodayLogged)
            .accessibilityIdentifier("drink-free-button")
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.bar)
    }
}

/// This week at a glance: a ring of the goal used, and the numbers.
struct WeekCard: View {
    let summary: WeekSummary
    let streak: Int

    var body: some View {
        HStack(spacing: 18) {
            ZStack {
                Circle().stroke(Color.secondary.opacity(0.2), lineWidth: 12)
                Circle()
                    .trim(from: 0, to: summary.progress)
                    .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut, value: summary.progress)
                VStack(spacing: 0) {
                    Text(summary.standardDrinks.drinksText).font(.title2.bold()).monospacedDigit()
                    Text("of \(Int(summary.weeklyGoal))").font(.caption).foregroundStyle(.secondary)
                }
            }
            .frame(width: 104, height: 104)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 8) {
                Text(String(format: "%.1f of %.0f drinks this week", summary.standardDrinks, summary.weeklyGoal))
                    .font(.headline)
                    .accessibilityIdentifier("week-total-label")
                Label("\(summary.remaining.drinksText) left", systemImage: "drop")
                Label("\(summary.drinkFreeDays) drink-free \(summary.drinkFreeDays == 1 ? "day" : "days")", systemImage: "leaf")
                    .accessibilityIdentifier("drink-free-count-label")
                Label("\(streak)-day streak", systemImage: "flame")
                    .accessibilityIdentifier("streak-label")
            }
            .font(.subheadline)
            Spacer(minLength: 0)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
    }

    private var ringColor: Color {
        summary.standardDrinks > summary.weeklyGoal ? .orange : .green
    }
}
