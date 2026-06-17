/// Aggregate stats from a player's tournament run, fed to scoring.
public struct TournamentStats: Codable, Equatable {
    public var goalsScored: Int
    public var saves: Int
    public var matchesWon: Int
    public var wonTournament: Bool

    public init(goalsScored: Int = 0, saves: Int = 0,
                matchesWon: Int = 0, wonTournament: Bool = false) {
        self.goalsScored = goalsScored
        self.saves = saves
        self.matchesWon = matchesWon
        self.wonTournament = wonTournament
    }
}
