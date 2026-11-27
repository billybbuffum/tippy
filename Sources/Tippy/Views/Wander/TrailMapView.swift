import SwiftUI
import TippyModeration
import TippyWander

/// The Wander: a vertical trail out from the pond through every area, each
/// with its banner, its landmarks drawn found / next / locked, its forks with
/// their side paths looping out (spec 07), and the active pet where its walk
/// has taken it. It opens where she last looked and replays the steps since
/// (a hop each, a curious look, a sparkle and the find card at each
/// landmark), following the route down side paths and back. A tap skips to
/// the end. When the pet waits at a fork, a card asks which way. Reduce Motion
/// cross-fades the pet instead; demo mode shows the end state at once.
struct TrailMapView: View {
    @Environment(WanderModel.self) private var wander
    @Environment(JournalModel.self) private var journal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Per device: how far along the walk (steps walked) she last saw, so
    /// only new steps replay.
    @AppStorage("wander-last-seen-position") private var lastSeenPosition = 0

    /// The pet's place as a (fractional) index along the walk: 0 is the pond,
    /// n is where the n-th step walked took it.
    @State private var shownStep: Double = 0
    @State private var replayFrom = 0
    @State private var started = false
    @State private var pose: PetMood = .happy
    @State private var hops = 0
    @State private var landings = 0
    @State private var sparkles = 0
    @State private var sparkleAt: String?
    @State private var fades = 0
    @State private var revealed: Landmark?
    @State private var playback: Task<Void, Never>?

    private var motion: Bool { MotionAllowed(reduceMotion: reduceMotion).value }
    private var petName: String { wander.shownPet?.name ?? journal.settings.petName }
    private var walkedPath: [TrailSpot] { wander.state.walkedPath }
    private var replays: Bool { !UISmokeMode.isActive || UISmokeMode.replaysWander }

    var body: some View {
        GeometryReader { geometry in
            let layout = TrailLayout(width: geometry.size.width)
            let route = TrailRoute(layout: layout, path: walkedPath, walk: wander.walk)
            ScrollViewReader { proxy in
                ScrollView {
                    map(layout, route)
                        .frame(width: layout.width, height: layout.height)
                }
                .accessibilityIdentifier("wander-map")
                .onAppear { start(proxy) }
                .onChange(of: shownStep) { follow(proxy) }
                .onChange(of: wander.walk.stepsUsed) { walkedOn(proxy) }
                .onChange(of: wander.walk.spot) { hopped(proxy) }
            }
        }
        .overlay(alignment: .bottom) { bottomCard }
        .overlay(alignment: .topTrailing) {
            if playback != nil {
                Button("Skip") { skip() }
                    .buttonStyle(.pixel(.teal, size: 10, fill: false))
                    .padding()
                    .accessibilityIdentifier("wander-skip-button")
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { skip() })
        .navigationTitle("The Wander")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stop() }
    }

    // MARK: Drawing

