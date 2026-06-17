# Gameplay Presentation Logic Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the testable gameplay "brain" in `GameCore` — map a swipe to a `Shot`/`KeeperDive`, and orchestrate one interactive penalty shootout (turns, opponent AI, engine resolution, scoring) — all pure, seeded logic verified with `swift test`. The SpriteKit scene that renders this is the next plan.

**Architecture:** Extends the pure-Swift `GameCore` package. `SwipeMapper` is the seam between raw UI input and the engine. `ShootoutController` is the state machine the SpriteKit scene will drive: the player shoots (their team's kicks) and keeps (the opponent's kicks) in alternation; the controller calls `KeeperAI`/`ShooterAI` for the opponent, `PenaltyEngine.resolve` for the outcome, and `ShootoutScorer` for the result. It owns ONE `SeededGenerator` shared across AI and resolution, so a seed plus a sequence of player inputs fully determines the game — which is exactly what makes it testable. No SpriteKit/SwiftUI here.

**Tech Stack:** Swift 5.9+, Swift Package Manager, XCTest. Builds on `Shot`, `KeeperDive`, `PenaltyOutcome`, `PenaltyEngine`, `KeeperAI`, `ShooterAI`, `ShootoutScorer`, `SeededGenerator`.

---

## File Structure

```
GameCore/Sources/GameCore/Gameplay/
├── SwipeMapper.swift          # (dx,dy,speed,curve) -> Shot ; dx -> KeeperDive
└── ShootoutController.swift   # interactive shootout state machine
```

**Responsibilities:**
- `SwipeMapper` — pure translation of a normalized swipe into engine inputs, clamping to valid ranges. The scene computes the normalized swipe (displacement / view size, flick speed); the mapper turns it into a `Shot` (attacking) or `KeeperDive` (defending). This pins the swipe→engine contract.
- `ShootoutController` — drives one shootout. Tracks whose turn it is (`playerShoots` / `playerKeeps`), applies the player's `Shot` or `KeeperDive`, generates the opponent's behavior via the AIs, resolves with `PenaltyEngine`, records into `ShootoutScorer`, and exposes a `State` (scoreline, turn, last outcome, over, winner) plus the player's save count for scoring. Deterministic: owns one seeded generator shared by AI and resolution (this resolves the Plan-3 note about RNG sharing).

**Player ↔ scorer mapping:** the player's team is `home`; the opponent is `away`. A player shoot records `home` (scored iff `.goal`); a player keep records `away` (scored iff the opponent's shot is `.goal`, i.e. not saved/missed). `State.playerScore == scorer.homeScored`.

---

## Task 1: SwipeMapper

**Files:**
- Create: `GameCore/Sources/GameCore/Gameplay/SwipeMapper.swift`
- Test: `GameCore/Tests/GameCoreTests/SwipeMapperTests.swift`

The scene supplies a normalized swipe: `dx` horizontal displacement (−1 left … 1
right), `dy` upward displacement toward goal (0 … 1 = ground … crossbar),
`speed` flick speed (0 … 1), `curve` lateral path bend (−1 … 1). The mapper
clamps these into a `Shot`; when defending, only `dx` matters (the dive side).

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/SwipeMapperTests.swift`:

```swift
import XCTest
@testable import GameCore

final class SwipeMapperTests: XCTestCase {
    func testShotPassesInRangeValues() {
        let shot = SwipeMapper.shot(dx: 0.3, dy: 0.6, speed: 0.8, curve: -0.2)
        XCTAssertEqual(shot.aimX, 0.3)
        XCTAssertEqual(shot.aimY, 0.6)
        XCTAssertEqual(shot.power, 0.8)
        XCTAssertEqual(shot.curve, -0.2)
    }

    func testShotClampsOutOfRange() {
        let shot = SwipeMapper.shot(dx: 2, dy: -1, speed: 5, curve: -9)
        XCTAssertEqual(shot.aimX, 1)     // dx clamped to 1
        XCTAssertEqual(shot.aimY, 0)     // dy clamped to 0
        XCTAssertEqual(shot.power, 1)    // speed clamped to 1
        XCTAssertEqual(shot.curve, -1)   // curve clamped to -1
    }

