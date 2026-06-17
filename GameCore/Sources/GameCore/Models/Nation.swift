/// A national team competing in the tournament.
public struct Nation: Codable, Identifiable, Equatable, Hashable {
    /// Stable ISO-style code, e.g. "ITA". Used as identity.
    public let id: String
    public let name: String
    /// Flag emoji used for lightweight display.
    public let flag: String
    /// Relative strength 1-100, drives keeper AI and match simulation.
    public let strength: Int

    public init(id: String, name: String, flag: String, strength: Int) {
        self.id = id
        self.name = name
        self.flag = flag
        self.strength = strength
    }
}
