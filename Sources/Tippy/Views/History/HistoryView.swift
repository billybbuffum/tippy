import SwiftUI
import TippyModeration

/// Every logged day, newest first: its drinks (tap to edit, swipe to delete),
/// its drink-free mark, and its reflection. Past days can be marked
/// drink-free. Deleting a day's last drink asks what the day becomes.
struct HistoryView: View {
    @Environment(JournalModel.self) private var model
    @State private var addingDrinkFreeDay = false
    @State private var editing: DrinkEntry?
    @State private var deletingLast: DrinkEntry?

    var body: some View {
        List {
            if model.journal.loggedDays.isEmpty {
                ContentUnavailableView("Nothing logged yet", systemImage: "calendar", description: Text("Days you log show up here."))
            }
            ForEach(model.journal.loggedDays, id: \.self) { day in
                Section {
                    if model.journal.isDrinkFree(day) {
                        Label("Drink-free day", systemImage: "leaf.fill")
                            .foregroundStyle(.green)
                            .accessibilityIdentifier("history-drink-free-row")
                            .swipeActions {
                                Button("Clear", role: .destructive) { model.clearDay(day) }
                            }
                    }
                    ForEach(model.journal.entries(on: day)) { entry in
                        Button {
                            editing = entry
                        } label: {
                            EntryRow(entry: entry)
                        }
                        .foregroundStyle(.primary)
                        .accessibilityIdentifier("history-entry-row")
                    }
                    .onDelete { offsets in
                        let entries = model.journal.entries(on: day)
                        for index in offsets { remove(entries[index]) }
                    }
                    if let reflection = model.journal.reflection(on: day) {
                        ReflectionRow(reflection: reflection)
                            .accessibilityIdentifier("history-reflection-row")
                    }
                } header: {
                    HStack {
                        Text(model.title(for: day))
                        Spacer()
                        if model.journal.hasDrinks(on: day) {
                            Text("\(model.journal.standardDrinks(on: day).drinksText) drinks").monospacedDigit()
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    addingDrinkFreeDay = true
                } label: {
                    Label("Mark a day drink-free", systemImage: "leaf.circle")
                }
                .accessibilityIdentifier("add-drink-free-day-button")
            }
        }
        .sheet(isPresented: $addingDrinkFreeDay) { DrinkFreeDaySheet() }
        .sheet(item: $editing) { entry in
            LogDrinkView(editing: entry)
        }
        .emptyDayDialog(for: $deletingLast)
    }

    /// Deletes right away, unless it's the day's last drink: then ask.
    private func remove(_ entry: DrinkEntry) {
        if model.isOnlyEntryOnItsDay(entry) {
            deletingLast = entry
        } else {
            model.delete(entry, ifDayEmpties: .clear)
        }
    }
}

struct EntryRow: View {
    let entry: DrinkEntry

    var body: some View {
        HStack {
            DrinkIcon(kind: entry.kind)
                .frame(width: 28, height: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(entry.kind.displayName)
                Text("\(entry.amount, specifier: entry.unit == .fluidOunce ? "%.1f" : "%.0f") \(entry.unit.shortName) · \(entry.abvPercent, specifier: "%.1f")%\(entry.standardDrinksOverride == nil ? "" : " · counted by hand")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.standardDrinks.drinksText).monospacedDigit()
        }
    }
}

struct ReflectionRow: View {
    let reflection: Reflection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ReflectionPrompts.prompt(id: reflection.promptID)?.text ?? "Reflection")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(reflection.answer)
                .italic()
        }
        .padding(.vertical, 2)
    }
}

/// Back-fill a drink-free day.
struct DrinkFreeDaySheet: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date?

    var body: some View {
        NavigationStack {
            Form {
                DatePicker(
                    "Day",
                    selection: Binding(get: { date ?? model.now }, set: { date = $0 }),
                    in: ...model.now,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
            }
            .navigationTitle("Drink-free day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Mark") {
                        if model.markDrinkFree(model.day(of: date ?? model.now)) { dismiss() }
                    }
                    .accessibilityIdentifier("mark-drink-free-button")
                }
            }
        }
    }
}
