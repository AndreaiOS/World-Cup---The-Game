import XCTest
@testable import GameCore

final class GroupTableTests: XCTestCase {
    func testRoundRobinProducesSixUniquePairs() {
        let pairs = GroupTable.roundRobinPairs(["A", "B", "C", "D"])
        XCTAssertEqual(pairs.count, 6)
        let normalized = Set(pairs.map { [$0.0, $0.1].sorted().joined(separator: "-") })
        XCTAssertEqual(normalized.count, 6)
    }

    func testStandingsAccumulateResults() {
        let ids = ["A", "B", "C", "D"]
        let results = [
            MatchResult(homeId: "A", awayId: "B", homeScore: 4, awayScore: 3),
            MatchResult(homeId: "A", awayId: "C", homeScore: 5, awayScore: 2),
            MatchResult(homeId: "D", awayId: "A", homeScore: 2, awayScore: 1),
        ]
        let table = GroupTable.standings(nationIds: ids, results: results)
        let a = table.first { $0.nationId == "A" }!
        XCTAssertEqual(a.played, 3)
        XCTAssertEqual(a.wins, 2)
        XCTAssertEqual(a.losses, 1)
        XCTAssertEqual(a.goalsFor, 10)      // 4 + 5 + 1
        XCTAssertEqual(a.goalsAgainst, 7)   // 3 + 2 + 2
        XCTAssertEqual(a.points, 6)
    }

    func testStandingsSortedByPointsThenDifference() {
        let ids = ["A", "B", "C", "D"]
        let results = [
            MatchResult(homeId: "A", awayId: "B", homeScore: 5, awayScore: 0),
            MatchResult(homeId: "C", awayId: "D", homeScore: 3, awayScore: 2),
            MatchResult(homeId: "A", awayId: "C", homeScore: 1, awayScore: 2),
        ]
        let table = GroupTable.standings(nationIds: ids, results: results)
        XCTAssertEqual(table.first?.nationId, "C")     // 6 pts
        XCTAssertEqual(table.map { $0.nationId }.firstIndex(of: "A"), 1)
    }
}
