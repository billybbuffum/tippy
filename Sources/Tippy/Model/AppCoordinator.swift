import Foundation
import TippyModeration
import TippyRewards
import TippyWander

/// Wires the contexts together (docs/specs/README.md, contract 4). It holds no
/// state of its own. Every journal change syncs Rewards and the Wander, then
/// replays every find the Wander has made into Rewards (as does a choice at a
/// fork on the Wander, which can walk saved steps at once): a decoration becomes a
/// grant (`find:<landmark>`), a coin pouch an award (`pouch:<landmark>`). Both are
/// once per key, so replaying on every sync is harmless, and finds made before
/// the shop existed reach it the first time this runs.
@MainActor
enum AppCoordinator {
    static func wire(journal: JournalModel, rewards: RewardsModel, wander: WanderModel) {
        journal.onJournalChange { journal, today in
            rewards.sync(journal: journal, today: today)
            wander.sync(journal: journal, today: today)
            forwardFinds(from: wander, to: rewards, today: today)
        }
        // A choice at a fork walks saved steps at once (spec 07).
        wander.onFindsChanged { [weak journal, weak wander, weak rewards] in
            guard let journal, let wander, let rewards else { return }
            forwardFinds(from: wander, to: rewards, today: journal.today)
        }
    }

    static func forwardFinds(from wander: WanderModel, to rewards: RewardsModel, today: LocalDate) {
        for landmark in wander.state.foundLandmarks {
            let day = wander.state.found[landmark.id] ?? today
            switch landmark.content {
            case .decoration(let itemID):
                rewards.grant(itemID: itemID, key: .find(landmark.id))
            case .pouch(let coins):
                rewards.award(coins: coins, key: .pouch(landmark.id), on: day)
            case .egg, .visitor, .scenery:
                break
            }
        }
    }
}
