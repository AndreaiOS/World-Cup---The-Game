import XCTest
@testable import GameCore

final class ShootoutControllerTests: XCTestCase {
    private let sureGoal = Shot(aimX: 0.9, aimY: 0.95, power: 0, curve: 0)

    func testStartsWithPlayerShootingAndZeroScore() {
        let c = ShootoutController(opponentStrength: 50, seed: 1)
        let s = c.state()
        XCTAssertEqual(s.turn, .playerShoots)
        XCTAssertEqual(s.playerScore, 0)
        XCTAssertEqual(s.opponentScore, 0)
        XCTAssertNil(s.lastOutcome)
        XCTAssertFalse(s.isOver)
    }

    func testSureGoalScoresAndAdvancesTurn() {
        let c = ShootoutController(opponentStrength: 80, seed: 7)
        let outcome = c.playerShoot(sureGoal)
        XCTAssertEqual(outcome, .goal)
        XCTAssertEqual(c.state().playerScore, 1)
        XCTAssertEqual(c.state().lastOutcome, .goal)
        XCTAssertEqual(c.state().turn, .playerKeeps)
    }

    func testDefendAdvancesTurnAndOpponentScoreMatchesOutcome() {
        let c = ShootoutController(opponentStrength: 60, seed: 3)
        _ = c.playerShoot(sureGoal)               // -> playerKeeps
        let outcome = c.playerDive(KeeperDive(x: 0))
        XCTAssertEqual(c.state().turn, .playerShoots)
        XCTAssertEqual(c.state().opponentScore, outcome == .goal ? 1 : 0)
    }

    func testWinnerIsNilUntilOver() {
        let c = ShootoutController(opponentStrength: 5, seed: 2)
        _ = c.playerShoot(sureGoal)
        XCTAssertNil(c.state().winnerIsPlayer)
        XCTAssertFalse(c.state().isOver)
    }

    func testCenteredDiveSavesWeakOpponentAndCountsSave() {
        let c = ShootoutController(opponentStrength: 5, seed: 4)
        _ = c.playerShoot(sureGoal)                 // -> playerKeeps
        let outcome = c.playerDive(KeeperDive(x: 0))
        XCTAssertEqual(outcome, .saved)
        XCTAssertEqual(c.playerSaves, 1)
        XCTAssertEqual(c.state().opponentScore, 0)
    }

    func testPlayerWinsFiveNilPlaythrough() {
        let c = ShootoutController(opponentStrength: 5, seed: 9)
        for _ in 0..<5 {
            XCTAssertFalse(c.state().isOver)
            _ = c.playerShoot(sureGoal)             // always goal
            _ = c.playerDive(KeeperDive(x: 0))      // always save
        }
        let s = c.state()
        XCTAssertTrue(s.isOver)
        XCTAssertEqual(s.playerScore, 5)
        XCTAssertEqual(s.opponentScore, 0)
        XCTAssertEqual(s.winnerIsPlayer, true)
        XCTAssertEqual(c.playerSaves, 5)
    }
}
