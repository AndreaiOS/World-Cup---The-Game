# iOS App + Penalty Scene Implementation Plan

> **For agentic workers:** This plan is verified by BUILDING and RUNNING in the iOS Simulator, not by `swift test`. Execute it INLINE/interactively (superpowers:executing-plans), not via headless subagents — SpriteKit rendering and gestures need a real simulator and human eyes. Steps use checkbox (`- [ ]`) syntax.

**Goal:** A runnable iOS app where the player plays one complete penalty shootout (attacking with a swipe, defending with a swipe) against an AI opponent, driven by the existing pure-logic `GameCore`, rendered with SpriteKit inside SwiftUI.

**Architecture:** A new iOS app target (`WorldFootball`) generated with XcodeGen, depending on the local `GameCore` Swift package. SwiftUI hosts a SpriteKit `PenaltyScene` via `SpriteView`. The scene is a THIN renderer: it captures a swipe, normalizes it to `(dx, dy, speed, curve)`, hands it to `SwipeMapper`, calls `ShootoutController.playerShoot`/`playerDive`, then animates the ball, keeper, and outcome from the returned result and `State`. All game rules live in `GameCore`; the app adds only presentation.

**Tech Stack:** Swift 5.9, SwiftUI, SpriteKit, XcodeGen 2.45.4, Xcode 26.5, iOS 16 Simulator (iPhone 16). Depends on `GameCore` (`SwipeMapper`, `ShootoutController`, `Shot`, `KeeperDive`, `PenaltyOutcome`, `Nation`, `DataStore`).

---

## Verification model (read first)

- **Build:** `xcodebuild ... build` must succeed (0 errors) for every task.
- **Static visuals (Tasks 1-2):** boot the simulator, install, launch, screenshot, and confirm the expected static UI.
- **Gameplay interaction (Tasks 3-4):** the build + launch is automated; the actual swipe *feel* (does a flick score? does a dive save?) is verified by the human playing it. Programmatic gesture injection is out of scope. Each gameplay task lists exactly what the player should see/do.

Common commands (used throughout; `APP_ID = co.socialsprint.worldfootball2026`):

```bash
# generate the Xcode project from project.yml
cd App && xcodegen generate && cd ..

# build for the simulator into a known DerivedData path
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath /tmp/wf-dd build

# boot + install + launch + screenshot
xcrun simctl boot "iPhone 16" 2>/dev/null || true
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```

---

## File Structure

```
World/
├── App/
│   ├── project.yml                 # XcodeGen spec for the WorldFootball app target
│   └── Sources/
│       ├── WorldFootballApp.swift  # @main SwiftUI entry
│       ├── GameView.swift          # SwiftUI: hosts SpriteView + scoreboard/result overlay
│       ├── PenaltyScene.swift      # SKScene: rendering, swipe capture, drives ShootoutController
│       ├── SwipeReader.swift       # normalizes raw touch points -> (dx,dy,speed,curve)
│       └── GoalGeometry.swift      # maps engine coords (x∈[-1,1], y∈[0,1]) <-> scene points
└── GameCore/                       # unchanged (consumed as a package)
```

**Responsibilities:**
- `project.yml` — declares the iOS app target and its dependency on the local `GameCore` package.
- `WorldFootballApp.swift` — app entry; shows `GameView`.
- `GameView.swift` — SwiftUI container: a `SpriteView` for the scene plus a SwiftUI overlay for the scoreboard and the end-of-shootout result/replay.
- `PenaltyScene.swift` — the SpriteKit scene: draws pitch/goal/ball/keeper, reads swipes, calls `SwipeReader`→`SwipeMapper`→`ShootoutController`, animates the result.
- `SwipeReader.swift` — pure-ish helper converting a swipe (start/end/control points + duration + view size) into normalized engine inputs.
- `GoalGeometry.swift` — converts engine goal coordinates to scene points (where the ball should fly) and back.

---

## Task 1: XcodeGen scaffold — blank app builds and launches

**Files:**
- Create: `App/project.yml`
- Create: `App/Sources/WorldFootballApp.swift`

- [ ] **Step 1: Write `App/project.yml`**

