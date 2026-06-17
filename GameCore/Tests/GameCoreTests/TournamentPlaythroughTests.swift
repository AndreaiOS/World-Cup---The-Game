import XCTest
@testable import GameCore

final class TournamentPlaythroughTests: XCTestCase {
    func testWinningEveryMatchReachesChampion() throws {
        let nations = try DataStore.loadNations()
        let groups = try DataStore.loadGroups()
        var save = TournamentSave(playerNationId: "BRA", seed: 7)

        var guardCount = 0
        while guardCount < 20 {
            guardCount += 1
            let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
            if snap.phase != .playing { break }
            let opp = try XCTUnwrap(snap.opponentId)
            // Player wins every match.
            save.playerResults.append(
                MatchResult(homeId: "BRA", awayId: opp, homeScore: 5, awayScore: 4))
        }

        let final = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(final.phase, .champion)
        XCTAssertEqual(final.stage, .final)
        // 3 group + 5 knockout = 8 matches to win it all.
        XCTAssertEqual(save.playerResults.count, 8)
    }

    func testRunIsDeterministicForSeed() throws {
        let nations = try DataStore.loadNations()
        let groups = try DataStore.loadGroups()
        func firstKnockoutOpponent(seed: UInt64) -> String? {
            let opps = TournamentEngine.groupOpponents(
                group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
            let save = TournamentSave(playerNationId: "BRA", seed: seed,
                playerResults: opps.map { MatchResult(homeId: "BRA", awayId: $0, homeScore: 5, awayScore: 0) })
            return TournamentEngine.snapshot(nations: nations, groups: groups, save: save).opponentId
        }
        XCTAssertEqual(firstKnockoutOpponent(seed: 123), firstKnockoutOpponent(seed: 123))
    }
}
