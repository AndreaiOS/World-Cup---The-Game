/// The entire persistable tournament state. The player is `home` in every
/// recorded result, so `result.winnerId == playerNationId` means a player win.
public struct TournamentSave: Codable, Equatable {
    public let playerNationId: String
    public let seed: UInt64
    public var playerResults: [MatchResult]

    public init(playerNationId: String, seed: UInt64, playerResults: [MatchResult] = []) {
        self.playerNationId = playerNationId
        self.seed = seed
        self.playerResults = playerResults
    }
}

/// Where the player stands in their run.
public enum TournamentPhase: String, Codable, Equatable {
    case playing
    case eliminated
    case champion
}

/// The derived view the UI renders.
public struct TournamentSnapshot: Equatable {
    public let stage: Stage
    public let phase: TournamentPhase
    /// The next opponent's id when `phase == .playing`, else nil.
    public let opponentId: String?
    public let playerGroupStandings: [GroupStanding]
    public let playerMatchesPlayed: Int

    public init(stage: Stage, phase: TournamentPhase, opponentId: String?,
                playerGroupStandings: [GroupStanding], playerMatchesPlayed: Int) {
        self.stage = stage
        self.phase = phase
        self.opponentId = opponentId
        self.playerGroupStandings = playerGroupStandings
        self.playerMatchesPlayed = playerMatchesPlayed
    }
}
