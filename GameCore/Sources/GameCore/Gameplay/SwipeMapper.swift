/// Translates a normalized swipe into engine inputs. The scene normalizes raw
/// touch points (displacement / view size, flick speed) before calling this.
public enum SwipeMapper {
    /// Attacking: horizontal drag = aim X, upward drag = aim height,
    /// flick speed = power, path bend = curve.
    public static func shot(dx: Double, dy: Double, speed: Double, curve: Double) -> Shot {
        Shot(aimX: clampSigned(dx),
             aimY: clampUnit(dy),
             power: clampUnit(speed),
             curve: clampSigned(curve))
    }

    /// Defending: only the horizontal drag matters — it picks the dive side.
    public static func dive(dx: Double) -> KeeperDive {
        KeeperDive(x: clampSigned(dx))
    }

    private static func clampSigned(_ v: Double) -> Double { min(1.0, max(-1.0, v)) }
    private static func clampUnit(_ v: Double) -> Double { min(1.0, max(0.0, v)) }
}