    private func map(_ layout: TrailLayout, _ route: TrailRoute) -> some View {
        ZStack(alignment: .topLeading) {
            backdrop(layout)
            ForEach(layout.loops) { loop in
                HabitatScenery(loop: loop)
            }
            ForEach(layout.loops) { loop in
                loop.path
                    .stroke(Color(red: 0.93, green: 0.86, blue: 0.68).opacity(0.8), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                loop.path
                    .stroke(Color(red: 0.55, green: 0.45, blue: 0.30).opacity(0.6), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [3, 6]))
            }
            layout.path
                .stroke(Color(red: 0.93, green: 0.86, blue: 0.68).opacity(0.9), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            layout.path
                .stroke(Color(red: 0.55, green: 0.45, blue: 0.30).opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 8]))
            startMarker(layout)
            ForEach(layout.loops) { loop in
                ForkSign(
                    fork: loop.fork,
                    open: canRevisit(loop.fork),
                    revisit: { revisit(loop.fork) }
                )
                .position(loop.signpost)
                ForEach(loop.nodes) { node in
                    SideNode(landmark: node.landmark, status: status(of: node.landmark))
                        .position(node.point)
                }
            }
            ForEach(layout.nodes) { node in
                LandmarkNode(
                    landmark: node.landmark,
                    status: status(of: node.landmark),
                    stepsAway: max(node.landmark.step - wander.walk.mainStep, 0),
                    captionOnRight: node.captionOnRight,
                    glows: motion
                )
                .position(node.point)
            }
            if let id = sparkleAt, let point = point(ofLandmark: id, in: layout), !reduceMotion {
                OneShotSprite(animation: .sparkle, trigger: sparkles)
                    .frame(width: 72, height: 72)
                    .position(x: point.x, y: point.y - 24)
            }
            if !reduceMotion {
                let feet = route.point(at: shownStep.rounded())
                OneShotSprite(animation: .dustPuff, trigger: landings)
                    .frame(width: 60, height: 60)
                    .position(x: feet.x, y: feet.y - 10)
            }
            // Laid out (not positioned) at the pet's height, so scrollTo
            // finds its real frame.
            VStack(spacing: 0) {
                Color.clear.frame(height: max(route.point(at: shownStep).y - 1, 0))
                Color.clear.frame(height: 2).id("pet-anchor")
            }
            .frame(width: 1)
            .allowsHitTesting(false)
            pet(route)
        }
    }

    private func point(ofLandmark id: String, in layout: TrailLayout) -> CGPoint? {
        if let node = layout.nodes.first(where: { $0.id == id }) { return node.point }
        for loop in layout.loops {
            if let node = loop.nodes.first(where: { $0.landmark.id == id }) { return node.point }
        }
        return nil
    }

    private func backdrop(_ layout: TrailLayout) -> some View {
        VStack(spacing: 0) {
            ZStack {
                Color(red: 0.64, green: 0.68, blue: 0.44)
                Ellipse()
                    .fill(Color(red: 0.34, green: 0.62, blue: 0.60))
                    .frame(width: layout.width * 0.5, height: 56)
                    .offset(y: -6)
            }
            .frame(height: TrailLayout.startHeight)
            ForEach(layout.sections) { section in
                VStack(spacing: 0) {
                    AreaBanner(area: section.area)
                        .frame(width: layout.width, height: layout.bannerHeight)
                    section.area.groundColor
                        .frame(height: max(section.height - layout.bannerHeight, 0))
                }
                .frame(height: section.height, alignment: .top)
            }
            Color(red: 0.72, green: 0.72, blue: 0.47)
        }
        .frame(width: layout.width, height: layout.height, alignment: .top)
        .accessibilityHidden(true)
    }

    private func startMarker(_ layout: TrailLayout) -> some View {
        Text("The pond")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(.thinMaterial, in: Capsule())
            .position(x: layout.start.x, y: layout.start.y + 44)
    }

    private func pet(_ route: TrailRoute) -> some View {
        Group {
            if let shown = wander.shownPet {
                PetSprite(pose: pose, species: shown.species)
            } else {
                EggView(species: wander.hatchingPet?.species ?? wander.nest?.species ?? .pondling, wiggles: false)
            }
        }
        .frame(width: 64, height: 64)
        .keyframeAnimator(initialValue: Hop(), trigger: hops) { content, hop in
            content
                .scaleEffect(x: hop.scaleX, y: hop.scaleY, anchor: .bottom)
                .offset(y: hop.lift)
        } keyframes: { _ in
            KeyframeTrack(\.lift) {
                CubicKeyframe(-18, duration: 0.17)
                CubicKeyframe(0, duration: 0.18)
            }
            KeyframeTrack(\.scaleX) {
                LinearKeyframe(1.0, duration: 0.33)
                LinearKeyframe(1.1, duration: 0.05)
                CubicKeyframe(1.0, duration: 0.12)
            }
            KeyframeTrack(\.scaleY) {
                LinearKeyframe(1.0, duration: 0.33)
                LinearKeyframe(0.9, duration: 0.05)
                CubicKeyframe(1.0, duration: 0.12)
            }
        }
        // The pet stands on the stone, not over it.
        .offset(y: -26)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(petName)
        .accessibilityValue(placeDescription(route.spot(at: Int(shownStep.rounded()))))
        .accessibilityIdentifier("wander-pet")
        .modifier(TrailFollow(index: shownStep, route: route))
        // A new identity cross-fades the pet to its place under Reduce Motion.
        .id(fades)
        .transition(.opacity)
    }

    /// "Step 9", "Step 11, at the Heron's Inlet fork", "Heron's Inlet, step 2 of 5".
    private func placeDescription(_ spot: TrailSpot) -> String {
        switch spot {
        case .main(let step):
            if let fork = wander.walk.waitingAt, fork.mainStep == step {
                return "Step \(step), at the \(fork.sidePath.name) fork"
            }
            return "Step \(step)"
        case .side(let forkID, let step):
            guard let fork = Trail.fork(id: forkID) else { return "Step \(step)" }
            return "\(fork.sidePath.name), step \(step) of \(fork.sidePath.length)"
        }
    }

    /// The find card while one is showing; otherwise, when the pet waits at a
    /// fork and nothing is playing, the card asking which way.
    @ViewBuilder
    private var bottomCard: some View {
        if let revealed {
            FindCard(landmark: revealed, petName: petName) {
                withAnimation { self.revealed = nil }
            }
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else if playback == nil, let fork = wander.walk.waitingAt {
            ForkCard(fork: fork, petName: petName, savedSteps: wander.walk.savedSteps) { explore in
                withAnimation { _ = wander.choose(at: fork.id, explore: explore, today: journal.today) }
            }
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func status(of landmark: Landmark) -> LandmarkNode.Status {
        if wander.isFound(landmark) { return .found }
        return landmark.id == wander.nextLandmark?.id ? .next : .locked
    }

    private func canRevisit(_ fork: Fork) -> Bool {
        wander.walk.excursion == nil && wander.walk.openForks.contains { $0.id == fork.id }
    }

    private func revisit(_ fork: Fork) {
        skip()
        _ = wander.revisit(fork.id, today: journal.today)
    }

    // MARK: Playback

    private func start(_ proxy: ScrollViewProxy) {
        guard !started else { return }
        started = true
        let end = wander.walk.stepsUsed
        pose = .happy
        guard replays else {
            // Demo mode: the end state at once, so scenarios stay fast.
            shownStep = Double(end)
            scrollToPet(proxy, animated: false)
            return
        }
        let from = min(max(lastSeenPosition, 0), end)
        replayFrom = from
        shownStep = Double(from)
        scrollToPet(proxy, animated: false)
        guard from < end else {
            lastSeenPosition = end
            return
        }
        playback = Task { @MainActor in await play(from: from, to: end) }
    }

    /// A choice at a fork (or a revisit using saved steps) walked on while the
    /// map is open: replay the new steps from where the pet stands.
    private func walkedOn(_ proxy: ScrollViewProxy) {
        guard started else { return }
        let end = wander.walk.stepsUsed
        let from = min(Int(shownStep.rounded()), end)
        guard replays, playback == nil, from < end else {
            playback?.cancel()
            playback = nil
            var instant = Transaction()
            instant.disablesAnimations = true
            withTransaction(instant) { shownStep = Double(end) }
            if replays { lastSeenPosition = end }
            scrollToPet(proxy, animated: false)
            return
        }
        replayFrom = from
        playback = Task { @MainActor in await play(from: from, to: end) }
    }

    /// A revisit with no saved steps moves the pet to the fork without a step.
    private func hopped(_ proxy: ScrollViewProxy) {
        guard started, playback == nil else { return }
        withAnimation(.easeInOut(duration: 0.4)) { fades += 1 }
        scrollToPet(proxy, animated: motion)
    }

    private func play(from: Int, to end: Int) async {
        do {
            try await Task.sleep(for: .seconds(0.4))
            if reduceMotion {
                withAnimation(.easeInOut(duration: 0.6)) {
                    fades += 1
                    shownStep = Double(end)
                }
                try await Task.sleep(for: .seconds(0.6))
                reveal(lastFind(after: from, through: end))
                finish()
                return
            }
            var current = from
            if end - from > 6 {
                // A long way: slide through all but the last three, then hop those.
                current = end - 3
                withAnimation(.easeInOut(duration: 0.9)) { shownStep = Double(current) }
                try await Task.sleep(for: .seconds(0.9))
            }
            while current < end {
                if Task.isCancelled { return }
                current += 1
                hops += 1
                withAnimation(.linear(duration: 0.35)) { shownStep = Double(current) }
                try await Task.sleep(for: .seconds(0.35))
                if Task.isCancelled { return }
                landings += 1
                if let landmark = landmark(atIndex: current) {
                    pose = .waiting
                    try await Task.sleep(for: .seconds(0.6))
                    if Task.isCancelled { return }
                    sparkleAt = landmark.id
                    sparkles += 1
                    pose = landmark.isThrilling ? .thriving : .happy
                    reveal(landmark)
                    try await Task.sleep(for: .seconds(0.5))
                }
            }
            finish()
        } catch {
            // Cancellation ends playback before any more position or find changes.
            return
        }
    }

    /// The landmark where the `index`-th step walked landed, if any.
    private func landmark(atIndex index: Int) -> Landmark? {
        let path = walkedPath
        guard index >= 1, index <= path.count else { return nil }
        return Trail.landmark(at: path[index - 1])
    }

    /// A tap anywhere: straight to the end, with the latest find's card.
    private func skip() {
        guard let task = playback else { return }
        task.cancel()
        playback = nil
        let end = wander.walk.stepsUsed
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { shownStep = Double(end) }
        pose = .happy
        if revealed == nil { reveal(lastFind(after: replayFrom, through: end)) }
        finish()
    }

    private func finish() {
        playback = nil
        if replays {
            lastSeenPosition = wander.walk.stepsUsed
        }
        // Finds skipped during a long replay remain on Home until actually shown.
    }

    /// Leaving mid-replay keeps the rest for next time; finds not shown yet
    /// stay for Home's find card.
    private func stop() {
        playback?.cancel()
        playback = nil
    }

    private func reveal(_ landmark: Landmark?) {
        guard let landmark,
              wander.unannouncedFinds.contains(where: { $0.id == landmark.id }) else { return }
        wander.announceFind(landmark.id)
        withAnimation(.spring(duration: 0.4)) { revealed = landmark }
    }

    /// The latest unannounced find among the steps walked in (from, end].
    private func lastFind(after from: Int, through end: Int) -> Landmark? {
        let path = walkedPath
        let lower = max(from, 0)
        let upper = min(end, path.count)
        guard lower < upper else { return nil }
        let reached = Set(path[lower..<upper].compactMap { Trail.landmark(at: $0)?.id })
        return wander.unannouncedFinds.last { reached.contains($0.id) }
    }

    private func scrollToPet(_ proxy: ScrollViewProxy, animated: Bool) {
        Task { @MainActor in
            if animated {
                withAnimation(.easeInOut(duration: 0.35)) { proxy.scrollTo("pet-anchor", anchor: .center) }
            } else {
                proxy.scrollTo("pet-anchor", anchor: .center)
            }
        }
    }

    private func follow(_ proxy: ScrollViewProxy) {
        guard started else { return }
        // A skip clears playback before updating the step. Its final anchor must
        // still be followed, immediately, even though there is no task left.
        scrollToPet(proxy, animated: motion && playback != nil)
    }
}

/// The hop's arc and its squash on landing.
private struct Hop {
    var lift = 0.0
    var scaleX = 1.0
    var scaleY = 1.0
}

/// Places the pet along its walk at a (fractional) index, so an animated
/// change carries it along the curve, round a side path's loop, or hops it.
private struct TrailFollow: ViewModifier, Animatable {
    var index: Double
    let route: TrailRoute

    var animatableData: Double {
        get { index }
        set { index = newValue }
    }

    func body(content: Content) -> some View {
        content.position(route.point(at: index))
    }
}

/// A fork's signpost, beside the fork: the side path's name and habitat
/// and, while it's open to explore, a button to send the pet down it.
struct ForkSign: View {
    let fork: Fork
    let open: Bool
    let revisit: () -> Void

    var body: some View {
        let u = PixelGrid.uiPoint
        VStack(spacing: 2 * u) {
            VStack(spacing: 0) {
                Text(fork.sidePath.name)
                    .pixelFont(.body, 9)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text(fork.sidePath.habitat.uppercased())
                    .pixelFont(.labelBold, 6)
                    .opacity(0.85)
            }
            .foregroundStyle(PixelPalette.parchmentLight)
            .pixelPanel(.wood)
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isHeader)
            if open {
                Button("Explore", action: revisit)
                    .buttonStyle(.pixel(.teal, size: 8, fill: false))
                    .accessibilityLabel("Explore \(fork.sidePath.name)")
                    .accessibilityIdentifier("revisit-\(fork.id)-button")
            }
        }
        .frame(maxWidth: 130)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fork-\(fork.id)")
    }
}

/// A landmark on a side path: a smaller stone, with its find's icon once found.
struct SideNode: View {
    let landmark: Landmark
    let status: LandmarkNode.Status

    var body: some View {
        ZStack {
            Circle()
                .fill(status == .found ? PixelPalette.leaf : (status == .next ? PixelPalette.gold : PixelPalette.parchmentShade))
                .overlay(Circle().stroke(PixelPalette.plum, lineWidth: 2))
                .frame(width: 22, height: 22)
            if status == .found {
                FindIcon(content: landmark.content)
                    .frame(width: 20, height: 20)
                    .offset(x: 12, y: -12)
            }
        }
        .frame(width: 36, height: 36)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status == .found ? landmark.name : "A spot on the side path")
        .accessibilityValue(status.rawValue)
        .accessibilityIdentifier("landmark-\(landmark.id)")
    }
}

