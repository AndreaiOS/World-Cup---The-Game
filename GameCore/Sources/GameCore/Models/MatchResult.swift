/// Outcome of one played penalty shootout. Shootouts never tie:
/// the engine that produces a MatchResult guarantees unequal scores.
public struct MatchResult: Codable, Equatable {
    public let homeId: String
    public let awayId: String
    public let homeScore: Int
    public let awayScore: Int

    public init(homeId: String, awayId: String, homeScore: Int, awayScore: Int) {
        self.homeId = homeId
        self.awayId = awayId
        self.homeScore = homeScore
        self.awayScore = awayScore
    }

    public var winnerId: String { homeScore >= awayScore ? homeId : awayId }
    public var loserId: String { homeScore >= awayScore ? awayId : homeId }
}
