/// Deterministic tournament orchestration over the bundled dataset.
public enum TournamentEngine {

    /// The group the player's nation belongs to.
    public static func playerGroup(in groups: [Group], playerId: String) -> Group {
        guard let g = groups.first(where: { $0.nationIds.contains(playerId) }) else {
            preconditionFailure("nation \(playerId) is not in any group")
        }
        return g
    }

    /// The player's three group opponents, in group order.
    public static func groupOpponents(group: Group, playerId: String) -> [String] {
        group.nationIds.filter { $0 != playerId }
    }
}