/// "Which way?": the pet waits at a fork until she picks, with the steps
/// saved meanwhile shown, so nothing feels lost.
struct ForkCard: View {
    let fork: Fork
    let petName: String
    let savedSteps: Int
    let choose: (Bool) -> Void

    var body: some View {
        let u = PixelGrid.uiPoint
        VStack(alignment: .leading, spacing: 3 * u) {
            Text("Which way?")
                .pixelFont(.body, 13)
                .accessibilityAddTraits(.isHeader)
            Text("\(fork.sidePath.name.uppercased()) · \(fork.sidePath.habitat.uppercased())")
                .pixelFont(.labelBold, 7)
                .foregroundStyle(PixelPalette.tealDark)
            Text("\(petName) is at the signpost. \(fork.sidePath.hint)")
                .pixelFont(.body, 10)
                .fixedSize(horizontal: false, vertical: true)
            if savedSteps > 0 {
                Text(savedSteps == 1 ? "1 step saved for the way you pick" : "\(savedSteps) steps saved for the way you pick")
                    .pixelFont(.body, 9)
                    .foregroundStyle(PixelPalette.tealDark)
                    .accessibilityIdentifier("fork-saved-label")
            }
            Button("Explore \(fork.sidePath.name) · \(fork.sidePath.length) steps") { choose(true) }
                .buttonStyle(.pixel(.teal, size: 10))
                .accessibilityIdentifier("fork-explore-button")
            Button("Stay on the trail") { choose(false) }
                .buttonStyle(.pixel(.wood, size: 10))
                .accessibilityIdentifier("fork-stay-button")
        }
        .foregroundStyle(PixelPalette.plum)
        .pixelPanel(.parchment)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("fork-card")
    }
}

