import XCTest
@testable import GameCore

final class KeeperAITests: XCTestCase {
    private let shot = Shot(aimX: 0.3, aimY: 0.3, power: 0, curve: 0)

    func testDiveIsInRange() {
        for seed in UInt64(1)...200 {
            var g = SeededGenerator(seed: seed)
            let dive = KeeperAI.dive(strength: 50, against: shot, using: &g)
            XCTAssertGreaterThanOrEqual(dive.x, -1.0)
            XCTAssertLessThanOrEqual(dive.x, 1.0)
        }
    }

    func testDeterministicForSeed() {
        var a = SeededGenerator(seed: 5)
        var b = SeededGenerator(seed: 5)
        XCTAssertEqual(KeeperAI.dive(strength: 80, against: shot, using: &a),
                       KeeperAI.dive(strength: 80, against: shot, using: &b))
    }

    func testStrongKeeperSavesMoreThanWeak() {
        func saves(strength: Int) -> Int {
            var count = 0
            for seed in UInt64(1)...400 {
                var g = SeededGenerator(seed: seed)
                let dive = KeeperAI.dive(strength: strength, against: shot, using: &g)
                if PenaltyEngine.resolve(shot: shot, keeper: dive, using: &g) == .saved {
                    count += 1
                }
            }
            return count
        }
        let strong = saves(strength: 99)
        let weak = saves(strength: 0)
        XCTAssertGreaterThan(strong, weak)
        XCTAssertGreaterThan(strong, 250)
    }
}
