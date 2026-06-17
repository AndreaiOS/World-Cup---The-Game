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

    /// Every group-stage result: the player's own matches come from the save,
    /// all other matches are simulated. Consumes `gen` for the simulated matches
    /// in a fixed order. Call only when the player has played all three group
    /// matches.
    public static func allGroupResults(nations: [String: Nation], groups: [Group],
                                       save: TournamentSave,
                                       gen: inout SeededGenerator) -> [MatchResult] {
        let player = save.playerNationId
        let pGroup = playerGroup(in: groups, playerId: player)
        let opponents = groupOpponents(group: pGroup, playerId: player)

        var playerResultByOpponent: [String: MatchResult] = [:]
        for (i, opp) in opponents.enumerated() where i < save.playerResults.count {
            playerResultByOpponent[opp] = save.playerResults[i]
        }

        var results: [MatchResult] = []
        for group in groups {
            for (a, b) in GroupTable.roundRobinPairs(group.nationIds) {
                if group.id == pGroup.id && (a == player || b == player) {
                    let opp = (a == player) ? b : a
                    if let r = playerResultByOpponent[opp] {
                        results.append(r)
                    }
                } else {
                    let home = nations[a]!
                    let away = nations[b]!
                    results.append(MatchSimulator.simulate(home: home, away: away, using: &gen))
                }
            }
        }
        return results
    }
}
