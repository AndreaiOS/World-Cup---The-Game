import XCTest
@testable import GameCore

final class TournamentTypesTests: XCTestCase {
    func testSaveRoundTrips() throws {
        let save = TournamentSave(playerNationId: "BRA", seed: 42, playerResults: [
            MatchResult(homeId: "BRA", awayId: "MAR", homeScore: 5, awayScore: 3)
        ])
        let data = try JSONEncoder().encode(save)
        let decoded = try JSONDecoder().decode(TournamentSave.self, from: data)
        XCTAssertEqual(decoded, save)
    }

    func testPlayerGroupAndOpponentsFromRealData() throws {
        let groups = try DataStore.loadGroups()
        let group = TournamentEngine.playerGroup(in: groups, playerId: "BRA")
        XCTAssertTrue(group.nationIds.contains("BRA"))
        let opponents = TournamentEngine.groupOpponents(group: group, playerId: "BRA")
        XCTAssertEqual(opponents.count, 3)
        XCTAssertFalse(opponents.contains("BRA"))
    }
}
