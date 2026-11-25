import SwiftUI
import TippyModeration
import TippyWander

/// The Wander: a vertical trail out from the pond through every area, each
/// with its banner, its landmarks drawn found / next / locked, and the
/// active pet at its position. It opens where she last looked and replays
/// the steps since (a hop each, a curious look, a sparkle and the find card
/// at each landmark). A tap skips to the end. Reduce Motion cross-fades the
/// pet instead; demo mode shows the end state at once.
struct TrailMapView: View {
    @Environment(WanderModel.self) private var wander
    @Environment(JournalModel.self) private var journal
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Per device: the trail position she last saw, so only new steps replay.
    @AppStorage("wander-last-seen-position") private var lastSeenPosition = 0

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

    var body: some View {
        GeometryReader { geometry in
            let layout = TrailLayout(width: geometry.size.width)
            ScrollViewReader { proxy in
                ScrollView {
                    map(layout)
                        .frame(width: layout.width, height: layout.height)
                }
                .accessibilityIdentifier("wander-map")
                .onAppear { start(proxy) }
                .onChange(of: shownStep) { follow(proxy) }
            }
        }
        .overlay(alignment: .bottom) { findCard }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { skip() })
        .navigationTitle("The Wander")
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stop() }
    }

    // MARK: Drawing

    private func map(_ layout: TrailLayout) -> some View {
        ZStack(alignment: .topLeading) {
            backdrop(layout)
            layout.path
                .stroke(Color(red: 0.93, green: 0.86, blue: 0.68).opacity(0.9), style: StrokeStyle(lineWidth: 14, lineCap: .round))
            layout.path
                .stroke(Color(red: 0.55, green: 0.45, blue: 0.30).opacity(0.5), style: StrokeStyle(lineWidth: 2, lineCap: .round, dash: [6, 8]))
            startMarker(layout)
            ForEach(layout.nodes) { node in
                LandmarkNode(
                    landmark: node.landmark,
                    status: status(of: node.landmark),
                    stepsAway: max(node.landmark.step - wander.position, 0),
                    captionOnRight: node.captionOnRight,
                    glows: motion
                )
                .position(node.point)
            }
            if let id = sparkleAt, let node = layout.nodes.first(where: { $0.id == id }), !reduceMotion {
                OneShotSprite(animation: .sparkle, trigger: sparkles)
                    .frame(width: 72, height: 72)
                    .position(x: node.point.x, y: node.point.y - 24)
            }
            if !reduceMotion {
                let feet = layout.point(atStep: shownStep.rounded())
                OneShotSprite(animation: .dustPuff, trigger: landings)
                    .frame(width: 60, height: 60)
                    .position(x: feet.x, y: feet.y - 10)
            }
            // Laid out (not positioned) at the pet's height, so scrollTo
            // finds its real frame.
            VStack(spacing: 0) {
                Color.clear.frame(height: max(layout.point(atStep: shownStep).y - 1, 0))
                Color.clear.frame(height: 2).id("pet-anchor")
            }
            .frame(width: 1)
            .allowsHitTesting(false)
            pet(layout)
        }
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

    private func pet(_ layout: TrailLayout) -> some View {
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
        .accessibilityValue("Step \(Int(shownStep.rounded()))")
        .accessibilityIdentifier("wander-pet")
        .modifier(TrailFollow(step: shownStep, layout: layout))
        // A new identity cross-fades the pet to its place under Reduce Motion.
        .id(fades)
        .transition(.opacity)
    }

    @ViewBuilder
    private var findCard: some View {
        if let revealed {
            FindCard(landmark: revealed, petName: petName) {
                withAnimation { self.revealed = nil }
            }
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func status(of landmark: Landmark) -> LandmarkNode.Status {
        if wander.isFound(landmark) { return .found }
        return landmark.id == wander.nextLandmark?.id ? .next : .locked
    }

    // MARK: Playback

    private func start(_ proxy: ScrollViewProxy) {
        guard !started else { return }
        started = true
        let end = wander.position
        pose = .happy
        guard !UISmokeMode.isActive else {
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

    private func play(from: Int, to end: Int) async {
        try? await Task.sleep(for: .seconds(0.4))
        if reduceMotion {
            withAnimation(.easeInOut(duration: 0.6)) {
                fades += 1
                shownStep = Double(end)
            }
            try? await Task.sleep(for: .seconds(0.6))
            reveal(lastFind(after: from, through: end))
            finish()
            return
        }
        var current = from
        if end - from > 6 {
            // A long way: slide through all but the last three, then hop those.
            current = end - 3
            withAnimation(.easeInOut(duration: 0.9)) { shownStep = Double(current) }
            try? await Task.sleep(for: .seconds(0.9))
        }
        while current < end {
            if Task.isCancelled { return }
            current += 1
            hops += 1
            withAnimation(.linear(duration: 0.35)) { shownStep = Double(current) }
            try? await Task.sleep(for: .seconds(0.35))
            if Task.isCancelled { return }
            landings += 1
            if let landmark = Trail.landmarks.first(where: { $0.step == current }) {
                pose = .waiting
                try? await Task.sleep(for: .seconds(0.6))
                if Task.isCancelled { return }
                sparkleAt = landmark.id
                sparkles += 1
                pose = landmark.isThrilling ? .thriving : .happy
                reveal(landmark)
                try? await Task.sleep(for: .seconds(0.5))
            }
        }
        finish()
    }

    /// A tap anywhere: straight to the end, with the latest find's card.
    private func skip() {
        guard let task = playback else { return }
        task.cancel()
        playback = nil
        let end = wander.position
        var instant = Transaction()
        instant.disablesAnimations = true
        withTransaction(instant) { shownStep = Double(end) }
        pose = .happy
        if revealed == nil { reveal(lastFind(after: replayFrom, through: end)) }
        finish()
    }

    private func finish() {
        playback = nil
        if !UISmokeMode.isActive { lastSeenPosition = wander.position }
        let end = wander.position
        for landmark in Trail.landmarks where landmark.step > replayFrom && landmark.step <= end {
            wander.announceFind(landmark.id)
        }
    }

    /// Leaving mid-replay keeps the rest for next time; finds not shown yet
    /// stay for Home's find card.
    private func stop() {
        playback?.cancel()
        playback = nil
    }

    private func reveal(_ landmark: Landmark?) {
        guard let landmark else { return }
        wander.announceFind(landmark.id)
        withAnimation(.spring(duration: 0.4)) { revealed = landmark }
    }

    private func lastFind(after from: Int, through end: Int) -> Landmark? {
        Trail.landmarks.last { $0.step > from && $0.step <= end && wander.isFound($0) }
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
        guard playback != nil else { return }
        scrollToPet(proxy, animated: true)
    }
}

/// The hop's arc and its squash on landing.
private struct Hop {
    var lift = 0.0
    var scaleX = 1.0
    var scaleY = 1.0
}

/// Places the pet on the trail at a (fractional) step, so an animated step
/// change carries it along the curve rather than straight across.
private struct TrailFollow: ViewModifier, Animatable {
    var step: Double
    let layout: TrailLayout

    var animatableData: Double {
        get { step }
        set { step = newValue }
    }

    func body(content: Content) -> some View {
        content.position(layout.point(atStep: step))
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
