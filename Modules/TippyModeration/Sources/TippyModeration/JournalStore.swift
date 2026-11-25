import Foundation

/// Port (repository): where the journal is kept. The app supplies the adapter (a file in
/// Application Support on the phone, memory in UI tests).
public protocol JournalStore {
    /// Nil when nothing has been saved yet.
    func load() throws -> Journal?
    func save(_ journal: Journal) throws
}
