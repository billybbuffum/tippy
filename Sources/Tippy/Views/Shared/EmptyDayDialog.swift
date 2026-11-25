import SwiftUI
import TippyModeration

extension View {
    /// Asks what a day becomes when its only drink is deleted: drink-free, or
    /// cleared. Present by setting `entry`; `deleted` runs after either choice.
    func emptyDayDialog(for entry: Binding<DrinkEntry?>, deleted: @escaping () -> Void = {}) -> some View {
        modifier(EmptyDayDialog(entry: entry, deleted: deleted))
    }
}

private struct EmptyDayDialog: ViewModifier {
    @Environment(JournalModel.self) private var model
    @Binding var entry: DrinkEntry?
    let deleted: () -> Void

    func body(content: Content) -> some View {
        content.confirmationDialog(
            "That was the day's only drink.",
            isPresented: Binding(get: { entry != nil }, set: { if !$0 { entry = nil } }),
            titleVisibility: .visible,
            presenting: entry
        ) { entry in
            Button("Mark the day drink-free") {
                model.delete(entry, ifDayEmpties: .markDrinkFree)
                deleted()
            }
            .accessibilityIdentifier("empty-day-drink-free-button")
            Button("Clear the day", role: .destructive) {
                model.delete(entry, ifDayEmpties: .clear)
                deleted()
            }
            .accessibilityIdentifier("empty-day-clear-button")
            Button("Cancel", role: .cancel) {}
        } message: { _ in
            Text("Was it a drink-free day, or should the day be left unlogged?")
        }
    }
}
