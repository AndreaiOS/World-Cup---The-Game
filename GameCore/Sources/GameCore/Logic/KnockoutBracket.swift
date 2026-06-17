/// Builds and advances the single-elimination knockout bracket.
///
/// Seeding note: the official FIFA Round-of-32 slotting table is replaced by a
/// deterministic seeded bracket. All 32 qualifiers are ranked (winners above
/// runners-up above thirds; then points, goal difference, goals for, id) and
/// paired seed 1 vs 32, 2 vs 31, … so stronger finishers meet later.
public enum KnockoutBracket {

    public static func buildRoundOf32(from qualifiers: [Qualifier]) -> [BracketMatch] {
        let seeded = qualifiers.sorted { lhs, rhs in
            if lhs.position != rhs.position { return lhs.position < rhs.position }
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.goalDifference != rhs.goalDifference {
                return lhs.goalDifference > rhs.goalDifference
            }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.nationId < rhs.nationId
        }

        let count = seeded.count
        var matches: [BracketMatch] = []
        for i in 0..<(count / 2) {
            matches.append(BracketMatch(homeId: seeded[i].nationId,
                                        awayId: seeded[count - 1 - i].nationId))
        }
        return matches
    }

    /// Pair the winners of consecutive matches into the next round.
    /// `results[i]` must correspond to `matches[i]`.
    public static func nextRound(from matches: [BracketMatch],
                                 results: [MatchResult]) -> [BracketMatch] {
        let winners = results.map { $0.winnerId }
        var next: [BracketMatch] = []
        var i = 0
        while i + 1 < winners.count {
            next.append(BracketMatch(homeId: winners[i], awayId: winners[i + 1]))
            i += 2
        }
        return next
    }
}
