import XCTest
@testable import GameCore

final class TournamentSnapshotGroupTests: XCTestCase {
    private func data() throws -> ([Nation], [Group]) {
        (try DataStore.loadNations(), try DataStore.loadGroups())
    }

    func testStartsPlayingFirstGroupOpponent() throws {
        let (nations, groups) = try data()
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
        let save = TournamentSave(playerNationId: "BRA", seed: 1)
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.phase, .playing)
        XCTAssertEqual(snap.stage, .group)
        XCTAssertEqual(snap.opponentId, opps[0])
        XCTAssertEqual(snap.playerMatchesPlayed, 0)
    }

    func testSecondGroupOpponentAfterOneWin() throws {
        let (nations, groups) = try data()
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
        let save = TournamentSave(playerNationId: "BRA", seed: 1, playerResults: [
            MatchResult(homeId: "BRA", awayId: opps[0], homeScore: 4, awayScore: 2)
        ])
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.opponentId, opps[1])
        XCTAssertEqual(snap.playerMatchesPlayed, 1)
    }

    func testWinningAllThreeQualifies() throws {
        let (nations, groups) = try data()
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
        let save = TournamentSave(playerNationId: "BRA", seed: 1,
            playerResults: opps.map { MatchResult(homeId: "BRA", awayId: $0, homeScore: 5, awayScore: 0) })
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertNotEqual(snap.phase, .eliminated)
        XCTAssertEqual(snap.playerMatchesPlayed, 3)
    }

    func testLosingAllThreeIsEliminated() throws {
        let (nations, groups) = try data()
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
        let save = TournamentSave(playerNationId: "BRA", seed: 1,
            playerResults: opps.map { MatchResult(homeId: "BRA", awayId: $0, homeScore: 0, awayScore: 5) })
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.phase, .eliminated)
        XCTAssertEqual(snap.stage, .group)
    }
}
