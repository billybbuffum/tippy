import Foundation
import TippyModeration

/// Coins earned once for one fact. A value object: an award is always worth
/// more than nothing, so one with zero or negative coins cannot be made (or read
/// back from a file).
public struct Award: Hashable, Sendable {
    public let key: AwardKey
    /// Always greater than 0.
    public let coins: Int
    /// The day the fact belongs to: the logged day, or the week's last day for a week goal.
    public let earnedOn: LocalDate

    /// Nil unless `coins` is greater than 0.
    public init?(key: AwardKey, coins: Int, earnedOn: LocalDate) {
        guard coins > 0 else { return nil }
        self.key = key
        self.coins = coins
        self.earnedOn = earnedOn
    }
}

extension Award: Codable {
    enum CodingKeys: String, CodingKey {
        case key, coins, earnedOn
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let key = try c.decode(AwardKey.self, forKey: .key)
        let coins = try c.decode(Int.self, forKey: .coins)
        let day = try c.decode(LocalDate.self, forKey: .earnedOn)
        guard let award = Award(key: key, coins: coins, earnedOn: day) else {
            throw DecodingError.dataCorruptedError(
                forKey: .coins, in: c, debugDescription: "An award must be worth more than 0 coins, not \(coins)."
            )
        }
        self = award
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(key, forKey: .key)
        try c.encode(coins, forKey: .coins)
        try c.encode(earnedOn, forKey: .earnedOn)
    }
}
