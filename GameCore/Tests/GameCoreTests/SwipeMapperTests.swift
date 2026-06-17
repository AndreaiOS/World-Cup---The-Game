import XCTest
@testable import GameCore

final class SwipeMapperTests: XCTestCase {
    func testShotPassesInRangeValues() {
        let shot = SwipeMapper.shot(dx: 0.3, dy: 0.6, speed: 0.8, curve: -0.2)
        XCTAssertEqual(shot.aimX, 0.3)
        XCTAssertEqual(shot.aimY, 0.6)
        XCTAssertEqual(shot.power, 0.8)
        XCTAssertEqual(shot.curve, -0.2)
    }

    func testShotClampsOutOfRange() {
        let shot = SwipeMapper.shot(dx: 2, dy: -1, speed: 5, curve: -9)
        XCTAssertEqual(shot.aimX, 1)
        XCTAssertEqual(shot.aimY, 0)
        XCTAssertEqual(shot.power, 1)
        XCTAssertEqual(shot.curve, -1)
    }

    func testDiveClampsDx() {
        XCTAssertEqual(SwipeMapper.dive(dx: 0.5).x, 0.5)
        XCTAssertEqual(SwipeMapper.dive(dx: -3).x, -1)
        XCTAssertEqual(SwipeMapper.dive(dx: 3).x, 1)
    }
}
