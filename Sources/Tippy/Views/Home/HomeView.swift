import SwiftUI
import TippyModeration
import TippyRewards
import TippyWander

struct HomeView: View {
    @Environment(JournalModel.self) private var model
    @Environment(RewardsModel.self) private var rewards
    @Environment(WanderModel.self) private var wander
    @State private var showingLog = false
    @State private var showingSettings = false
    @State private var reflecting: DayItem?
    @State private var showingWander = false
    @State private var hatching: PetItem?
    @State private var showingShop = false
    @State private var decorating = false
    @State private var placingItem: String?
    /// Whether Home is the screen in front (nothing pushed over it). A plain
    /// box, not observed: flipping it must not re-render Home mid-push.
    @State private var front = FrontFlag()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // One-time cards first: shown once, so they must be in view without
                    // scrolling, clear of the bottom action bar under the tall camp scene.
                    if let find = wander.unannouncedFinds.first {
                        FindCard(landmark: find, petName: wander.shownPet?.name ?? model.settings.petName) {
                            withAnimation { wander.announceFind(find.id) }
                        }
                    }
                    if model.shouldOfferReminder {
                        ReminderOfferCard()
                    }
                    PetScene(decorating: $decorating, placingItem: $placingItem) { showingShop = true }
                    WanderChips { showingWander = true }
                    NextWeekIdeaCard()
                    WeekCard(summary: model.summary)
                    todayCard
                }
                .padding()
            }
            .onAppear {
                front.isFront = true
                presentHatch()
            }
            .onDisappear { front.isFront = false }
            .modifier(RewardsPresentation(otherSheetShowing: showingLog || showingSettings || showingShop || reflecting != nil || hatching != nil || wander.state.pendingHatch != nil))
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
                    CoinBadge(balance: rewards.balance) { showingShop = true }
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
            .navigationDestination(isPresented: $showingWander) { TrailMapView() }
            .sheet(isPresented: $showingLog, onDismiss: presentHatch) { LogDrinkView() }
            .sheet(isPresented: $showingSettings, onDismiss: presentHatch) { SettingsView() }
            .sheet(isPresented: $showingShop, onDismiss: presentHatch) {
                ShopView { itemID in
                    decorating = true
                    placingItem = itemID
                }
            }
            .sheet(item: $reflecting, onDismiss: presentHatch) { item in ReflectionSheet(day: item.day) }
            .fullScreenCover(item: $hatching) { item in HatchView(petID: item.id) }
            .onChange(of: wander.state.pendingHatch) { presentHatch() }
        }
    }

    /// The hatch moment waits until Home is in front with no sheet up (a
    /// check-in hatches the egg, then the reflection usually follows), so
    /// it plays as soon as she's back.
    private func presentHatch() {
        guard front.isFront, hatching == nil, !showingLog, !showingSettings, !showingShop, reflecting == nil,
              let id = wander.state.pendingHatch else { return }
        hatching = PetItem(id: id)
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

/// A flag Home sets on appear and disappear without causing a re-render.
final class FrontFlag {
    var isFront = false
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
