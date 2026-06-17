import XCTest
@testable import GameCore

final class PenaltyModelsTests: XCTestCase {
    func testShotStoresComponents() {
        let shot = Shot(aimX: 0.3, aimY: 0.5, power: 0.8, curve: -0.2)
        XCTAssertEqual(shot.aimX, 0.3)
        XCTAssertEqual(shot.aimY, 0.5)
        XCTAssertEqual(shot.power, 0.8)
        XCTAssertEqual(shot.curve, -0.2)
    }

    func testKeeperDiveStoresX() {
        XCTAssertEqual(KeeperDive(x: -0.6).x, -0.6)
    }

    func testOutcomeIsCodable() throws {
        let data = try JSONEncoder().encode(PenaltyOutcome.goal)
        let decoded = try JSONDecoder().decode(PenaltyOutcome.self, from: data)
        XCTAssertEqual(decoded, .goal)
    }
}