```yaml
name: WorldFootball
options:
  bundleIdPrefix: co.socialsprint
  deploymentTarget:
    iOS: "16.0"
  createIntermediateGroups: true
packages:
  GameCore:
    path: ../GameCore
targets:
  WorldFootball:
    type: application
    platform: iOS
    sources:
      - Sources
    dependencies:
      - package: GameCore
    settings:
      base:
        GENERATE_INFOPLIST_FILE: "YES"
        PRODUCT_BUNDLE_IDENTIFIER: co.socialsprint.worldfootball2026
        MARKETING_VERSION: "0.1.0"
        CURRENT_PROJECT_VERSION: "1"
        TARGETED_DEVICE_FAMILY: "1"
        SWIFT_VERSION: "5.9"
        INFOPLIST_KEY_UILaunchScreen_Generation: "YES"
        INFOPLIST_KEY_UISupportedInterfaceOrientations: "UIInterfaceOrientationPortrait"
schemes:
  WorldFootball:
    build:
      targets:
        WorldFootball: all
    run:
      config: Debug
```

- [ ] **Step 2: Write the minimal app entry** — `App/Sources/WorldFootballApp.swift`:

```swift
import SwiftUI

@main
struct WorldFootballApp: App {
    var body: some Scene {
        WindowGroup {
            ZStack {
                Color.green.opacity(0.3).ignoresSafeArea()
                Text("World Football 2026")
                    .font(.title.bold())
            }
        }
    }
}
```

- [ ] **Step 3: Generate the project**

Run: `cd App && xcodegen generate && cd ..`
Expected: "Created project at .../App/WorldFootball.xcodeproj". Then confirm the scheme exists:
Run: `xcodebuild -project App/WorldFootball.xcodeproj -list`
Expected: lists a `WorldFootball` scheme.

- [ ] **Step 4: Build for the simulator**

Run:
```bash
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,name=iPhone 16' \
  -derivedDataPath /tmp/wf-dd build
```
Expected: `** BUILD SUCCEEDED **`.

- [ ] **Step 5: Launch and screenshot**

Run:
```bash
xcrun simctl boot "iPhone 16" 2>/dev/null || true
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: the screenshot shows a light-green screen with "World Football 2026".

- [ ] **Step 6: Add `.gitignore` for build output and commit**

Add to a new `App/.gitignore`:
```
WorldFootball.xcodeproj/
*.xcuserdatad/
```
(The project is regenerated from `project.yml`, so the generated `.xcodeproj` is not tracked.)

```bash
git add App/project.yml App/Sources/WorldFootballApp.swift App/.gitignore
git commit -m "feat: scaffold WorldFootball iOS app target (XcodeGen)"
```

---

## Task 2: PenaltyScene static rendering inside SwiftUI

**Files:**
- Create: `App/Sources/GoalGeometry.swift`
- Create: `App/Sources/PenaltyScene.swift`
- Create: `App/Sources/GameView.swift`
- Modify: `App/Sources/WorldFootballApp.swift` (show `GameView`)

- [ ] **Step 1: Write `App/Sources/GoalGeometry.swift`**

```swift
import CoreGraphics

/// Maps engine goal coordinates (x∈[-1,1], y∈[0,1]) to points inside a scene.
/// The goal mouth occupies the top portion of the scene; the penalty spot is
/// near the bottom center.
struct GoalGeometry {
    let sceneSize: CGSize

    var goalWidth: CGFloat { sceneSize.width * 0.7 }
    var goalHeight: CGFloat { sceneSize.height * 0.28 }
    var goalCenterX: CGFloat { sceneSize.width / 2 }
    var goalLineY: CGFloat { sceneSize.height * 0.62 }      // bottom of the goal mouth
    var crossbarY: CGFloat { goalLineY + goalHeight }
    var penaltySpot: CGPoint { CGPoint(x: sceneSize.width / 2, y: sceneSize.height * 0.16) }

    /// Where in the scene a shot aimed at (aimX, aimY) lands.
    func point(aimX: Double, aimY: Double) -> CGPoint {
        let x = goalCenterX + CGFloat(aimX) * (goalWidth / 2)
        let y = goalLineY + CGFloat(aimY) * goalHeight
        return CGPoint(x: x, y: y)
    }

    /// Where the keeper stands/dives for a horizontal commit x∈[-1,1].
    func keeperPoint(x: Double) -> CGPoint {
        CGPoint(x: goalCenterX + CGFloat(x) * (goalWidth / 2),
                y: goalLineY + goalHeight * 0.25)
    }
}
```

- [ ] **Step 2: Write `App/Sources/PenaltyScene.swift` (static rendering only for now)**

```swift
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
```

- [ ] **Step 3: Write `App/Sources/GameView.swift`**

```swift
import SwiftUI
import SpriteKit

