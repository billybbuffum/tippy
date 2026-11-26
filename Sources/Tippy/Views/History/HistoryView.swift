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
        let u = PixelGrid.uiPoint
        VStack(spacing: 3 * u) {
            Button {
                addingDrinkFreeDay = true
            } label: {
                HStack(spacing: 2 * u) {
                    PixelIcon.leaf
                    Text("Mark a day drink-free")
                }
            }
            .buttonStyle(.pixel(.leaf, size: 10, fill: false))
            .frame(maxWidth: .infinity, alignment: .trailing)
            .padding(.horizontal, 5 * u)
            .accessibilityIdentifier("add-drink-free-day-button")
            List {
                if model.journal.loggedDays.isEmpty {
                    VStack(spacing: 3 * u) {
                        PixelIcon.calendar
                        Text("Nothing logged yet")
                            .pixelFont(.body, 13)
                        Text("Days you log show up here.")
                            .pixelFont(.body, 10)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12 * u)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                }
                ForEach(model.journal.loggedDays, id: \.self) { day in
                    Section {
                        dayHeader(day)
                        if model.journal.isDrinkFree(day) {
                            HStack(spacing: 3 * u) {
                                PixelIcon.leaf
                                Text("Drink-free day")
                                    .pixelFont(.body, 11)
                                    .foregroundStyle(PixelPalette.leafDark)
                            }
                            .accessibilityElement(children: .combine)
                            .accessibilityIdentifier("history-drink-free-row")
                            .swipeActions {
                                Button("Clear", role: .destructive) { model.clearDay(day) }
                            }
                            .listRowBackground(Color.clear)
                        }
                        ForEach(model.journal.entries(on: day)) { entry in
                            Button {
                                editing = entry
                            } label: {
                                EntryRow(entry: entry)
                            }
                            .accessibilityIdentifier("history-entry-row")
                            .listRowBackground(Color.clear)
                        }
                        .onDelete { offsets in
                            let entries = model.journal.entries(on: day)
                            for index in offsets { remove(entries[index]) }
                        }
                        if let reflection = model.journal.reflection(on: day) {
                            ReflectionRow(reflection: reflection)
                                .accessibilityIdentifier("history-reflection-row")
                                .listRowBackground(Color.clear)
                        }
                    }
                    .listRowSeparatorTint(PixelPalette.parchmentShade)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .padding(.vertical, 3 * u)
            .parchmentFrame()
        }
        .pixelScreen("History", identifier: "history-screen")
        .sheet(isPresented: $addingDrinkFreeDay) { DrinkFreeDaySheet() }
        .sheet(item: $editing) { entry in
            LogDrinkView(editing: entry)
        }
        .emptyDayDialog(for: $deletingLast)
    }

    /// The day's title and total, as a small caps row above its entries.
    private func dayHeader(_ day: LocalDate) -> some View {
        HStack {
            Text(model.title(for: day).uppercased())
                .pixelFont(.labelBold, 8)
            Spacer()
            if model.journal.hasDrinks(on: day) {
                Text("\(model.journal.standardDrinks(on: day).drinksText) drinks")
                    .pixelFont(.body, 10)
            }
        }
        .foregroundStyle(PixelPalette.tealDark)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
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
                .foregroundStyle(PixelPalette.tealDark)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.kind.displayName)
                    .pixelFont(.body, 11)
                Text("\(entry.amount, specifier: entry.unit == .fluidOunce ? "%.1f" : "%.0f") \(entry.unit.shortName) · \(entry.abvPercent, specifier: "%.1f")%\(entry.standardDrinksOverride == nil ? "" : " · counted by hand")")
                    .pixelFont(.body, 9)
                    .foregroundStyle(PixelPalette.plum.opacity(0.7))
            }
            Spacer()
            Text(entry.standardDrinks.drinksText)
                .pixelFont(.body, 12)
        }
        .foregroundStyle(PixelPalette.plum)
    }
}

struct ReflectionRow: View {
    let reflection: Reflection

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(ReflectionPrompts.prompt(id: reflection.promptID)?.text ?? "Reflection")
                .pixelFont(.body, 9)
                .foregroundStyle(PixelPalette.plum.opacity(0.7))
            Text(reflection.answer)
                .pixelFont(.body, 11)
                .foregroundStyle(PixelPalette.plum)
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
        ParchmentSheet(title: "Drink-free day", identifier: "drink-free-day-sheet") {
            Button("Cancel") { dismiss() }
                .buttonStyle(.pixel(.paper, size: 10, fill: false))
                .accessibilityIdentifier("drink-free-day-cancel-button")
        } trailing: {
            Button("Mark") {
                if model.markDrinkFree(model.day(of: date ?? model.now)) { dismiss() }
            }
            .buttonStyle(.pixel(.leaf, size: 10, fill: false))
            .accessibilityIdentifier("mark-drink-free-button")
        } content: {
            ScrollView {
                PixelSection(title: "Which day had no drinks?") {
                    // The system calendar: a pixel one would be harder to use.
                    DatePicker(
                        "Day",
                        selection: Binding(get: { date ?? model.now }, set: { date = $0 }),
                        in: ...model.now,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                }
                .padding(.horizontal, 6 * PixelGrid.uiPoint)
            }
        }
    }
}