/// One landmark on the map: its stone (found, next with a glow, or locked),
/// the find's icon once found, and a short caption.
struct LandmarkNode: View {
    enum Status: String {
        case found
        case next
        case locked
    }

    let landmark: Landmark
    let status: Status
    let stepsAway: Int
    let captionOnRight: Bool
    /// The next node's glow loops only when motion is allowed.
    let glows: Bool

    var body: some View {
        ZStack {
            if status == .next { glow }
            stone
            if status == .found {
                FindIcon(content: landmark.content)
                    .frame(width: 26, height: 26)
                    .offset(x: 18, y: -18)
            }
            Text(caption)
                .font(.caption2.weight(.semibold))
                .lineLimit(2)
                .multilineTextAlignment(captionOnRight ? .leading : .trailing)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
                .frame(width: 130, alignment: captionOnRight ? .leading : .trailing)
                .offset(x: captionOnRight ? 98 : -98)
        }
        .frame(width: 56, height: 56)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(status == .found ? landmark.name : caption)
        .accessibilityValue(status.rawValue)
        .accessibilityIdentifier("landmark-\(landmark.id)")
    }

    private var caption: String {
        switch status {
        case .found: return landmark.name
        case .next: return stepsAway == 1 ? "Next: 1 step" : "Next: \(stepsAway) steps"
        case .locked: return "Step \(landmark.step)"
        }
    }

