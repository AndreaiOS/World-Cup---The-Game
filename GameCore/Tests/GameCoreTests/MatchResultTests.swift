import XCTest
@testable import GameCore

final class MatchResultTests: XCTestCase {
    func testWinnerIsHigherScorer() {
        let result = MatchResult(homeId: "ITA", awayId: "FRA",
                                 homeScore: 4, awayScore: 3)
        XCTAssertEqual(result.winnerId, "ITA")
        XCTAssertEqual(result.loserId, "FRA")
    }

    func testWinnerWhenAwayScoresMore() {
        let result = MatchResult(homeId: "ITA", awayId: "FRA",
                                 homeScore: 2, awayScore: 5)
        XCTAssertEqual(result.winnerId, "FRA")
        XCTAssertEqual(result.loserId, "ITA")
    }

    func testRoundTripCodable() throws {
        let result = MatchResult(homeId: "ITA", awayId: "FRA",
                                 homeScore: 4, awayScore: 3)
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(MatchResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }
}
