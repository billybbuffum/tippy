import Foundation

/// What a sync produced, so the app can celebrate it once.
public struct WanderEvents: Equatable, Sendable {
    public var newSteps: Int
    /// In trail order.
    public var newlyFound: [Landmark]
    public var hatched: [Pet]

    public init(newSteps: Int = 0, newlyFound: [Landmark] = [], hatched: [Pet] = []) {
        self.newSteps = newSteps
        self.newlyFound = newlyFound
        self.hatched = hatched
    }

    public var isEmpty: Bool { newSteps == 0 && newlyFound.isEmpty && hatched.isEmpty }
}
