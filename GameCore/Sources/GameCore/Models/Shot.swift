/// A penalty shot in goal-coordinate space.
/// `aimX` −1 (left post) … 1 (right post); `aimY` 0 (ground) … 1 (crossbar);
/// `power` 0 … 1 (more power = more spread); `curve` −1 … 1 lateral bend.
public struct Shot: Equatable {
    public let aimX: Double
    public let aimY: Double
    public let power: Double
    public let curve: Double

    public init(aimX: Double, aimY: Double, power: Double, curve: Double) {
        self.aimX = aimX
        self.aimY = aimY
        self.power = power
        self.curve = curve
    }
}
