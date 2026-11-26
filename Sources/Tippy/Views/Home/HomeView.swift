import SwiftUI
import TippyModeration
import TippyRewards
import TippyWander

/// Home is the camp, edge to edge (spec 06): the world fills the screen, the
/// HUD sits on the sky, one-time notices stack under it, the pet speaks in a
/// bubble, and the controls live on the wooden dock. No navigation bar.
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
    /// An item waiting for a spot ("Place it now", or "Move to another spot").
    @State private var placingItem: String?
    @State private var slotSheet: CampSlot?
    @State private var shopAfterSheet = false
    @State private var visiting: VisitorItem?
    /// Whether Home is the screen in front (nothing pushed over it). A plain
    /// box, not observed: flipping it must not re-render Home mid-push.
    @State private var front = FrontFlag()

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                GeometryReader { geometry in
                    world(WorldLayout(size: geometry.size))
                }
                .ignoresSafeArea()
                VStack(alignment: .leading, spacing: 3 * PixelGrid.uiPoint) {
                    HomeHUD(openShop: { showingShop = true }, openSettings: { showingSettings = true })
                    notices
                    Spacer(minLength: 0)
                    if !decorating {
                        signpost
                    }
                }
                .padding(.horizontal, 6 * PixelGrid.uiPoint)
                .padding(.top, 2 * PixelGrid.uiPoint)
                .padding(.bottom, 4 * PixelGrid.uiPoint)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                HomeDock(
                    decorating: $decorating,
                    placingItem: $placingItem,
                    logDrink: { showingLog = true },
                    drinkFree: markDrinkFree,
                    openWander: { showingWander = true },
                    openShop: { showingShop = true }
                )
            }
            .toolbar(.hidden, for: .navigationBar)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("home-screen")
            .onAppear {
                front.isFront = true
                presentHatch()
            }
            .onDisappear { front.isFront = false }
            .modifier(RewardsPresentation(otherSheetShowing: showingLog || showingSettings || showingShop || reflecting != nil || hatching != nil || wander.state.pendingHatch != nil || visiting != nil || wander.unseenVisitorID != nil))
            .navigationDestination(isPresented: $showingWander) { TrailMapView() }
            .sheet(isPresented: $showingLog, onDismiss: presentHatch) { LogDrinkView() }
            .sheet(isPresented: $showingSettings, onDismiss: presentHatch) { SettingsView() }
            .sheet(isPresented: $showingShop, onDismiss: presentHatch) {
                ShopView { itemID in
                    decorating = true
                    placingItem = itemID
                }
            }
            .sheet(item: $slotSheet, onDismiss: {
                if shopAfterSheet {
                    shopAfterSheet = false
                    showingShop = true
                }
            }) { slot in
                SlotSheet(slot: slot, move: { placingItem = $0 }, wantsShop: { shopAfterSheet = true })
            }
            .sheet(item: $reflecting, onDismiss: presentHatch) { item in ReflectionSheet(day: item.day) }
            .fullScreenCover(item: $hatching, onDismiss: presentHatch) { item in HatchView(petID: item.id) }
            .sheet(item: $visiting, onDismiss: visitorDismissed) { item in
                VisitorView(visitorID: item.id, petName: wander.shownPet?.name ?? model.settings.petName)
            }
            .onChange(of: wander.state.pendingHatch) { presentHatch() }
            .onChange(of: wander.unseenVisitorID) { presentHatch() }
        }
    }

    // MARK: The world

    private var sky: SkyTime { SkyTime(hour: model.calendar.component(.hour, from: model.now)) }

    private func world(_ layout: WorldLayout) -> some View {
        let side = layout.pondSide
        return ZStack(alignment: .topLeading) {
            WorldBackdrop(layout: layout, time: sky)
            CampSceneView(
                isDusk: sky != .day,
                decorating: decorating,
                placingKind: placingItem.flatMap(CampCatalog.item)?.kind,
                onTapSlot: tapped,
                scale: .immersive
            ) {
                if let pet = wander.shownPet {
                    PetView(mood: model.mood, species: pet.species)
                        .accessibilityIdentifier("pet-view")
                } else {
                    let hatching = wander.hatchingPet
                    let nest = wander.nest
                    NestView(
                        species: hatching?.species ?? nest?.species ?? .pondling,
                        wiggles: hatching != nil || nest?.checkInsLeft == 1
                    )
                    .accessibilityIdentifier("nest-view")
                }
            } nest: {
                if wander.shownPet != nil, let nest = wander.nest {
                    NestView(species: nest.species, wiggles: nest.checkInsLeft == 1)
                        .accessibilityIdentifier("nest-view")
                }
            }
            .frame(width: side, height: side)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("camp-scene")
            .offset(x: layout.pondOrigin.x, y: layout.pondOrigin.y)
            if !decorating {
                SpeechBubble(text: bubbleText)
                    .fixedSize()
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(todayLine)
                    .accessibilityIdentifier("today-status-label")
                    .position(layout.point(CGPoint(x: 0.5, y: 0.40)))
                if let countdown {
                    // The identifier goes on the text itself: on the panel it
                    // would name a container with an empty label.
                    Text(countdown)
                        .pixelFont(.body, 9)
                        .foregroundStyle(PixelPalette.plum)
                        .accessibilityIdentifier("nest-countdown-label")
                        .pixelPanel(.parchment)
                        .fixedSize()
                        .position(layout.point(wander.shownPet == nil ? CGPoint(x: 0.5, y: 0.97) : CGPoint(x: 0.26, y: 0.92)))
                }
            }
        }
        .frame(width: layout.size.width, height: layout.size.height, alignment: .topLeading)
    }

    /// The signpost to the Wander: how far the next landmark is.
    private var signpost: some View {
        Button { showingWander = true } label: {
            HStack(spacing: 3 * PixelGrid.uiPoint) {
                PixelIcon.flag
                Text(wander.state.nextLandmarkCaption)
            }
        }
        .buttonStyle(.pixel(.wood, size: 10, fill: false))
        .accessibilityLabel(wander.state.nextLandmarkCaption)
        .accessibilityIdentifier("wander-next-label")
    }

    /// One-time notices, in the spec's order, as parchment panels under the HUD.
    @ViewBuilder
    private var notices: some View {
        if let find = wander.unannouncedFinds.first {
            FindCard(landmark: find, petName: wander.shownPet?.name ?? model.settings.petName) {
                withAnimation { wander.announceFind(find.id) }
            }
        }
        if model.shouldOfferReminder {
            ReminderOfferCard()
        }
        NextWeekIdeaCard()
    }

    // MARK: Today

    /// What VoiceOver hears on the bubble, and what the smoke tests read.
    private var todayLine: String {
        if model.isTodayDrinkFree { return "Today is a drink-free day" }
        if model.isTodayLogged { return "Today: \(model.todaysDrinks.drinksText) standard drinks" }
        return "Today isn't logged yet"
    }

    /// The same, in the pet's voice and short enough for the bubble.
    private var bubbleText: String {
        if model.isTodayDrinkFree { return "A drink-free day!" }
        if model.isTodayLogged { return "Today: \(model.todaysDrinks.drinksText) drinks" }
        return "How was today?"
    }

    private var countdown: String? {
        if wander.shownPet == nil {
            return wander.hatchingPet != nil ? "Hatching now!" : wander.nest?.countdownText
        }
        return wander.nest?.countdownText
    }

    private func markDrinkFree() {
        let today = model.today
        if model.markDrinkFree(today), model.journal.reflection(on: today) == nil {
            reflecting = DayItem(day: today)
        }
    }

    // MARK: Decorating

    private func tapped(_ slot: CampSlot) {
        if let item = placingItem {
            if rewards.place(item, in: slot.id) {
                withAnimation { placingItem = nil }
            }
        } else {
            slotSheet = slot
        }
    }

    // MARK: Presentation

    /// The hatch moment, then a visitor found on the Wander, each wait until
    /// Home is in front with nothing else up (a check-in hatches the egg, then
    /// the reflection usually follows), so they play as soon as she's back,
    /// one at a time.
    private func presentHatch() {
        guard front.isFront, hatching == nil, visiting == nil, !showingLog, !showingSettings, !showingShop,
              reflecting == nil else { return }
        if let id = wander.state.pendingHatch {
            hatching = PetItem(id: id)
        } else if let visitor = wander.unseenVisitorID {
            visiting = VisitorItem(id: visitor)
        }
    }

    /// Closing the visitor any way means she's met them.
    private func visitorDismissed() {
        if let visitor = wander.unseenVisitorID { wander.markVisitorSeen(visitor) }
        presentHatch()
    }
}

/// A flag Home sets on appear and disappear without causing a re-render.
final class FrontFlag {
    var isFront = false
}
