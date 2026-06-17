/// Chooses the opponent's penalty when the player is the keeper.
/// Stronger shooters place wider and higher with controlled power.
public enum ShooterAI {
    public static func shoot(strength: Int, using rng: inout SeededGenerator) -> Shot {
        let skill = Double(strength) / 100.0
        let side: Double = rng.nextUnit() < 0.5 ? -1.0 : 1.0
        // Placement away from center grows with skill (0 = center, ~0.6 = corner).
        let placement = (0.45 + 0.15 * rng.nextUnit()) * skill
        let aimX = min(1.0, max(-1.0, side * placement))
        let aimY = min(1.0, max(0.0, 0.3 + 0.4 * skill))
        // Lower power = less spread; weak shooters are slightly wilder.
        let power = min(1.0, max(0.0, 0.3 + 0.3 * skill))
        return Shot(aimX: aimX, aimY: aimY, power: power, curve: 0)
    }
}