    @ViewBuilder
    private var stone: some View {
        let path = "Wander/node-\(status.rawValue)"
        if SpriteLibrary.image(path) != nil {
            SpriteImage(path: path).frame(width: 48, height: 48)
        } else {
            Circle()
                .fill(status == .locked ? Color.gray : (status == .next ? Color.orange : Color.green))
                .frame(width: 36, height: 36)
        }
    }

    @ViewBuilder
    private var glow: some View {
        if glows {
            AnimatedSprite(animation: .findGlow)
                .frame(width: 84, height: 84)
                .offset(y: 10)
        } else if let still = SpriteLibrary.frames(of: .findGlow).first {
            Image(decorative: still, scale: 1)
                .interpolation(.none)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 84, height: 84)
                .offset(y: 10)
        }
    }
}

/// An area's banner with its name, or a coloured stand-in without the art.
struct AreaBanner: View {
    let area: Area

    var body: some View {
        ZStack(alignment: .topLeading) {
            if SpriteLibrary.image("Wander/area-\(area.id)") != nil {
                SpriteImage(path: "Wander/area-\(area.id)")
            } else {
                area.groundColor
            }
            Text(area.name)
                .font(.headline)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(.thinMaterial, in: Capsule())
                .padding(10)
                .accessibilityAddTraits(.isHeader)
        }
    }
}

extension Area {
    /// The ground below the banner, matched to the banner's foreground.
    var groundColor: Color {
        switch id {
        case "pond-shore": return Color(red: 0.64, green: 0.68, blue: 0.44)
        case "reed-bed": return Color(red: 0.60, green: 0.66, blue: 0.42)
        case "willow-grove": return Color(red: 0.56, green: 0.65, blue: 0.42)
        case "mossy-woods": return Color(red: 0.44, green: 0.53, blue: 0.36)
        case "mushroom-glade": return Color(red: 0.62, green: 0.63, blue: 0.42)
        default: return Color(red: 0.72, green: 0.72, blue: 0.47)
        }
    }
}
