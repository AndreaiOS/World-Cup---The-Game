/// Group-stage computations: fixtures, standings, and qualification.
public enum GroupTable {

    /// All unique unordered pairings of the given ids (round robin).
    public static func roundRobinPairs(_ ids: [String]) -> [(String, String)] {
        var pairs: [(String, String)] = []
        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                pairs.append((ids[i], ids[j]))
            }
        }
        return pairs
    }

    /// Build the sorted table for a group from its played results.
    /// Sort: points, then goal difference, then goals for, then id (stable).
    public static func standings(nationIds: [String],
                                 results: [MatchResult]) -> [GroupStanding] {
        var byId: [String: GroupStanding] = [:]
        for id in nationIds { byId[id] = GroupStanding(nationId: id) }

        for r in results {
            guard var home = byId[r.homeId], var away = byId[r.awayId] else { continue }
            home.played += 1; away.played += 1
            home.goalsFor += r.homeScore; home.goalsAgainst += r.awayScore
            away.goalsFor += r.awayScore; away.goalsAgainst += r.homeScore
            if r.homeScore >= r.awayScore { home.wins += 1; away.losses += 1 }
            else { away.wins += 1; home.losses += 1 }
            byId[r.homeId] = home; byId[r.awayId] = away
        }

        return byId.values.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.goalDifference != rhs.goalDifference {
                return lhs.goalDifference > rhs.goalDifference
            }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.nationId < rhs.nationId
        }
    }

    /// Top two of every group plus the eight best third-placed nations.
    /// Returns 32 qualifiers (24 + 8). Best thirds ranked by points, then
    /// goal difference, then goals for, then id.
    public static func qualifiers(groups: [Group],
                                  results: [MatchResult]) -> [Qualifier] {
        var advancing: [Qualifier] = []
        var thirds: [Qualifier] = []

        for group in groups {
            let table = standings(nationIds: group.nationIds, results: results)
            for (index, standing) in table.enumerated() {
                let q = Qualifier(nationId: standing.nationId, groupId: group.id,
                                  position: index + 1, points: standing.points,
                                  goalDifference: standing.goalDifference,
                                  goalsFor: standing.goalsFor)
                if index < 2 { advancing.append(q) }
                else if index == 2 { thirds.append(q) }
            }
        }

        let bestThirds = thirds.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.goalDifference != rhs.goalDifference {
                return lhs.goalDifference > rhs.goalDifference
            }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.nationId < rhs.nationId
        }.prefix(8)

        return advancing + bestThirds
    }
}
