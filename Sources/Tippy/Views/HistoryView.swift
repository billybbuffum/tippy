import SwiftUI
import TippyModeration

/// Every logged day, newest first: its drinks (swipe to delete) or its
/// drink-free mark (swipe to remove). Past days can be marked drink-free.
struct HistoryView: View {
    @Environment(JournalModel.self) private var model
    @State private var addingDrinkFreeDay = false

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
                                Button("Remove", role: .destructive) { model.clearDrinkFree(day) }
                            }
                    }
                    ForEach(model.journal.entries(on: day)) { entry in
                        EntryRow(entry: entry)
                            .accessibilityIdentifier("history-entry-row")
                    }
                    .onDelete { offsets in
                        let entries = model.journal.entries(on: day)
                        for index in offsets { model.delete(entries[index]) }
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
    }
}

struct EntryRow: View {
    let entry: DrinkEntry

    var body: some View {
        HStack {
            Image(systemName: entry.kind.symbol)
                .frame(width: 28)
                .foregroundStyle(.secondary)
            VStack(alignment: .leading) {
                Text(entry.kind.displayName)
                Text("\(entry.volumeMilliliters / Units.millilitersPerFluidOunce, specifier: "%.1f") fl oz · \(entry.abvPercent, specifier: "%.1f")%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(entry.standardDrinks.drinksText).monospacedDigit()
        }
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
                        model.markDrinkFree(model.day(of: date ?? model.now))
                        dismiss()
                    }
                    .accessibilityIdentifier("mark-drink-free-button")
                }
            }
        }
    }
}
