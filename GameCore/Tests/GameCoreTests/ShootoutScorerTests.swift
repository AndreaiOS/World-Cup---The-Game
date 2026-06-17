import XCTest
@testable import GameCore

final class ShootoutScorerTests: XCTestCase {
    private func take(_ s: inout ShootoutScorer, home: [Bool], away: [Bool]) {
        for i in 0..<max(home.count, away.count) {
            if i < home.count { s.record(side: .home, scored: home[i]) }
            if i < away.count { s.record(side: .away, scored: away[i]) }
        }
    }

    func testFreshIsNotDecided() {
        let s = ShootoutScorer()
        XCTAssertFalse(s.isDecided)
        XCTAssertNil(s.winner)
    }

    func testDecidedAfterRegulationWhenScoresDiffer() {
        var s = ShootoutScorer()
        take(&s, home: [true, true, true, false, false],
                away: [true, false, true, false, false])
        XCTAssertTrue(s.isDecided)
        XCTAssertEqual(s.winner, .home)
    }

    func testTiedAfterRegulationIsNotDecided() {
        var s = ShootoutScorer()
        take(&s, home: [true, true, true, false, false],
                away: [true, true, true, false, false])
        XCTAssertFalse(s.isDecided)
        XCTAssertNil(s.winner)
    }

    func testSuddenDeathDecidesOnUnequalPair() {
        var s = ShootoutScorer()
        take(&s, home: [true, true, true, false, false],
                away: [true, true, true, false, false])
        s.record(side: .home, scored: true)                // home 4, taken 6
        XCTAssertFalse(s.isDecided)                        // away yet to take
        s.record(side: .away, scored: false)               // away 3, taken 6
        XCTAssertTrue(s.isDecided)
        XCTAssertEqual(s.winner, .home)                    // home leads 4-3
    }

    func testMidRegulationNotDecided() {
        var s = ShootoutScorer()
        s.record(side: .home, scored: true)
        s.record(side: .away, scored: false)
        s.record(side: .home, scored: true)
        XCTAssertFalse(s.isDecided)
    }
}
