import SpriteKit
import GameCore

final class PenaltyScene: SKScene {
    private let ball = SKNode()
    private let keeper = SKNode()
    private let prompt = SKLabelNode(text: "SWIPE TO SHOOT")
    private lazy var geo = GoalGeometry(sceneSize: size)

    var opponentStrength: Int = 75
    var matchSeed: UInt64 = 1
    /// Called once when the shootout is decided, with the final score.
    var onComplete: ((Int, Int) -> Void)?
    private var controller: ShootoutController!
    private var reported = false
    private lazy var swipes = SwipeReader(sceneSize: size)
    private var touchStart: CGPoint?
    private var touchMid: CGPoint?
    private var touchStartTime: TimeInterval = 0
    private var busy = false
    /// Called by the SwiftUI layer to refresh the scoreboard/result after each kick.
    var onStateChange: ((ShootoutController.State) -> Void)?

    override func didMove(to view: SKView) {
        controller = ShootoutController(opponentStrength: opponentStrength, seed: matchSeed)
        geo = GoalGeometry(sceneSize: size)
        drawPitch()
        drawGoal()
        buildKeeper()
        buildBall()

        prompt.fontName = "AvenirNext-Bold"
        prompt.fontSize = 20
        prompt.fontColor = SKColor.white.withAlphaComponent(0.9)
        prompt.position = CGPoint(x: size.width / 2, y: size.height * 0.06)
        addChild(prompt)
        updatePrompt()
    }

    // MARK: - Scenery

    private func drawPitch() {
        backgroundColor = SKColor(red: 0.16, green: 0.50, blue: 0.22, alpha: 1)
        let stripes = 9
        let h = size.height / CGFloat(stripes)
        for i in 0..<stripes where i % 2 == 0 {
            let r = SKShapeNode(rect: CGRect(x: 0, y: CGFloat(i) * h, width: size.width, height: h))
            r.fillColor = SKColor(white: 1, alpha: 0.05)
            r.strokeColor = .clear
            r.zPosition = -10
            addChild(r)
        }
        let spot = SKShapeNode(circleOfRadius: 4)
        spot.fillColor = .white
        spot.strokeColor = .clear
        spot.position = geo.penaltySpot
        addChild(spot)
    }

    private func drawGoal() {
        let left = geo.goalCenterX - geo.goalWidth / 2
        let right = geo.goalCenterX + geo.goalWidth / 2
        let bottom = geo.goalLineY
        let top = geo.crossbarY

        // Net grid.
        let net = CGMutablePath()
        let cols = 11, rows = 6
        for i in 0...cols {
            let x = left + CGFloat(i) / CGFloat(cols) * (right - left)
            net.move(to: CGPoint(x: x, y: bottom)); net.addLine(to: CGPoint(x: x, y: top))
        }
        for j in 0...rows {
            let y = bottom + CGFloat(j) / CGFloat(rows) * (top - bottom)
            net.move(to: CGPoint(x: left, y: y)); net.addLine(to: CGPoint(x: right, y: y))
        }
        let netNode = SKShapeNode(path: net)
        netNode.strokeColor = SKColor.white.withAlphaComponent(0.22)
        netNode.lineWidth = 1
        netNode.zPosition = -5
        addChild(netNode)

        // Posts + crossbar.
        let frame = CGMutablePath()
        frame.move(to: CGPoint(x: left, y: bottom))
        frame.addLine(to: CGPoint(x: left, y: top))
        frame.addLine(to: CGPoint(x: right, y: top))
        frame.addLine(to: CGPoint(x: right, y: bottom))
        let posts = SKShapeNode(path: frame)
        posts.strokeColor = .white
        posts.lineWidth = 8
        posts.lineJoin = .round
        posts.lineCap = .round
        addChild(posts)
    }

    private func buildKeeper() {
        let body = SKShapeNode(rectOf: CGSize(width: 30, height: 46), cornerRadius: 9)
        body.fillColor = SKColor(red: 0.10, green: 0.62, blue: 0.66, alpha: 1)
        body.strokeColor = .clear
        body.position = CGPoint(x: 0, y: -4)
        keeper.addChild(body)

        let arms = SKShapeNode(rectOf: CGSize(width: 58, height: 10), cornerRadius: 5)
        arms.fillColor = SKColor(red: 0.10, green: 0.62, blue: 0.66, alpha: 1)
        arms.strokeColor = .clear
        arms.position = CGPoint(x: 0, y: 10)
        keeper.addChild(arms)

        let head = SKShapeNode(circleOfRadius: 11)
        head.fillColor = SKColor(red: 0.95, green: 0.80, blue: 0.66, alpha: 1)
        head.strokeColor = .clear
        head.position = CGPoint(x: 0, y: 24)
        keeper.addChild(head)

        keeper.position = geo.keeperPoint(x: 0)
        keeper.zPosition = 5
        addChild(keeper)
    }

    private func makeBall() -> SKNode {
        let node = SKNode()
        let shadow = SKShapeNode(ellipseOf: CGSize(width: 26, height: 9))
        shadow.fillColor = SKColor.black.withAlphaComponent(0.22)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -15)
        node.addChild(shadow)

        let body = SKShapeNode(circleOfRadius: 13)
        body.fillColor = .white
        body.strokeColor = SKColor(white: 0.65, alpha: 1)
        body.lineWidth = 1
        node.addChild(body)

