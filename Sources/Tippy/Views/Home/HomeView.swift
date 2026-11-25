import SwiftUI
import TippyModeration

struct HomeView: View {
    @Environment(JournalModel.self) private var model
    @State private var showingLog = false
    @State private var showingSettings = false
    @State private var reflecting: DayItem?

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
                    if model.shouldOfferReminder {
                        // Near the top: it's shown once, so it must be in view
                        // without scrolling, clear of the bottom action bar.
                        ReminderOfferCard()
                    }
                    WeekCard(summary: model.summary)
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
            .sheet(item: $reflecting) { item in ReflectionSheet(day: item.day) }
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
                let today = model.today
                if model.markDrinkFree(today), model.journal.reflection(on: today) == nil {
                    reflecting = DayItem(day: today)
                }
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

/// This week at a glance: a ring of the goal used, and the numbers, in
/// neutral words (the pet carries the feelings).
struct WeekCard: View {
    let summary: WeekSummary

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
                Label("\(summary.checkedInDays) of \(summary.daysElapsed) days logged", systemImage: "checkmark.circle")
                    .accessibilityIdentifier("days-logged-label")
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

/// The reminder, offered once after the first check-in.
struct ReminderOfferCard: View {
    @Environment(JournalModel.self) private var model

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Want a nudge in the evening if the day isn't logged yet?", systemImage: "bell")
                .font(.subheadline)
            HStack {
                Button("Remind me at \(model.reminderTimeToday.formatted(date: .omitted, time: .shortened))") {
                    Task { await model.answerReminderOffer(accept: true) }
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("reminder-offer-accept-button")
                Button("Not now") {
                    Task { await model.answerReminderOffer(accept: false) }
                }
                .buttonStyle(.bordered)
                .accessibilityIdentifier("reminder-offer-dismiss-button")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("reminder-offer-card")
    }
}
