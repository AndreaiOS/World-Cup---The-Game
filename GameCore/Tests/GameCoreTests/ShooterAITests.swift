import XCTest
@testable import GameCore

final class ShooterAITests: XCTestCase {
    func testShotComponentsInRange() {
        for seed in UInt64(1)...300 {
            var g = SeededGenerator(seed: seed)
            let shot = ShooterAI.shoot(strength: 60, using: &g)
            XCTAssertGreaterThanOrEqual(shot.aimX, -1.0)
            XCTAssertLessThanOrEqual(shot.aimX, 1.0)
            XCTAssertGreaterThanOrEqual(shot.aimY, 0.0)
            XCTAssertLessThanOrEqual(shot.aimY, 1.0)
            XCTAssertGreaterThanOrEqual(shot.power, 0.0)
            XCTAssertLessThanOrEqual(shot.power, 1.0)
        }
    }

    func testDeterministicForSeed() {
        var a = SeededGenerator(seed: 9)
        var b = SeededGenerator(seed: 9)
        XCTAssertEqual(ShooterAI.shoot(strength: 70, using: &a),
                       ShooterAI.shoot(strength: 70, using: &b))
    }

    func testStrongShooterScoresMoreThanWeak() {
        func goals(strength: Int) -> Int {
            var count = 0
            for seed in UInt64(1)...400 {
                var g = SeededGenerator(seed: seed)
                let shot = ShooterAI.shoot(strength: strength, using: &g)
                if PenaltyEngine.resolve(shot: shot, keeper: KeeperDive(x: 0), using: &g) == .goal {
                    count += 1
                }
            }
            return count
        }
        let strong = goals(strength: 99)
        let weak = goals(strength: 5)
        XCTAssertGreaterThan(strong, weak)
        XCTAssertGreaterThan(strong, 200)
    }
}
