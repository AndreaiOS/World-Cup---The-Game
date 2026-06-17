import XCTest
@testable import GameCore

final class ScoreCalculatorTests: XCTestCase {
    func testCombinesAllComponents() {
        let stats = TournamentStats(goalsScored: 10, saves: 5,
                                    matchesWon: 4, wonTournament: true)
        // 10*100 + 5*60 + 4*250 + 1000 = 1000 + 300 + 1000 + 1000 = 3300
        XCTAssertEqual(ScoreCalculator.totalScore(stats), 3300)
    }

    func testNoBonusWhenTournamentNotWon() {
        let stats = TournamentStats(goalsScored: 3, saves: 2,
                                    matchesWon: 1, wonTournament: false)
        // 300 + 120 + 250 + 0 = 670
        XCTAssertEqual(ScoreCalculator.totalScore(stats), 670)
    }

    func testZeroStatsScoreZero() {
        let stats = TournamentStats(goalsScored: 0, saves: 0,
                                    matchesWon: 0, wonTournament: false)
        XCTAssertEqual(ScoreCalculator.totalScore(stats), 0)
    }
}
