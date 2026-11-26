import SwiftUI
import TippyModeration
import TippyRewards

/// The wooden dock along the bottom of Home (spec 06): logging on the first
/// row, the Wander, Pets, Decorate and the shop on the second. In decorate
/// mode it swaps to the shop, a hint and Done.
struct HomeDock: View {
    @Binding var decorating: Bool
    @Binding var placingItem: String?
    let logDrink: () -> Void
    let drinkFree: () -> Void
    let openWander: () -> Void
    let openShop: () -> Void

    @Environment(JournalModel.self) private var model

    var body: some View {
        let u = PixelGrid.uiPoint
        VStack(spacing: 3 * u) {
            if decorating {
                decorateRow
            } else {
                HStack(spacing: 3 * u) {
                    Button(action: logDrink) {
                        HStack(spacing: 3 * u) {
                            PixelIcon.mug
                            Text("Log a drink")
                        }
                    }
                    .buttonStyle(.pixel(.teal))
                    .accessibilityIdentifier("log-drink-button")
                    Button(action: drinkFree) {
                        HStack(spacing: 3 * u) {
                            PixelIcon.leaf
                            Text(model.isTodayDrinkFree ? "Drink-free today" : "No drinks today")
                        }
                    }
                    .buttonStyle(.pixel(.leaf))
                    .disabled(model.isTodayLogged)
                    .accessibilityIdentifier("drink-free-button")
                }
                HStack(spacing: 2 * u) {
                    Button(action: openWander) {
                        dockLabel("Wander", PixelIcon.map)
                    }
                    .buttonStyle(.pixel(.wood, size: 7, font: .labelBold))
                    .accessibilityIdentifier("wander-button")
                    NavigationLink {
                        PetsView()
                    } label: {
                        dockLabel("Pets", PixelIcon.paw)
                    }
                    .buttonStyle(.pixel(.wood, size: 7, font: .labelBold))
                    .accessibilityLabel("Pets")
                    .accessibilityIdentifier("pets-button")
                    Button {
                        withAnimation { decorating = true }
                    } label: {
                        dockLabel("Decor", PixelIcon.brush)
                    }
                    .buttonStyle(.pixel(.wood, size: 7, font: .labelBold))
                    .accessibilityLabel("Decorate")
                    .accessibilityIdentifier("decorate-button")
                    Button(action: openShop) {
                        dockLabel("Shop", PixelIcon.bag)
                    }
                    .buttonStyle(.pixel(.wood, size: 7, font: .labelBold))
                    .accessibilityLabel("Shop")
                    .accessibilityIdentifier("dock-shop-button")
                }
            }
        }
        .padding(.horizontal, 6 * u)
        .padding(.top, 5 * u)
        .padding(.bottom, 3 * u)
        .background(PixelDock().ignoresSafeArea(edges: .bottom))
    }

    /// Icon over a small caps label, so four fit across the narrowest phone.
    private func dockLabel(_ title: String, _ icon: PixelIcon) -> some View {
        VStack(spacing: PixelGrid.uiPoint) {
            icon
            Text(title.uppercased())
        }
    }

    private var decorateRow: some View {
        let u = PixelGrid.uiPoint
        return HStack(spacing: 3 * u) {
            Button(action: openShop) {
                HStack(spacing: 2 * u) {
                    PixelIcon.bag
                    Text("SHOP")
                }
            }
            .buttonStyle(.pixel(.wood, size: 8, font: .labelBold, fill: false))
            .accessibilityLabel("Shop")
            .accessibilityIdentifier("shop-button")
            Text(hint)
                .pixelFont(.body, 10)
                .foregroundStyle(PixelPalette.parchmentLight)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("decorate-hint-label")
            Button("Done") {
                withAnimation {
                    decorating = false
                    placingItem = nil
                }
            }
            .buttonStyle(.pixel(.teal, fill: false))
            .accessibilityIdentifier("decorate-done-button")
        }
        .frame(minHeight: 22 * u)
    }

    private var hint: String {
        if let item = placingItem.flatMap(CampCatalog.item) { return "Tap a spot for the \(item.name.lowercased())" }
        return "Tap a spot to place or move things"
    }
}
