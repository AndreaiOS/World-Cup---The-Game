/// Resolves a single penalty in goal-coordinate space.
public enum PenaltyEngine {
    /// Max lateral shift produced by full curve.
    static let curveFactor = 0.25
    /// Max random deviation at full power (risk/reward of power).
    static let maxSpread = 0.35
    /// Half-width the keeper covers around its dive x.
    static let keeperReach = 0.40
    /// Shots above this height beat the keeper (top corners).
    static let keeperVerticalReach = 0.70

    public static func resolve(shot: Shot, keeper: KeeperDive,
                               using rng: inout SeededGenerator) -> PenaltyOutcome {
        // Always consume two draws so RNG sequencing is stable regardless of power.
        let noiseX = (rng.nextUnit() * 2 - 1) * shot.power * maxSpread
        let noiseY = (rng.nextUnit() * 2 - 1) * shot.power * maxSpread

        let landingX = shot.aimX + shot.curve * curveFactor + noiseX
        let landingY = shot.aimY + noiseY

        // Off the frame (wide, over, or into the ground) -> miss.
        if landingX < -1 || landingX > 1 || landingY < 0 || landingY > 1 {
            return .miss
        }
        // Keeper saves if it covers the landing spot horizontally and can reach the height.
        if abs(landingX - keeper.x) <= keeperReach && landingY <= keeperVerticalReach {
            return .saved
        }
        return .goal
    }
}
