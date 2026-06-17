import XCTest
@testable import GameCore

final class MatchSimulatorTests: XCTestCase {
    private let strong = Nation(id: "STR", name: "Strong", flag: "🅰️", strength: 99)
    private let weak = Nation(id: "WEK", name: "Weak", flag: "🅱️", strength: 5)

    func testResultIsDeterministicForSeed() {
        var g1 = SeededGenerator(seed: 123)
        var g2 = SeededGenerator(seed: 123)
        let r1 = MatchSimulator.simulate(home: strong, away: weak, using: &g1)
        let r2 = MatchSimulator.simulate(home: strong, away: weak, using: &g2)
        XCTAssertEqual(r1, r2)
    }

    func testNeverTiesAcrossManySeeds() {
        for seed in UInt64(1)...500 {
            var g = SeededGenerator(seed: seed)
            let r = MatchSimulator.simulate(home: strong, away: weak, using: &g)
            XCTAssertNotEqual(r.homeScore, r.awayScore, "tie at seed \(seed)")
        }
    }

    func testStrongerTeamWinsMajorityOverManySeeds() {
        var strongWins = 0
        for seed in UInt64(1)...500 {
            var g = SeededGenerator(seed: seed)
            let r = MatchSimulator.simulate(home: strong, away: weak, using: &g)
            if r.winnerId == "STR" { strongWins += 1 }
        }
        XCTAssertGreaterThan(strongWins, 350)
    }

    func testResultCarriesNationIds() {
        var g = SeededGenerator(seed: 9)
        let r = MatchSimulator.simulate(home: strong, away: weak, using: &g)
        XCTAssertEqual(r.homeId, "STR")
        XCTAssertEqual(r.awayId, "WEK")
    }
}
