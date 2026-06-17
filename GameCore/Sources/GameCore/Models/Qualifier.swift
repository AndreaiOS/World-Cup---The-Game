/// A nation that advanced from the group stage, carrying the stats used to
/// seed the knockout bracket.
public struct Qualifier: Equatable {
    public let nationId: String
    public let groupId: String
    public let position: Int        // 1, 2, or 3 within its group
    public let points: Int
    public let goalDifference: Int
    public let goalsFor: Int

    public init(nationId: String, groupId: String, position: Int,
                points: Int, goalDifference: Int, goalsFor: Int) {
        self.nationId = nationId
        self.groupId = groupId
        self.position = position
        self.points = points
        self.goalDifference = goalDifference
        self.goalsFor = goalsFor
    }
}
