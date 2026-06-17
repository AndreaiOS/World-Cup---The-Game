/// Simulates a penalty shootout between two nations. Used for every match the
/// player does not play in person. Strength biases conversion. The returned
/// MatchResult is always non-tie, upholding the shootout invariant.
public enum MatchSimulator {

    private static func conversionProbability(strength: Int) -> Double {
        0.55 + 0.40 * (Double(strength) / 100.0)
    }

    private static func kicks(count: Int, strength: Int,
                              using rng: inout SeededGenerator) -> Int {
        let p = conversionProbability(strength: strength)
        var made = 0
        for _ in 0..<count where rng.nextUnit() < p { made += 1 }
        return made
    }

    public static func simulate(home: Nation, away: Nation,
                                using rng: inout SeededGenerator) -> MatchResult {
        var homeScore = kicks(count: 5, strength: home.strength, using: &rng)
        var awayScore = kicks(count: 5, strength: away.strength, using: &rng)

        let homeP = conversionProbability(strength: home.strength)
        let awayP = conversionProbability(strength: away.strength)

        var rounds = 0
        while homeScore == awayScore && rounds < 50 {
            let homeMade = rng.nextUnit() < homeP
            let awayMade = rng.nextUnit() < awayP
            if homeMade { homeScore += 1 }
            if awayMade { awayScore += 1 }
            rounds += 1
        }

        if homeScore == awayScore {
            // Vanishingly unlikely: decide deterministically, never a tie.
            if home.strength >= away.strength { homeScore += 1 } else { awayScore += 1 }
        }

        return MatchResult(homeId: home.id, awayId: away.id,
                           homeScore: homeScore, awayScore: awayScore)
    }
}
