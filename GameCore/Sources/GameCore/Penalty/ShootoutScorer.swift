/// Tracks an interactive penalty shootout and decides the winner.
/// Five regulation kicks per side, then sudden-death pairs. Decided once both
/// sides have taken the same number of kicks (>= 5) and the scores differ.
public struct ShootoutScorer: Equatable {
    public enum Side { case home, away }

    public private(set) var homeScored = 0
    public private(set) var awayScored = 0
    public private(set) var homeTaken = 0
    public private(set) var awayTaken = 0

    /// Number of regulation kicks each side takes before sudden death.
    public static let regulationKicks = 5

    public init() {}

    public mutating func record(side: Side, scored: Bool) {
        switch side {
        case .home:
            homeTaken += 1
            if scored { homeScored += 1 }
        case .away:
            awayTaken += 1
            if scored { awayScored += 1 }
        }
    }

    public var isDecided: Bool {
        homeTaken == awayTaken
            && homeTaken >= Self.regulationKicks
            && homeScored != awayScored
    }

    public var winner: Side? {
        guard isDecided else { return nil }
        return homeScored > awayScored ? .home : .away
    }
}
