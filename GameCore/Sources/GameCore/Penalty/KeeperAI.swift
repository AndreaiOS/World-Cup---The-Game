/// Chooses the keeper's dive. Stronger keepers read the shot more often.
public enum KeeperAI {
    /// The best keeper reads the shot this fraction of the time.
    static let maxReadChance = 0.75

    public static func dive(strength: Int, against shot: Shot,
                            using rng: inout SeededGenerator) -> KeeperDive {
        let readChance = (Double(strength) / 100.0) * maxReadChance
        if rng.nextUnit() < readChance {
            // Reads it: dive toward where the shot is actually heading.
            let target = shot.aimX + shot.curve * PenaltyEngine.curveFactor
            return KeeperDive(x: min(1.0, max(-1.0, target)))
        }
        // Guesses a random side.
        return KeeperDive(x: rng.nextUnit() * 2 - 1)
    }
}