struct GameView: View {
    @State private var scene = makeScene()

    private static func makeScene() -> PenaltyScene {
        let scene = PenaltyScene(size: CGSize(width: 390, height: 600))
        scene.scaleMode = .resizeFill
        return scene
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            Text("0 – 0")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 8)
                .shadow(radius: 3)
        }
    }
}
```

- [ ] **Step 4: Point the app at `GameView`** — replace the body of `App/Sources/WorldFootballApp.swift`:

```swift
import SwiftUI

@main
struct WorldFootballApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
        }
    }
}
```

- [ ] **Step 5: Regenerate, build, launch, screenshot**

Run (regenerate because new source files were added):
```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/wf-dd build
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: `BUILD SUCCEEDED`; screenshot shows a green pitch, a white goal frame in the upper area, a yellow keeper on the goal line, a white ball near the bottom, and "0 – 0" at the top.

- [ ] **Step 6: Commit**

```bash
git add App/Sources/GoalGeometry.swift App/Sources/PenaltyScene.swift App/Sources/GameView.swift App/Sources/WorldFootballApp.swift
git commit -m "feat: render static penalty scene (pitch, goal, ball, keeper)"
```

---

## Task 3: Swipe to shoot — wire the attacking turn

**Files:**
- Create: `App/Sources/SwipeReader.swift`
- Modify: `App/Sources/PenaltyScene.swift` (swipe capture + shoot + animation)

The scene holds a `ShootoutController` and, on the player's shooting turn, turns
a swipe into a `Shot` and animates the outcome. The keeper has no exposed dive,
so its animation is a heuristic from the outcome (dives toward the ball on a
save, the wrong way on a goal) — purely cosmetic.

- [ ] **Step 1: Write `App/Sources/SwipeReader.swift`**

```swift
import CoreGraphics

/// Converts a raw swipe in scene points into normalized engine inputs.
/// Scene coordinates have y up, so an upward flick toward the goal yields dy > 0.
struct SwipeReader {
    let sceneSize: CGSize

    func read(start: CGPoint, end: CGPoint, control: CGPoint,
              duration: TimeInterval) -> (dx: Double, dy: Double, speed: Double, curve: Double) {
        let w = Double(sceneSize.width)
        let h = Double(sceneSize.height)

        // A horizontal flick of ~35% of width = full aim left/right.
        let dx = Double(end.x - start.x) / (w * 0.35)
        // An upward flick of ~45% of height = full aim to the crossbar.
        let dy = Double(end.y - start.y) / (h * 0.45)

        let dist = Double(hypot(end.x - start.x, end.y - start.y))
        let pxPerSec = dist / max(duration, 0.016)
        // ~2000 px/s reads as full power.
        let speed = pxPerSec / 2000.0

        // Curve = sideways offset of the control (mid) point from the straight
        // line start->end, normalized by half the swipe length.
        let mx = Double(end.x - start.x), my = Double(end.y - start.y)
        let len = max(hypot(mx, my), 1)
        let cx = Double(control.x - start.x), cy = Double(control.y - start.y)
        let cross = (mx * cy - my * cx) / len     // signed perpendicular distance
        let curve = cross / (len * 0.5)

        return (dx, dy, speed, curve)
    }
}
```

- [ ] **Step 2: Add swipe state + controller to `PenaltyScene`** — add these stored properties at the top of the class (below the existing `keeper`/`ball`/`geo`):

```swift
    private let controller = ShootoutController(opponentStrength: 75,
                                                seed: UInt64.random(in: 1...999_999))
    private lazy var swipes = SwipeReader(sceneSize: size)
    private var touchStart: CGPoint?
    private var touchMid: CGPoint?
    private var touchStartTime: TimeInterval = 0
    private var busy = false
    /// Called by the SwiftUI layer to refresh the scoreboard/result after each kick.
    var onStateChange: ((ShootoutController.State) -> Void)?
```

- [ ] **Step 3: Capture the swipe** — add these overrides to `PenaltyScene`:

```swift
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
```

- [ ] **Step 4: Animate the shot** — add to `PenaltyScene`:

```swift
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
        // Reset the ball after a beat, ready for the next kick.
        ball.run(.sequence([
            .wait(forDuration: 0.8),
            .move(to: geo.penaltySpot, duration: 0.0),
            .run { [weak self] in
                self?.keeper.run(.move(to: self!.geo.keeperPoint(x: 0), duration: 0.2))
                self?.busy = false
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
```

