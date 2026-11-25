import SwiftUI
import TippyModeration

/// Log a drink, or edit one. Pick a kind (which fills in a typical size and
/// strength), adjust, choose the day, and optionally count it differently.
/// After a new drink is saved, the day's reflection prompt follows in the
/// same sheet, unless the day already has one.
struct LogDrinkView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    /// The drink being edited, or nil for a new one.
    let editing: DrinkEntry?

    @State private var draft: DrinkDraft
    @State private var date: Date?
    @State private var countsDifferently: Bool
    @State private var reflectingOn: LocalDate?
    @State private var deletingLast: DrinkEntry?

    init(editing: DrinkEntry? = nil) {
        self.editing = editing
        let draft = editing.map { DrinkDraft($0) } ?? DrinkDraft.typical(.beer, in: .fluidOunce)
        _draft = State(initialValue: draft)
        _countsDifferently = State(initialValue: draft.standardDrinksOverride != nil)
    }

    var body: some View {
        NavigationStack {
            if let day = reflectingOn {
                ReflectionView(day: day) { dismiss() }
            } else {
                form
            }
        }
    }

    private var form: some View {
        Form {
            Section("Drink") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                    ForEach(DrinkKind.allCases, id: \.self) { kind in
                        Button {
                            choose(kind)
                        } label: {
                            VStack(spacing: 4) {
                                DrinkIcon(kind: kind).frame(height: 32)
                                Text(kind.displayName).font(.caption)
                            }
                            .frame(maxWidth: .infinity, minHeight: 60)
                        }
                        .buttonStyle(.bordered)
                        .tint(kind == draft.kind ? Color.accentColor : Color.secondary)
                        .accessibilityIdentifier("drink-kind-\(kind.rawValue)")
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Size and strength") {
                Picker("Unit", selection: unitBinding) {
                    ForEach(VolumeUnit.allCases, id: \.self) { Text($0.shortName).tag($0) }
                }
                .pickerStyle(.segmented)
                .accessibilityIdentifier("drink-unit-picker")
                Stepper(value: $draft.amount, in: draft.unit.amountRange, step: draft.unit.step) {
                    Text("\(draft.amount, specifier: draft.unit == .fluidOunce ? "%.1f" : "%.0f") \(draft.unit.shortName)")
                }
                .accessibilityIdentifier("drink-volume-stepper")
                Stepper(value: $draft.abvPercent, in: 0...80, step: 0.5) {
                    Text("\(draft.abvPercent, specifier: "%.1f")% alcohol")
                }
                .accessibilityIdentifier("drink-abv-stepper")
                Toggle("Count it differently", isOn: overrideBinding)
                    .accessibilityIdentifier("drink-override-toggle")
                if let override = draft.standardDrinksOverride {
                    Stepper(value: overrideValue, in: 0...20, step: 0.5) {
                        Text("Counts as \(override.drinksText) drinks")
                    }
                    .accessibilityIdentifier("drink-override-stepper")
                }
                LabeledContent("Standard drinks") {
                    Text((draft.entryPreview?.standardDrinks ?? 0).drinksText)
                        .monospacedDigit()
                        .accessibilityIdentifier("drink-standard-label")
                }
            }
            Section {
                DatePicker("Day", selection: dayBinding, in: ...model.now, displayedComponents: .date)
                    .accessibilityIdentifier("drink-day-picker")
            } footer: {
                Text("A US standard drink is 14 g of alcohol: about a 12 oz beer, a 5 oz glass of wine or a 1.5 oz shot.")
            }
            if let editing {
                Section {
                    Button("Delete drink", role: .destructive) { delete(editing) }
                        .accessibilityIdentifier("delete-drink-button")
                }
            }
        }
        .emptyDayDialog(for: $deletingLast) { dismiss() }
        .navigationTitle(editing == nil ? "Log a drink" : "Edit drink")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Cancel") { dismiss() }
                    .accessibilityIdentifier("cancel-drink-button")
            }
            ToolbarItem(placement: .confirmationAction) {
                Button("Save") { save() }
                    .disabled(draft.entryPreview == nil)
                    .accessibilityIdentifier("save-drink-button")
            }
        }
    }

    private var day: LocalDate {
        if let date { return model.day(of: date) }
        return editing?.day ?? model.today
    }

    private var dayBinding: Binding<Date> {
        Binding(get: { date ?? model.date(of: day) }, set: { date = $0 })
    }

    private var unitBinding: Binding<VolumeUnit> {
        Binding(
            get: { draft.unit },
            set: { unit in
                // Keep the same pour, expressed in the new unit.
                let milliliters = draft.amount * draft.unit.milliliters
                draft.unit = unit
                draft.amount = unit.rounded(milliliters / unit.milliliters)
            }
        )
    }

    private var overrideBinding: Binding<Bool> {
        Binding(
            get: { draft.standardDrinksOverride != nil },
            set: { on in
                let computed = DrinkDraft(kind: draft.kind, amount: draft.amount, unit: draft.unit, abvPercent: draft.abvPercent)
                    .entryPreview?.standardDrinks ?? 1
                draft.standardDrinksOverride = on ? (computed * 2).rounded() / 2 : nil
            }
        )
    }

    private var overrideValue: Binding<Double> {
        Binding(get: { draft.standardDrinksOverride ?? 1 }, set: { draft.standardDrinksOverride = $0 })
    }

    private func choose(_ kind: DrinkKind) {
        let override = draft.standardDrinksOverride
        draft = DrinkDraft.typical(kind, in: draft.unit)
        draft.standardDrinksOverride = override
    }

    private func delete(_ entry: DrinkEntry) {
        if model.isOnlyEntryOnItsDay(entry) {
            deletingLast = entry
        } else {
            model.delete(entry, ifDayEmpties: .clear)
            dismiss()
        }
    }

    private func save() {
        let day = day
        if let editing {
            if model.update(editing, with: draft, on: day) { dismiss() }
            return
        }
        guard model.log(draft, on: day) else { return }
        if model.journal.reflection(on: day) == nil {
            withAnimation { reflectingOn = day }
        } else {
            dismiss()
        }
    }
}
