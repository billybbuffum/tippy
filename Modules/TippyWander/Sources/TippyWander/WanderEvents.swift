import Foundation

/// What a sync produced, so the app can celebrate it once.
public struct WanderEvents: Equatable, Sendable {
    public var newSteps: Int
    /// In trail order.
    public var newlyFound: [Landmark]
    public var hatched: [Pet]
    /// The pet just started waiting at this fork for her choice (spec 07).
    public var reachedFork: Fork?
    /// The pet just came back from this side path.
    public var excursionDone: Fork?

    public init(
        newSteps: Int = 0,
        newlyFound: [Landmark] = [],
        hatched: [Pet] = [],
        reachedFork: Fork? = nil,
        excursionDone: Fork? = nil
    ) {
        self.newSteps = newSteps
        self.newlyFound = newlyFound
        self.hatched = hatched
        self.reachedFork = reachedFork
        self.excursionDone = excursionDone
    }

    public var isEmpty: Bool {
        newSteps == 0 && newlyFound.isEmpty && hatched.isEmpty && reachedFork == nil && excursionDone == nil
    }
}