- [ ] **Step 5: Surface the scoreboard** — in `GameView.swift`, replace the static `Text("0 – 0")` with live state. Replace the whole `GameView` struct with:

```swift
import SwiftUI
import SpriteKit
import GameCore

struct GameView: View {
    @State private var playerScore = 0
    @State private var opponentScore = 0
    @State private var scene: PenaltyScene = makeScene()

    private static func makeScene() -> PenaltyScene {
        let scene = PenaltyScene(size: CGSize(width: 390, height: 600))
        scene.scaleMode = .resizeFill
        return scene
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            Text("\(playerScore) – \(opponentScore)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 8)
                .shadow(radius: 3)
        }
        .onAppear {
            scene.onStateChange = { state in
                playerScore = state.playerScore
                opponentScore = state.opponentScore
            }
        }
    }
}
```

- [ ] **Step 6: Regenerate, build, launch**

```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/wf-dd build
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: `BUILD SUCCEEDED`; app launches showing the scene.
**Human gameplay check:** drag from the ball toward a corner of the goal and release. The ball should fly there, the keeper dives, a "GOAL!/SAVED!/MISS!" label flashes, and the scoreboard updates after a goal. After your kick it becomes the opponent's turn (handled in Task 4); for now the scene will ignore further taps until the defend flow exists.

- [ ] **Step 7: Commit**

```bash
git add App/Sources/SwipeReader.swift App/Sources/PenaltyScene.swift App/Sources/GameView.swift
git commit -m "feat: swipe-to-shoot attacking turn wired to ShootoutController"
```

---

## Task 4: Defending turn + full shootout loop + result overlay

**Files:**
- Modify: `App/Sources/PenaltyScene.swift` (defend flow + turn prompt)
- Modify: `App/Sources/GameView.swift` (result + replay overlay)

On the player's keeping turn, an opponent ball flies toward the goal and the
player swipes left/right to dive; the dive direction is the swipe's horizontal
sign. When the shootout is decided, the SwiftUI overlay shows the result and a
"Play Again" button that resets the scene.

- [ ] **Step 1: Add a turn prompt + defend handling to `PenaltyScene`** — add a prompt label property near the other stored properties:

```swift
    private let prompt = SKLabelNode(text: "SWIPE TO SHOOT")
```

and add to the end of `didMove(to:)`:

```swift
        prompt.fontName = "AvenirNext-Bold"
        prompt.fontSize = 18
        prompt.fontColor = SKColor.white.withAlphaComponent(0.85)
        prompt.position = CGPoint(x: size.width / 2, y: size.height * 0.07)
        addChild(prompt)
        updatePrompt()
```

Add this helper:

```swift
    private func updatePrompt() {
        let s = controller.state()
        if s.isOver {
            prompt.text = ""
        } else {
            prompt.text = s.turn == .playerShoots ? "SWIPE TO SHOOT" : "SWIPE TO DIVE"
        }
    }
```

- [ ] **Step 2: Handle the defend swipe** — change `touchesEnded` to branch on the turn. Replace the existing `touchesEnded` with:

```swift
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
```

Update the guards in `touchesBegan` to allow either turn (remove the
`turn == .playerShoots` condition so both turns can start a swipe):

```swift
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !busy, !controller.state().isOver, let t = touches.first else { return }
        touchStart = t.location(in: self)
        touchMid = t.location(in: self)
        touchStartTime = t.timestamp
    }
```

- [ ] **Step 3: Animate the defend turn** — add to `PenaltyScene`:

```swift
    private func dive(_ keeperDive: KeeperDive) {
        busy = true
        let outcome = controller.playerDive(keeperDive)

        // Move the keeper to the player's chosen side.
        keeper.run(.move(to: geo.keeperPoint(x: keeperDive.x), duration: 0.25))

        // The opponent ball flies from the spot to a corner; saved => toward the
        // keeper, goal => away from it. (Cosmetic; the rule already decided it.)
        let targetX = outcome == .saved ? keeperDive.x
                    : (keeperDive.x >= 0 ? -0.6 : 0.6)
        let target = geo.point(aimX: targetX, aimY: 0.5)
        let oppBall = SKShapeNode(circleOfRadius: 13)
        oppBall.fillColor = .white
        oppBall.strokeColor = .black
        oppBall.position = geo.penaltySpot
        addChild(oppBall)
        oppBall.run(.sequence([
            .move(to: target, duration: 0.35),
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
            }
        ]))
    }
