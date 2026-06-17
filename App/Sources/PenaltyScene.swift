import SpriteKit
import GameCore

final class PenaltyScene: SKScene {
    private let ball = SKShapeNode(circleOfRadius: 13)
    private let keeper = SKShapeNode(rectOf: CGSize(width: 46, height: 64), cornerRadius: 8)
    private lazy var geo = GoalGeometry(sceneSize: size)

    private let controller = ShootoutController(opponentStrength: 75,
                                                seed: UInt64.random(in: 1...999_999))
    private lazy var swipes = SwipeReader(sceneSize: size)
    private var touchStart: CGPoint?
    private var touchMid: CGPoint?
    private var touchStartTime: TimeInterval = 0
    private var busy = false
    /// Called by the SwiftUI layer to refresh the scoreboard/result after each kick.
    var onStateChange: ((ShootoutController.State) -> Void)?

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

    // MARK: - Swipe capture

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !busy, controller.state().turn == .playerShoots,
              let t = touches.first else { return }
        touchStart = t.location(in: self)
        touchMid = touchStart
        touchStartTime = t.timestamp
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        touchMid = t.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !busy, let start = touchStart, let mid = touchMid,
              let t = touches.first, controller.state().turn == .playerShoots else { return }
        let end = t.location(in: self)
        let duration = t.timestamp - touchStartTime
        let s = swipes.read(start: start, end: end, control: mid, duration: duration)
        let shot = SwipeMapper.shot(dx: s.dx, dy: s.dy, speed: s.speed, curve: s.curve)
        shoot(shot)
        touchStart = nil
    }

    // MARK: - Shooting

    private func shoot(_ shot: Shot) {
        busy = true
        let outcome = controller.playerShoot(shot)
        let target = geo.point(aimX: shot.aimX, aimY: shot.aimY)

        // Keeper heuristic: dive toward the ball on a save, the wrong way on a goal.
        let keeperX: Double
        switch outcome {
        case .saved: keeperX = shot.aimX
        case .goal:  keeperX = -max(0.3, abs(shot.aimX)) * (shot.aimX >= 0 ? 1 : -1)
        case .miss:  keeperX = 0
        }
        keeper.run(.move(to: geo.keeperPoint(x: keeperX), duration: 0.3))

        ball.run(.sequence([
            .move(to: target, duration: 0.35),
            .run { [weak self] in self?.finishKick(outcome) }
        ]))
    }

    private func finishKick(_ outcome: PenaltyOutcome) {
        flashOutcome(outcome)
        onStateChange?(controller.state())
        ball.run(.sequence([
            .wait(forDuration: 0.8),
            .move(to: geo.penaltySpot, duration: 0.0),
            .run { [weak self] in
                guard let self else { return }
                self.keeper.run(.move(to: self.geo.keeperPoint(x: 0), duration: 0.2))
                self.busy = false
            }
        ]))
    }

    private func flashOutcome(_ outcome: PenaltyOutcome) {
        let label = SKLabelNode(text: outcome == .goal ? "GOAL!"
                                : outcome == .saved ? "SAVED!" : "MISS!")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 40
        label.fontColor = .white
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.45)
        label.setScale(0.2)
        addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1.0, duration: 0.2), .fadeIn(withDuration: 0.2)]),
            .wait(forDuration: 0.6),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
    }
}
