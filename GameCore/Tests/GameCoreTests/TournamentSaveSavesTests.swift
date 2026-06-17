import XCTest
@testable import GameCore

final class TournamentSaveSavesTests: XCTestCase {
    func testRoundTripsWithSaves() throws {
        let save = TournamentSave(playerNationId: "BRA", seed: 1,
                                  playerResults: [], playerSaves: [2, 3])
        let data = try JSONEncoder().encode(save)
        let decoded = try JSONDecoder().decode(TournamentSave.self, from: data)
        XCTAssertEqual(decoded.playerSaves, [2, 3])
        XCTAssertEqual(decoded, save)
    }

    func testDecodesLegacySaveWithoutSavesKey() throws {
        let json = #"{"playerNationId":"BRA","seed":7,"playerResults":[]}"#
            .data(using: .utf8)!
        let decoded = try JSONDecoder().decode(TournamentSave.self, from: json)
        XCTAssertEqual(decoded.playerSaves, [])
        XCTAssertEqual(decoded.playerNationId, "BRA")
    }
}
