import XCTest
@testable import GameCore

final class AllGroupResultsTests: XCTestCase {
    private func brazilSave(seed: UInt64) throws -> ([Nation], [Group], TournamentSave) {
        let nations = try DataStore.loadNations()
        let groups = try DataStore.loadGroups()
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"),
            playerId: "BRA")
        let results = opps.map { MatchResult(homeId: "BRA", awayId: $0, homeScore: 5, awayScore: 0) }
        return (nations, groups, TournamentSave(playerNationId: "BRA", seed: seed, playerResults: results))
    }

    func testProducesSixResultsPerGroup() throws {
        let (nations, groups, save) = try brazilSave(seed: 1)
        var gen = SeededGenerator(seed: save.seed)
        let byId = Dictionary(uniqueKeysWithValues: nations.map { ($0.id, $0) })
        let results = TournamentEngine.allGroupResults(nations: byId, groups: groups,
                                                       save: save, gen: &gen)
        XCTAssertEqual(results.count, groups.count * 6)   // 12 * 6 = 72
    }

    func testPlayerResultsArePresent() throws {
        let (nations, groups, save) = try brazilSave(seed: 1)
        var gen = SeededGenerator(seed: save.seed)
        let byId = Dictionary(uniqueKeysWithValues: nations.map { ($0.id, $0) })
        let results = TournamentEngine.allGroupResults(nations: byId, groups: groups,
                                                       save: save, gen: &gen)
        let brazilMatches = results.filter { $0.homeId == "BRA" || $0.awayId == "BRA" }
        XCTAssertEqual(brazilMatches.count, 3)
        XCTAssertTrue(brazilMatches.allSatisfy { $0.winnerId == "BRA" })
    }

    func testDeterministicForSeed() throws {
        let (nations, groups, save) = try brazilSave(seed: 99)
        let byId = Dictionary(uniqueKeysWithValues: nations.map { ($0.id, $0) })
        var g1 = SeededGenerator(seed: save.seed)
        var g2 = SeededGenerator(seed: save.seed)
        let r1 = TournamentEngine.allGroupResults(nations: byId, groups: groups, save: save, gen: &g1)
        let r2 = TournamentEngine.allGroupResults(nations: byId, groups: groups, save: save, gen: &g2)
        XCTAssertEqual(r1, r2)
    }
}
