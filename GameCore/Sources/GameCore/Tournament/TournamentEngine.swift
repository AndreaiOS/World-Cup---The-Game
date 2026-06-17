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

    /// Replay the whole tournament from the save and return the current view.
    public static func snapshot(nations: [Nation], groups: [Group],
                                save: TournamentSave) -> TournamentSnapshot {
        let player = save.playerNationId
        let byId = Dictionary(uniqueKeysWithValues: nations.map { ($0.id, $0) })
        precondition(byId[player] != nil, "unknown nation \(player)")
        let pGroup = playerGroup(in: groups, playerId: player)
        let opponents = groupOpponents(group: pGroup, playerId: player)

        // --- Group stage, still playing the player's three matches ---
        if save.playerResults.count < 3 {
            let standings = GroupTable.standings(nationIds: pGroup.nationIds,
                                                 results: save.playerResults)
            return TournamentSnapshot(
                stage: .group, phase: .playing,
                opponentId: opponents[save.playerResults.count],
                playerGroupStandings: standings,
                playerMatchesPlayed: save.playerResults.count)
        }

        // --- Group stage resolved: simulate the rest and check qualification ---
        var gen = SeededGenerator(seed: save.seed)
        let groupResults = allGroupResults(nations: byId, groups: groups, save: save, gen: &gen)
        let groupStandings = GroupTable.standings(nationIds: pGroup.nationIds, results: groupResults)
        let qualifiers = GroupTable.qualifiers(groups: groups, results: groupResults)

        guard qualifiers.contains(where: { $0.nationId == player }) else {
            return TournamentSnapshot(
                stage: .group, phase: .eliminated, opponentId: nil,
                playerGroupStandings: groupStandings,
                playerMatchesPlayed: save.playerResults.count)
        }

        // --- Knockout (Task 4 replaces this placeholder) ---
        return knockoutSnapshot(byId: byId, qualifiers: qualifiers, save: save,
                                groupStandings: groupStandings, gen: &gen)
    }

    /// Placeholder replaced in Task 4.
    static func knockoutSnapshot(byId: [String: Nation], qualifiers: [Qualifier],
                                 save: TournamentSave, groupStandings: [GroupStanding],
                                 gen: inout SeededGenerator) -> TournamentSnapshot {
        TournamentSnapshot(stage: .roundOf32, phase: .playing, opponentId: nil,
                           playerGroupStandings: groupStandings,
                           playerMatchesPlayed: save.playerResults.count)
    }
}