```

Also call `updatePrompt()` at the end of `finishKick(_:)` (the attacking
reset), inside its final `.run` block, right after setting `busy = false`:

```swift
                self?.busy = false
                self?.updatePrompt()
```

- [ ] **Step 4: Result + replay overlay** — replace `GameView.swift` with:

```swift
import SwiftUI
import SpriteKit
import GameCore

struct GameView: View {
    @State private var playerScore = 0
    @State private var opponentScore = 0
    @State private var isOver = false
    @State private var playerWon = false
    @State private var sceneID = 0
    @State private var scene: PenaltyScene = makeScene()

    private static func makeScene() -> PenaltyScene {
        let scene = PenaltyScene(size: CGSize(width: 390, height: 600))
        scene.scaleMode = .resizeFill
        return scene
    }

    private func wire(_ scene: PenaltyScene) {
        scene.onStateChange = { state in
            playerScore = state.playerScore
            opponentScore = state.opponentScore
            isOver = state.isOver
            playerWon = state.winnerIsPlayer ?? false
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .id(sceneID)
                .ignoresSafeArea()
            Text("\(playerScore) – \(opponentScore)")
                .font(.system(size: 34, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
                .padding(.top, 8)
                .shadow(radius: 3)

            if isOver {
                VStack(spacing: 16) {
                    Text(playerWon ? "YOU WIN!" : "YOU LOSE")
                        .font(.system(size: 40, weight: .black, design: .rounded))
                        .foregroundColor(.white)
                    Button("Play Again") { restart() }
                        .font(.title2.bold())
                        .padding(.horizontal, 28).padding(.vertical, 12)
                        .background(.white).foregroundColor(.black)
                        .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.black.opacity(0.55))
                .ignoresSafeArea()
            }
        }
        .onAppear { wire(scene) }
    }

    private func restart() {
        let fresh = Self.makeScene()
        wire(fresh)
        scene = fresh
        sceneID += 1
        playerScore = 0; opponentScore = 0; isOver = false; playerWon = false
    }
}
```

- [ ] **Step 5: Regenerate, build, launch**

```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,name=iPhone 16' -derivedDataPath /tmp/wf-dd build
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: `BUILD SUCCEEDED`; app launches.
**Human gameplay check:** the prompt alternates "SWIPE TO SHOOT" / "SWIPE TO DIVE". Take 5 shots and 5 dives; the scoreboard tracks both sides; when the shootout is decided the "YOU WIN!/YOU LOSE" overlay appears with a working "Play Again" button.

- [ ] **Step 6: Commit**

```bash
git add App/Sources/PenaltyScene.swift App/Sources/GameView.swift
git commit -m "feat: defending turn, full shootout loop, and result overlay"
```

---

## Done criteria

- `xcodebuild ... build` succeeds with zero errors.
- The app launches on the iPhone 16 simulator and renders the penalty scene.
- The player can play a complete shootout: swipe to shoot, swipe to dive, the
  scoreboard tracks both sides, an outcome flashes per kick, and a win/lose
  overlay with "Play Again" appears when the shootout is decided.
- All shootout rules come from `GameCore` (`SwipeMapper` + `ShootoutController`);
  the app contains only presentation code.

## What this plan deliberately leaves out

- Menus, nation selection, and the tournament bracket → app-shell plan, which
  also picks the opponent's real `Nation`/strength (this slice hardcodes
  `opponentStrength: 75`) and feeds the shootout result back into
  `TournamentEngine`/`TournamentState`.
- Tuning the swipe constants in `SwipeReader` and richer art/animation are
  expected to evolve by playtesting; the values here are a sensible first cut.
- Game Center score submission and audio → services plan.
- The keeper/opponent-ball animations are cosmetic heuristics from the outcome
  (the engine does not expose the keeper's dive); exposing it for exact visuals
  is a possible later refinement.
```

## Notes on execution

This plan is **build-and-run verified**, not unit-tested. Expect to iterate on
real `xcodebuild` errors (XcodeGen settings, SpriteKit API specifics under Xcode
26.5) during execution — that is normal for the first app-target plan and does
not indicate a flawed plan. Fix compile errors as they surface, keeping the
structure above.
