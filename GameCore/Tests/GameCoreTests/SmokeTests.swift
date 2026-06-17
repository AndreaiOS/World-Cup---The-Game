import XCTest
@testable import GameCore

final class SmokeTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertEqual(GameCore.version, "0.1.0")
    }
}
