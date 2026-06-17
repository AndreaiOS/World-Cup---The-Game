import XCTest
@testable import GameCore

final class TournamentKnockoutTests: XCTestCase {
    private func data() throws -> ([Nation], [Group]) {
        (try DataStore.loadNations(), try DataStore.loadGroups())
    }

    private func threeGroupWins(_ groups: [Group]) -> [MatchResult] {
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
        return opps.map { MatchResult(homeId: "BRA", awayId: $0, homeScore: 5, awayScore: 0) }
    }

    func testQualifiedPlayerFacesAKnockoutOpponent() throws {
        let (nations, groups) = try data()
        let save = TournamentSave(playerNationId: "BRA", seed: 1, playerResults: threeGroupWins(groups))
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.phase, .playing)
        XCTAssertEqual(snap.stage, .roundOf32)
        XCTAssertNotNil(snap.opponentId)
        XCTAssertNotEqual(snap.opponentId, "BRA")
    }

    func testLosingFirstKnockoutMatchEliminates() throws {
        let (nations, groups) = try data()
        var results = threeGroupWins(groups)
        results.append(MatchResult(homeId: "BRA", awayId: "OPP", homeScore: 2, awayScore: 4)) // loss
        let save = TournamentSave(playerNationId: "BRA", seed: 1, playerResults: results)
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.phase, .eliminated)
        XCTAssertEqual(snap.stage, .roundOf32)
    }

    func testWinningEveryRoundCrownsChampion() throws {
        let (nations, groups) = try data()
        var results = threeGroupWins(groups)
        for _ in 0..<5 {   // R32, R16, QF, SF, Final
            results.append(MatchResult(homeId: "BRA", awayId: "OPP", homeScore: 5, awayScore: 4))
        }
        let save = TournamentSave(playerNationId: "BRA", seed: 1, playerResults: results)
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.phase, .champion)
        XCTAssertEqual(snap.stage, .final)
    }
}
