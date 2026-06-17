/// Drives one interactive penalty shootout. The player shoots their team's
/// kicks and keeps the opponent's kicks in alternation. Deterministic: owns a
/// single seeded generator shared by the opponent AI and the resolver, so a
/// seed plus the player's inputs fully determine the game.
public final class ShootoutController {
    public enum Turn: Equatable { case playerShoots, playerKeeps }

    public struct State: Equatable {
        public let playerScore: Int
        public let opponentScore: Int
        public let turn: Turn
        public let lastOutcome: PenaltyOutcome?
        public let isOver: Bool
        public let winnerIsPlayer: Bool?
    }

    private let opponentStrength: Int
    private var rng: SeededGenerator
    private var scorer = ShootoutScorer()
    private var turn: Turn = .playerShoots
    private var lastOutcome: PenaltyOutcome?
    public private(set) var playerSaves = 0

    public init(opponentStrength: Int, seed: UInt64) {
        self.opponentStrength = opponentStrength
        self.rng = SeededGenerator(seed: seed)
    }

    public func state() -> State {
        State(playerScore: scorer.homeScored,
              opponentScore: scorer.awayScored,
              turn: turn,
              lastOutcome: lastOutcome,
              isOver: scorer.isDecided,
              winnerIsPlayer: scorer.winner.map { $0 == .home })
    }

    /// The player takes one of their team's kicks against the opponent keeper.
    @discardableResult
    public func playerShoot(_ shot: Shot) -> PenaltyOutcome {
        precondition(turn == .playerShoots && !scorer.isDecided,
                     "not the player's turn to shoot")
        let dive = KeeperAI.dive(strength: opponentStrength, against: shot, using: &rng)
        let outcome = PenaltyEngine.resolve(shot: shot, keeper: dive, using: &rng)
        scorer.record(side: .home, scored: outcome == .goal)
        lastOutcome = outcome
        turn = .playerKeeps
        return outcome
    }

    /// The player keeps one of the opponent's kicks.
    @discardableResult
    public func playerDive(_ dive: KeeperDive) -> PenaltyOutcome {
        precondition(turn == .playerKeeps && !scorer.isDecided,
                     "not the player's turn to keep")
        let shot = ShooterAI.shoot(strength: opponentStrength, using: &rng)
        let outcome = PenaltyEngine.resolve(shot: shot, keeper: dive, using: &rng)
        scorer.record(side: .away, scored: outcome == .goal)
        if outcome == .saved { playerSaves += 1 }
        lastOutcome = outcome
        turn = .playerShoots
        return outcome
    }
}
