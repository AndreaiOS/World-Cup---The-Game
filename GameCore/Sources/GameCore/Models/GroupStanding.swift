/// One nation's record within a group. Shootouts never tie, so there are
/// no draws: points are simply wins * 3.
public struct GroupStanding: Equatable {
    public let nationId: String
    public var played: Int
    public var wins: Int
    public var losses: Int
    public var goalsFor: Int
    public var goalsAgainst: Int

    public init(nationId: String, played: Int = 0, wins: Int = 0, losses: Int = 0,
                goalsFor: Int = 0, goalsAgainst: Int = 0) {
        self.nationId = nationId
        self.played = played
        self.wins = wins
        self.losses = losses
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
    }

    public var points: Int { wins * 3 }
    public var goalDifference: Int { goalsFor - goalsAgainst }
}
