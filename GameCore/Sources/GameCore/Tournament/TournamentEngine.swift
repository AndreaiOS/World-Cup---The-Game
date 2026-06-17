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

    /// Walk the knockout bracket using the player's results for their own
    /// matches and simulating the others, returning the current view.
    static func knockoutSnapshot(byId: [String: Nation], qualifiers: [Qualifier],
                                 save: TournamentSave, groupStandings: [GroupStanding],
                                 gen: inout SeededGenerator) -> TournamentSnapshot {
        let player = save.playerNationId
        let stages: [Stage] = [.roundOf32, .roundOf16, .quarterFinal, .semiFinal, .final]
        let knockoutResults = Array(save.playerResults.dropFirst(3))

        var matches = KnockoutBracket.buildRoundOf32(from: qualifiers)
        var kIndex = 0

        for stage in stages {
            guard let playerMatch = matches.first(where: {
                $0.homeId == player || $0.awayId == player
            }) else { break }

            if kIndex < knockoutResults.count {
                let r = knockoutResults[kIndex]
                kIndex += 1
                if r.winnerId != player {
                    return snapshot(stage: stage, phase: .eliminated, opponentId: nil,
                                    groupStandings: groupStandings, save: save)
                }
                if matches.count == 1 {                       // won the final
                    return snapshot(stage: stage, phase: .champion, opponentId: nil,
                                    groupStandings: groupStandings, save: save)
                }
                let roundResults: [MatchResult] = matches.map { m in
                    if m.homeId == player || m.awayId == player {
                        return r
                    }
                    return MatchSimulator.simulate(home: byId[m.homeId]!,
                                                   away: byId[m.awayId]!, using: &gen)
                }
                matches = KnockoutBracket.nextRound(from: matches, results: roundResults)
            } else {
                let opponentId = playerMatch.homeId == player ? playerMatch.awayId
                                                              : playerMatch.homeId
                return snapshot(stage: stage, phase: .playing, opponentId: opponentId,
                                groupStandings: groupStandings, save: save)
            }
        }

        // Unreachable for valid inputs: a won final returns inside the loop, and
        // the player is always present in each round while advancing.
        preconditionFailure("knockout walk did not terminate")
    }

    private static func snapshot(stage: Stage, phase: TournamentPhase, opponentId: String?,
                                 groupStandings: [GroupStanding],
                                 save: TournamentSave) -> TournamentSnapshot {
        TournamentSnapshot(stage: stage, phase: phase, opponentId: opponentId,
                           playerGroupStandings: groupStandings,
                           playerMatchesPlayed: save.playerResults.count)
    }
}
