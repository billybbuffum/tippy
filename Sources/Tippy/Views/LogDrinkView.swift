import SwiftUI
import TippyModeration

/// Log one drink: pick a kind (which fills in a typical size and
/// strength), adjust, and choose the day (today, or earlier to back-fill).
struct LogDrinkView: View {
    @Environment(JournalModel.self) private var model
    @Environment(\.dismiss) private var dismiss

    @State private var kind: DrinkKind = .beer
    @State private var ounces: Double = 12
    @State private var abv: Double = 5
    @State private var date: Date?

    var body: some View {
        NavigationStack {
            Form {
                Section("Drink") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 10)], spacing: 10) {
                        ForEach(DrinkKind.allCases, id: \.self) { option in
                            Button {
                                choose(option)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: option.symbol).font(.title2)
                                    Text(option.displayName).font(.caption)
                                }
                                .frame(maxWidth: .infinity, minHeight: 56)
                            }
                            .buttonStyle(.bordered)
                            .tint(option == kind ? Color.accentColor : Color.secondary)
                            .accessibilityIdentifier("drink-kind-\(option.rawValue)")
                        }
                    }
                    .padding(.vertical, 4)
                }
                Section("Size and strength") {
                    Stepper(value: $ounces, in: 0.5...64, step: 0.5) {
                        Text("\(ounces, specifier: "%.1f") fl oz")
                    }
                    .accessibilityIdentifier("drink-volume-stepper")
                    Stepper(value: $abv, in: 0...80, step: 0.5) {
                        Text("\(abv, specifier: "%.1f")% alcohol")
                    }
                    .accessibilityIdentifier("drink-abv-stepper")
                    LabeledContent("Standard drinks") {
                        Text((serving?.standardDrinks ?? 0).drinksText)
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
            }
            .navigationTitle("Log a drink")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .accessibilityIdentifier("cancel-drink-button")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(serving == nil)
                        .accessibilityIdentifier("save-drink-button")
                }
            }
        }
    }

    private var serving: DrinkServing? {
        DrinkServing(volumeMilliliters: ounces * Units.millilitersPerFluidOunce, abvPercent: abv)
    }

    private var dayBinding: Binding<Date> {
        Binding(get: { date ?? model.now }, set: { date = $0 })
    }

    private func choose(_ option: DrinkKind) {
        kind = option
        let typical = option.defaultServing
        ounces = (typical.volumeMilliliters / Units.millilitersPerFluidOunce * 2).rounded() / 2
        abv = typical.abvPercent
    }

    private func save() {
        guard let serving else { return }
        model.log(kind: kind, serving: serving, on: model.day(of: date ?? model.now))
        dismiss()
    }
}
