import XCTest
@testable import GameCore

final class PenaltyEngineTests: XCTestCase {
    private func resolve(_ shot: Shot, _ keeper: KeeperDive, seed: UInt64 = 1) -> PenaltyOutcome {
        var g = SeededGenerator(seed: seed)
        return PenaltyEngine.resolve(shot: shot, keeper: keeper, using: &g)
    }

    func testKeeperSavesCenteredLowShotWhenCovering() {
        let shot = Shot(aimX: 0, aimY: 0.3, power: 0, curve: 0)
        XCTAssertEqual(resolve(shot, KeeperDive(x: 0)), .saved)
    }

    func testGoalWhenKeeperDivesWrongWay() {
        let shot = Shot(aimX: 0, aimY: 0.3, power: 0, curve: 0)
        XCTAssertEqual(resolve(shot, KeeperDive(x: 0.9)), .goal)
    }

    func testTopShotBeatsCenteredKeeper() {
        let shot = Shot(aimX: 0, aimY: 0.95, power: 0, curve: 0)
        XCTAssertEqual(resolve(shot, KeeperDive(x: 0)), .goal)
    }

    func testWideViaCurveIsMiss() {
        let shot = Shot(aimX: 0.95, aimY: 0.3, power: 0, curve: 1)
        XCTAssertEqual(resolve(shot, KeeperDive(x: 0)), .miss)
    }

    func testDeterministicForSeed() {
        let shot = Shot(aimX: 0.2, aimY: 0.5, power: 1, curve: 0.1)
        XCTAssertEqual(resolve(shot, KeeperDive(x: 0), seed: 77),
                       resolve(shot, KeeperDive(x: 0), seed: 77))
    }

    func testHighPowerCanSprayOffTarget() {
        let shot = Shot(aimX: 0.98, aimY: 0.5, power: 1, curve: 0)
        let anyMiss = (UInt64(1)...200).contains { resolve(shot, KeeperDive(x: -0.9), seed: $0) == .miss }
        XCTAssertTrue(anyMiss)
    }
}