        let center = SKShapeNode(circleOfRadius: 3.4)
        center.fillColor = .black; center.strokeColor = .clear
        body.addChild(center)
        for angle in stride(from: 0.0, to: 360.0, by: 72.0) {
            let spot = SKShapeNode(circleOfRadius: 2.6)
            spot.fillColor = .black; spot.strokeColor = .clear
            spot.position = CGPoint(x: 7.2 * cos(angle * .pi / 180),
                                    y: 7.2 * sin(angle * .pi / 180))
            body.addChild(spot)
        }
        return node
    }

    private func buildBall() {
        ball.removeAllChildren()
        ball.addChild(makeBall())
        ball.position = geo.penaltySpot
        ball.zPosition = 8
        if ball.parent == nil { addChild(ball) }
    }

    private func updatePrompt() {
        let s = controller.state()
        prompt.text = s.isOver ? "" : (s.turn == .playerShoots ? "SWIPE TO SHOOT" : "SWIPE TO DIVE")
    }

    // MARK: - Swipe capture

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !busy, !controller.state().isOver, let t = touches.first else { return }
        touchStart = t.location(in: self)
        touchMid = t.location(in: self)
        touchStartTime = t.timestamp
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let t = touches.first else { return }
        touchMid = t.location(in: self)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !busy, let start = touchStart, let mid = touchMid,
              let t = touches.first else { return }
        let end = t.location(in: self)
        let duration = t.timestamp - touchStartTime
        let s = swipes.read(start: start, end: end, control: mid, duration: duration)
        switch controller.state().turn {
        case .playerShoots:
            shoot(SwipeMapper.shot(dx: s.dx, dy: s.dy, speed: s.speed, curve: s.curve))
        case .playerKeeps:
            dive(SwipeMapper.dive(dx: s.dx))
        }
        touchStart = nil
    }

    // MARK: - Shooting

    private func shoot(_ shot: Shot) {
        busy = true
        let outcome = controller.playerShoot(shot)
        let target = geo.point(aimX: shot.aimX, aimY: shot.aimY)

        // The keeper leaps to the ball on a save (so the save is visible), and
        // dives the wrong way on a goal (so the ball clearly beats him).
        let keeperDest: CGPoint
        switch outcome {
        case .saved: keeperDest = target
        case .goal:  keeperDest = geo.keeperPoint(x: shot.aimX >= 0 ? -0.7 : 0.7)
        case .miss:  keeperDest = geo.keeperPoint(x: 0)
        }
        keeper.run(.move(to: keeperDest, duration: 0.3))

        ball.run(.sequence([
            .group([.move(to: target, duration: 0.35), .scale(to: 0.7, duration: 0.35)]),
            .run { [weak self] in self?.finishKick(outcome) }
        ]))
    }

    private func finishKick(_ outcome: PenaltyOutcome) {
        flashOutcome(outcome)
        onStateChange?(controller.state())
        ball.run(.sequence([
            .wait(forDuration: 0.8),
            .run { [weak self] in
                guard let self else { return }
                self.ball.position = self.geo.penaltySpot
                self.ball.setScale(1.0)
                self.keeper.run(.move(to: self.geo.keeperPoint(x: 0), duration: 0.2))
                self.busy = false
                self.updatePrompt()
                self.reportIfFinished()
            }
        ]))
    }

    // MARK: - Defending

    private func dive(_ keeperDive: KeeperDive) {
        busy = true
        let outcome = controller.playerDive(keeperDive)

        // On a save the keeper meets the ball; on a goal the ball goes to the
        // opposite side while the keeper dives where the player chose.
        let targetX = outcome == .saved ? keeperDive.x
                    : (keeperDive.x >= 0 ? -0.6 : 0.6)
        let target = geo.point(aimX: targetX, aimY: 0.5)
        let keeperDest = outcome == .saved ? target : geo.keeperPoint(x: keeperDive.x)
        keeper.run(.move(to: keeperDest, duration: 0.25))
        let oppBall = makeBall()
        oppBall.position = geo.penaltySpot
        oppBall.zPosition = 8
        addChild(oppBall)
        oppBall.run(.sequence([
            .group([.move(to: target, duration: 0.35), .scale(to: 0.7, duration: 0.35)]),
            .removeFromParent(),
            .run { [weak self] in self?.finishKeep(outcome) }
        ]))
    }

    private func finishKeep(_ outcome: PenaltyOutcome) {
        flashOutcome(outcome == .saved ? .saved : .goal)
        onStateChange?(controller.state())
        run(.sequence([
            .wait(forDuration: 0.8),
            .run { [weak self] in
                guard let self else { return }
                self.keeper.run(.move(to: self.geo.keeperPoint(x: 0), duration: 0.2))
                self.busy = false
                self.updatePrompt()
                self.reportIfFinished()
            }
        ]))
    }

    private func reportIfFinished() {
        guard !reported, controller.state().isOver else { return }
        reported = true
        let s = controller.state()
        run(.sequence([
            .wait(forDuration: 0.6),
            .run { [weak self] in self?.onComplete?(s.playerScore, s.opponentScore) }
        ]))
    }

    private func flashOutcome(_ outcome: PenaltyOutcome) {
        let label = SKLabelNode(text: outcome == .goal ? "GOAL!"
                                : outcome == .saved ? "SAVED!" : "MISS!")
        label.fontName = "AvenirNext-Heavy"
        label.fontSize = 46
        label.fontColor = outcome == .goal ? SKColor(red: 0.30, green: 0.85, blue: 0.40, alpha: 1)
                        : outcome == .saved ? SKColor(red: 1.0, green: 0.35, blue: 0.35, alpha: 1)
                        : SKColor(red: 1.0, green: 0.7, blue: 0.2, alpha: 1)
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.34)
        label.zPosition = 20
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
