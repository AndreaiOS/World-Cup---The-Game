import XCTest
@testable import GameCore

final class GroupModelTests: XCTestCase {
    func testGroupDecodes() throws {
        let json = """
        { "id": "A", "nationIds": ["MEX", "CAN", "USA", "ITA"] }
        """.data(using: .utf8)!
        let group = try JSONDecoder().decode(Group.self, from: json)
        XCTAssertEqual(group.id, "A")
        XCTAssertEqual(group.nationIds.count, 4)
        XCTAssertEqual(group.nationIds.first, "MEX")
    }

    func testStandingComputesPointsAndDifference() {
        let s = GroupStanding(nationId: "ITA", played: 3, wins: 2, losses: 1,
                              goalsFor: 9, goalsAgainst: 6)
        XCTAssertEqual(s.points, 6)            // wins * 3, no draws
        XCTAssertEqual(s.goalDifference, 3)
    }
}