    func testDiveClampsDx() {
        XCTAssertEqual(SwipeMapper.dive(dx: 0.5).x, 0.5)
        XCTAssertEqual(SwipeMapper.dive(dx: -3).x, -1)
        XCTAssertEqual(SwipeMapper.dive(dx: 3).x, 1)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter SwipeMapperTests`
Expected: FAIL — "cannot find 'SwipeMapper' in scope".

- [ ] **Step 3: Write the mapper**

`GameCore/Sources/GameCore/Gameplay/SwipeMapper.swift`:

```swift
/// Translates a normalized swipe into engine inputs. The scene normalizes raw
/// touch points (displacement / view size, flick speed) before calling this.
public enum SwipeMapper {
    /// Attacking: horizontal drag = aim X, upward drag = aim height,
    /// flick speed = power, path bend = curve.
    public static func shot(dx: Double, dy: Double, speed: Double, curve: Double) -> Shot {
        Shot(aimX: clampSigned(dx),
             aimY: clampUnit(dy),
             power: clampUnit(speed),
             curve: clampSigned(curve))
    }

    /// Defending: only the horizontal drag matters — it picks the dive side.
    public static func dive(dx: Double) -> KeeperDive {
        KeeperDive(x: clampSigned(dx))
    }

    private static func clampSigned(_ v: Double) -> Double { min(1.0, max(-1.0, v)) }
    private static func clampUnit(_ v: Double) -> Double { min(1.0, max(0.0, v)) }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter SwipeMapperTests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Gameplay/SwipeMapper.swift GameCore/Tests/GameCoreTests/SwipeMapperTests.swift
git commit -m "feat: add SwipeMapper for swipe-to-engine input"
```

---

## Task 2: ShootoutController — turns, resolution, scoreline

**Files:**
- Create: `GameCore/Sources/GameCore/Gameplay/ShootoutController.swift`
- Test: `GameCore/Tests/GameCoreTests/ShootoutControllerTests.swift`

Key deterministic facts used by the tests (true for any seed, by geometry):
- A top-corner shot `Shot(aimX: 0.9, aimY: 0.95, power: 0, curve: 0)` is **always a
  goal**: `aimY 0.95 > keeperVerticalReach 0.70`, so no keeper can save it, and it
  is on-frame. Used to force player goals deterministically.

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/ShootoutControllerTests.swift`:

```swift
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
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter ShootoutControllerTests`
Expected: FAIL — "cannot find 'ShootoutController' in scope".

- [ ] **Step 3: Write the controller**

`GameCore/Sources/GameCore/Gameplay/ShootoutController.swift`:

```swift
/// Drives one interactive penalty shootout. The player shoots their team's
/// kicks and keeps the opponent's kicks in alternation. Deterministic: owns a
/// single seeded generator shared by the opponent AI and the resolver, so a
/// seed plus the player's inputs fully determine the game.
public final class ShootoutController {
    public enum Turn: Equatable { case playerShoots, playerKeeps }

    public struct State: Equatable {
        public let playerScore: Int
        public let opponentScore: Int
        public let turn: Turn
        public let lastOutcome: PenaltyOutcome?
        public let isOver: Bool
        public let winnerIsPlayer: Bool?
    }

    private let opponentStrength: Int
    private var rng: SeededGenerator
    private var scorer = ShootoutScorer()
    private var turn: Turn = .playerShoots
    private var lastOutcome: PenaltyOutcome?
    public private(set) var playerSaves = 0

    public init(opponentStrength: Int, seed: UInt64) {
        self.opponentStrength = opponentStrength
        self.rng = SeededGenerator(seed: seed)
    }

    public func state() -> State {
        State(playerScore: scorer.homeScored,
              opponentScore: scorer.awayScored,
              turn: turn,
              lastOutcome: lastOutcome,
              isOver: scorer.isDecided,
              winnerIsPlayer: scorer.winner.map { $0 == .home })
    }

    /// The player takes one of their team's kicks against the opponent keeper.
    @discardableResult
    public func playerShoot(_ shot: Shot) -> PenaltyOutcome {
        precondition(turn == .playerShoots && !scorer.isDecided,
                     "not the player's turn to shoot")
        let dive = KeeperAI.dive(strength: opponentStrength, against: shot, using: &rng)
        let outcome = PenaltyEngine.resolve(shot: shot, keeper: dive, using: &rng)
        scorer.record(side: .home, scored: outcome == .goal)
        lastOutcome = outcome
        turn = .playerKeeps
        return outcome
    }

    /// The player keeps one of the opponent's kicks.
    @discardableResult
    public func playerDive(_ dive: KeeperDive) -> PenaltyOutcome {
        precondition(turn == .playerKeeps && !scorer.isDecided,
                     "not the player's turn to keep")
        let shot = ShooterAI.shoot(strength: opponentStrength, using: &rng)
        let outcome = PenaltyEngine.resolve(shot: shot, keeper: dive, using: &rng)
        scorer.record(side: .away, scored: outcome == .goal)
        if outcome == .saved { playerSaves += 1 }
        lastOutcome = outcome
        turn = .playerShoots
        return outcome
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter ShootoutControllerTests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Gameplay/ShootoutController.swift GameCore/Tests/GameCoreTests/ShootoutControllerTests.swift
git commit -m "feat: add ShootoutController turns and resolution"
```

---

## Task 3: ShootoutController — terminal state and a full playthrough

**Files:**
- Modify: `GameCore/Tests/GameCoreTests/ShootoutControllerTests.swift` (add tests)
- Test only — the controller already implements `isOver`, `winnerIsPlayer`, and
  `playerSaves` from Task 2; this task verifies the terminal behavior with a
  deterministic end-to-end playthrough.

Key deterministic facts (true for any seed, by geometry):
- Against a weak opponent (`opponentStrength: 5`), a centered dive
  `KeeperDive(x: 0)` **always saves**: the weak shooter aims near center with low
  power, so the ball lands within `keeperReach 0.40` and below
  `keeperVerticalReach 0.70`. Used to force player saves and keep the opponent
  scoreless.
- Combined with the always-goal top-corner shot, a player who shoots top-corner
  and dives center every round wins 5-0 after five rounds.

- [ ] **Step 1: Write the failing tests (added to the existing test class)**

Add these methods inside `ShootoutControllerTests`:

```swift
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
```

- [ ] **Step 2: Run tests to verify the new ones pass**

Run: `cd GameCore && swift test --filter ShootoutControllerTests`
Expected: PASS — the three Task-2 tests plus the three new ones (six total).

If `testCenteredDiveSavesWeakOpponentAndCountsSave` or the playthrough fails,
the weak-shooter/center-dive geometry assumption is off; do NOT change the
controller — re-derive the guaranteed-save input (a sufficiently centered dive
and weak opponent) and adjust only the test inputs, reporting what you changed.

- [ ] **Step 3: Run the full suite**

Run: `cd GameCore && swift test`
Expected: every test across the package PASSES.

- [ ] **Step 4: Commit**

```bash
git add GameCore/Tests/GameCoreTests/ShootoutControllerTests.swift
git commit -m "test: add ShootoutController terminal state and full playthrough"
```

---

## Done criteria

- `cd GameCore && swift test` builds and passes every test.
- `GameCore` still imports only `Foundation` (no SpriteKit/UIKit/SwiftUI).
- `SwipeMapper` turns a normalized swipe into a clamped `Shot` or `KeeperDive`.
- `ShootoutController` runs a full deterministic shootout: turns alternate,
  goals/saves are recorded, the scoreline and over/winner state are correct, and
  the player save count accumulates.

## What this plan deliberately leaves out

- The iOS app target, `PenaltyScene` (SpriteKit), swipe-gesture capture, rendering
  and animation → next plan (iOS app + scene), generated with XcodeGen and verified
  by building and running in the simulator. That scene is a thin renderer: it
  normalizes the player's swipe, hands it to `SwipeMapper`, calls
  `ShootoutController.playerShoot`/`playerDive`, and animates the returned outcome
  and `State`.
- Nation selection, bracket screens, menus, and tying a shootout result back into
  `TournamentEngine`/`TournamentState` → app-shell plan.
- Game Center and audio → services plan.
- Aggregating `playerScore`/`playerSaves`/wins into `TournamentStats` for
  `ScoreCalculator` happens at the tournament/app-shell layer, not here.
