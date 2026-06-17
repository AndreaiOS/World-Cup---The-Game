/// The entire persistable tournament state. The player is `home` in every
/// recorded result, so `result.winnerId == playerNationId` means a player win.
/// `playerSaves[i]` is how many saves the player made in match `i`.
public struct TournamentSave: Codable, Equatable {
    public let playerNationId: String
    public let seed: UInt64
    public var playerResults: [MatchResult]
    public var playerSaves: [Int]

    public init(playerNationId: String, seed: UInt64,
                playerResults: [MatchResult] = [], playerSaves: [Int] = []) {
        self.playerNationId = playerNationId
        self.seed = seed
        self.playerResults = playerResults
        self.playerSaves = playerSaves
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        playerNationId = try c.decode(String.self, forKey: .playerNationId)
        seed = try c.decode(UInt64.self, forKey: .seed)
        playerResults = try c.decode([MatchResult].self, forKey: .playerResults)
        // Tolerant: saves were added in v1.1; older saves lack the key.
        playerSaves = try c.decodeIfPresent([Int].self, forKey: .playerSaves) ?? []
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
