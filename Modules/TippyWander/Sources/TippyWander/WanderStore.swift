import Foundation

/// Port (repository): where the Wander is kept. The app supplies the adapter
/// (`wander.json` in Application Support on the phone, memory in UI tests).
public protocol WanderStore {
    /// Nil when nothing has been saved yet (the app then starts a new Wander).
    func load() throws -> WanderState?
    func save(_ state: WanderState) throws
}
