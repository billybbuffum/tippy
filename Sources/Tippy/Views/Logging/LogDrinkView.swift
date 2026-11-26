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
        if let day = reflectingOn {
            ReflectionView(day: day) { dismiss() }
        } else {
            form
        }
    }

    private var form: some View {
        let u = PixelGrid.uiPoint
        return ParchmentSheet(
            title: editing == nil ? "Log a drink" : "Edit drink",
            identifier: editing == nil ? "log-drink-sheet" : "edit-drink-sheet"
        ) {
            Button("Cancel") { dismiss() }
                .buttonStyle(.pixel(.paper, size: 10, fill: false))
                .accessibilityIdentifier("cancel-drink-button")
        } trailing: {
            Button("Save") { save() }
                .buttonStyle(.pixel(.teal, size: 10, fill: false))
                .disabled(draft.entryPreview == nil)
                .accessibilityIdentifier("save-drink-button")
        } content: {
            ScrollView {
                VStack(alignment: .leading, spacing: 6 * u) {
                    PixelSection(title: "Drink") {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 3 * u)], spacing: 3 * u) {
                            ForEach(DrinkKind.allCases, id: \.self) { kind in
                                Button {
                                    choose(kind)
                                } label: {
                                    VStack(spacing: 2 * u) {
                                        DrinkIcon(kind: kind).frame(height: 32)
                                        Text(kind.displayName)
                                    }
                                }
                                .buttonStyle(.pixel(kind == draft.kind ? .chosen : .paper, size: 9))
                                .accessibilityAddTraits(kind == draft.kind ? .isSelected : [])
                                .accessibilityIdentifier("drink-kind-\(kind.rawValue)")
                            }
                        }
                    }
                    PixelSection(title: "Size and strength") {
                        PixelSegmented(options: VolumeUnit.allCases, selection: unitBinding) { $0.shortName }
                            .accessibilityIdentifier("drink-unit-picker")
                        PixelStepper(
                            name: "Amount",
                            text: "\(String(format: draft.unit == .fluidOunce ? "%.1f" : "%.0f", draft.amount)) \(draft.unit.shortName)",
                            value: $draft.amount,
                            range: draft.unit.amountRange,
                            step: draft.unit.step
                        )
                        .accessibilityIdentifier("drink-volume-stepper")
                        PixelStepper(
                            name: "Alcohol",
                            text: String(format: "%.1f%% alcohol", draft.abvPercent),
                            value: $draft.abvPercent,
                            range: 0...80,
                            step: 0.5
                        )
                        .accessibilityIdentifier("drink-abv-stepper")
                        Toggle("Count it differently", isOn: overrideBinding)
                            .toggleStyle(.pixel)
                            .accessibilityIdentifier("drink-override-toggle")
                        if let override = draft.standardDrinksOverride {
                            PixelStepper(
                                name: "Standard drinks",
                                text: "Counts as \(override.drinksText) drinks",
                                value: overrideValue,
                                range: 0...20,
                                step: 0.5
                            )
                            .accessibilityIdentifier("drink-override-stepper")
                        }
                        HStack {
                            Text("Standard drinks")
                                .pixelFont(.body, 11)
                            Spacer()
                            Text((draft.entryPreview?.standardDrinks ?? 0).drinksText)
                                .pixelFont(.body, 13)
                                .foregroundStyle(PixelPalette.tealDark)
                                .accessibilityIdentifier("drink-standard-label")
                        }
                    }
                    PixelSection(
                        title: "Day",
                        footer: "A US standard drink is 14 g of alcohol: about a 12 oz beer, a 5 oz glass of wine or a 1.5 oz shot."
                    ) {
                        DatePicker("Day", selection: dayBinding, in: ...model.now, displayedComponents: .date)
                            .pixelFont(.body, 11)
                            .accessibilityIdentifier("drink-day-picker")
                    }
                }
                .padding(.horizontal, 6 * u)
                .padding(.bottom, 8 * u)
            }
            .safeAreaInset(edge: .bottom) {
                if let editing {
                    // Always in view, however far the form scrolls.
                    Button("Delete drink") { delete(editing) }
                        .buttonStyle(.pixel(.wood, size: 11))
                        .accessibilityIdentifier("delete-drink-button")
                        .padding(.horizontal, 6 * u)
                        .padding(.vertical, 3 * u)
                }
            }
        }
        .emptyDayDialog(for: $deletingLast) { dismiss() }
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
