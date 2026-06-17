/// A single knockout pairing.
public struct BracketMatch: Codable, Equatable {
    public let homeId: String
    public let awayId: String

    public init(homeId: String, awayId: String) {
        self.homeId = homeId
        self.awayId = awayId
    }
}
