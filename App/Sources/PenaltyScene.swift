import SpriteKit
import GameCore

final class PenaltyScene: SKScene {
    private let ball = SKShapeNode(circleOfRadius: 13)
    private let keeper = SKShapeNode(rectOf: CGSize(width: 46, height: 64), cornerRadius: 8)
    private lazy var geo = GoalGeometry(sceneSize: size)

    override func didMove(to view: SKView) {
        backgroundColor = SKColor(red: 0.20, green: 0.55, blue: 0.25, alpha: 1)
        geo = GoalGeometry(sceneSize: size)
        drawGoal()
        drawKeeper()
        drawBall()
    }

    private func drawGoal() {
        let frame = SKShapeNode(rect: CGRect(
            x: geo.goalCenterX - geo.goalWidth / 2,
            y: geo.goalLineY,
            width: geo.goalWidth,
            height: geo.goalHeight))
        frame.strokeColor = .white
        frame.lineWidth = 6
        frame.fillColor = SKColor.white.withAlphaComponent(0.06)
        addChild(frame)
    }

    private func drawKeeper() {
        keeper.fillColor = SKColor.systemYellow
        keeper.strokeColor = .clear
        keeper.position = geo.keeperPoint(x: 0)
        addChild(keeper)
    }

    private func drawBall() {
        ball.fillColor = .white
        ball.strokeColor = .black
        ball.lineWidth = 1
        ball.position = geo.penaltySpot
        addChild(ball)
    }
}
