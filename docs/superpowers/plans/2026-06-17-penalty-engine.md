# Penalty Engine Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the single-shot penalty engine in `GameCore` — resolve one penalty (shot + keeper dive → goal/save/miss) in an abstract goal-coordinate space, plus the keeper and shooter AIs (difficulty scales with strength) and the interactive shootout scorer — all pure, seeded logic verified with `swift test`.

**Architecture:** Extends the pure-Swift `GameCore` package. The goal is modelled as a coordinate space: x in [-1, 1] (left post to right post), y in [0, 1] (ground to crossbar). A `Shot` is aim + power + curve; power adds random spread (risk/reward); the keeper saves if it covers the landing spot. Randomness flows through the existing `SeededGenerator` so every outcome is deterministic and testable. No SpriteKit/SwiftUI — the gameplay scene (next plan) maps a swipe to a `Shot`/`KeeperDive` and renders the returned outcome.

**Tech Stack:** Swift 5.9+, Swift Package Manager, XCTest. Builds on `SeededGenerator`, `Nation`.

---

## File Structure

```
GameCore/Sources/GameCore/
├── Models/
│   ├── PenaltyOutcome.swift   # goal | saved | miss
│   ├── Shot.swift             # aimX, aimY, power, curve
│   └── KeeperDive.swift       # x (commit direction)
└── Penalty/
    ├── PenaltyEngine.swift    # resolve(shot:keeper:using:) -> PenaltyOutcome
    ├── KeeperAI.swift         # dive(strength:against:using:) -> KeeperDive
    ├── ShooterAI.swift        # shoot(strength:using:) -> Shot
    └── ShootoutScorer.swift   # interactive shootout rules (5 + sudden death)
```

**Responsibilities:**
- `PenaltyOutcome` — the three results of a penalty.
- `Shot` — where the shooter aims (`aimX` −1…1, `aimY` 0…1), how hard (`power` 0…1), and lateral bend (`curve` −1…1).
- `KeeperDive` — the keeper's horizontal commit `x` (−1…1).
- `PenaltyEngine` — pure resolution. Computes the landing spot (aim + curve + power-scaled spread), returns `.miss` if off-frame, `.saved` if the keeper covers it, else `.goal`. Always consumes exactly two RNG draws so sequencing is stable.
- `KeeperAI` — produces a dive. A stronger keeper "reads" the shot (dives toward it) with a probability rising with strength; otherwise it guesses a side. This is the difficulty knob the player faces when attacking.
- `ShooterAI` — produces the opponent's shot when the player is the keeper. A stronger shooter places wider and higher with controlled power (less spread), so it scores more.
- `ShootoutScorer` — tallies both sides' kicks and decides when a shootout is won (five kicks each, then sudden death).

**Coordinate model and tuning constants** (defined once, on `PenaltyEngine`):
- `curveFactor = 0.25` — max lateral shift from full curve.
- `maxSpread = 0.35` — max random deviation at full power.
- `keeperReach = 0.40` — half-width the keeper covers around its dive x.
- `keeperVerticalReach = 0.70` — shots above this height beat the keeper (top corners).

**Documented simplifications (v1):**
- The keeper "reads" the committed shot with strength-based probability. This models difficulty fairly: the scene commits the player's swipe first, then computes the keeper's reaction. The player does not see the dive before committing.
- `ShootoutScorer` does not early-terminate regulation when a result is mathematically certain (e.g. 4-0 after eight kicks); both sides always take their five regulation kicks, then sudden death begins. Matches `MatchSimulator`'s model.

---

## Task 1: Penalty models (PenaltyOutcome, Shot, KeeperDive)

**Files:**
- Create: `GameCore/Sources/GameCore/Models/PenaltyOutcome.swift`
- Create: `GameCore/Sources/GameCore/Models/Shot.swift`
- Create: `GameCore/Sources/GameCore/Models/KeeperDive.swift`
- Test: `GameCore/Tests/GameCoreTests/PenaltyModelsTests.swift`

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/PenaltyModelsTests.swift`:

```swift
import XCTest
@testable import GameCore

final class PenaltyModelsTests: XCTestCase {
    func testShotStoresComponents() {
        let shot = Shot(aimX: 0.3, aimY: 0.5, power: 0.8, curve: -0.2)
        XCTAssertEqual(shot.aimX, 0.3)
        XCTAssertEqual(shot.aimY, 0.5)
        XCTAssertEqual(shot.power, 0.8)
        XCTAssertEqual(shot.curve, -0.2)
    }

    func testKeeperDiveStoresX() {
        XCTAssertEqual(KeeperDive(x: -0.6).x, -0.6)
    }

    func testOutcomeIsCodable() throws {
        let data = try JSONEncoder().encode(PenaltyOutcome.goal)
        let decoded = try JSONDecoder().decode(PenaltyOutcome.self, from: data)
        XCTAssertEqual(decoded, .goal)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter PenaltyModelsTests`
Expected: FAIL — "cannot find 'Shot' in scope".

- [ ] **Step 3: Write the models**

`GameCore/Sources/GameCore/Models/PenaltyOutcome.swift`:

```swift
/// The result of a single penalty.
public enum PenaltyOutcome: String, Codable, Equatable {
    case goal
    case saved
    case miss
}
```

`GameCore/Sources/GameCore/Models/Shot.swift`:

```swift
/// A penalty shot in goal-coordinate space.
/// `aimX` −1 (left post) … 1 (right post); `aimY` 0 (ground) … 1 (crossbar);
/// `power` 0 … 1 (more power = more spread); `curve` −1 … 1 lateral bend.
public struct Shot: Equatable {
    public let aimX: Double
    public let aimY: Double
    public let power: Double
    public let curve: Double

    public init(aimX: Double, aimY: Double, power: Double, curve: Double) {
        self.aimX = aimX
        self.aimY = aimY
        self.power = power
        self.curve = curve
    }
}
```

`GameCore/Sources/GameCore/Models/KeeperDive.swift`:

```swift
/// The keeper's horizontal commit, `x` −1 (left) … 1 (right).
public struct KeeperDive: Equatable {
    public let x: Double

    public init(x: Double) {
        self.x = x
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter PenaltyModelsTests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Models/PenaltyOutcome.swift GameCore/Sources/GameCore/Models/Shot.swift GameCore/Sources/GameCore/Models/KeeperDive.swift GameCore/Tests/GameCoreTests/PenaltyModelsTests.swift
git commit -m "feat: add penalty models (outcome, shot, keeper dive)"
```

---

## Task 2: PenaltyEngine.resolve

**Files:**
- Create: `GameCore/Sources/GameCore/Penalty/PenaltyEngine.swift`
- Test: `GameCore/Tests/GameCoreTests/PenaltyEngineTests.swift`

At `power = 0` there is no spread, so landing equals aim plus curve — this makes
the placement tests below fully deterministic without depending on the RNG.

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/PenaltyEngineTests.swift`:

```swift
import XCTest
@testable import GameCore

final class PenaltyEngineTests: XCTestCase {
    private func resolve(_ shot: Shot, _ keeper: KeeperDive, seed: UInt64 = 1) -> PenaltyOutcome {
        var g = SeededGenerator(seed: seed)
        return PenaltyEngine.resolve(shot: shot, keeper: keeper, using: &g)
    }

    func testKeeperSavesCenteredLowShotWhenCovering() {
        // power 0 -> lands exactly at aim (0, 0.3); keeper centered covers it.
        let shot = Shot(aimX: 0, aimY: 0.3, power: 0, curve: 0)
        XCTAssertEqual(resolve(shot, KeeperDive(x: 0)), .saved)
    }

    func testGoalWhenKeeperDivesWrongWay() {
        let shot = Shot(aimX: 0, aimY: 0.3, power: 0, curve: 0)
        XCTAssertEqual(resolve(shot, KeeperDive(x: 0.9)), .goal)
    }

    func testTopShotBeatsCenteredKeeper() {
        // High shot (y 0.95) is above the keeper's vertical reach.
        let shot = Shot(aimX: 0, aimY: 0.95, power: 0, curve: 0)
        XCTAssertEqual(resolve(shot, KeeperDive(x: 0)), .goal)
    }

    func testWideViaCurveIsMiss() {
        // aimX 0.95 + full curve (0.25) = 1.2 -> outside the right post.
        let shot = Shot(aimX: 0.95, aimY: 0.3, power: 0, curve: 1)
        XCTAssertEqual(resolve(shot, KeeperDive(x: 0)), .miss)
    }

    func testDeterministicForSeed() {
        let shot = Shot(aimX: 0.2, aimY: 0.5, power: 1, curve: 0.1)
        XCTAssertEqual(resolve(shot, KeeperDive(x: 0), seed: 77),
                       resolve(shot, KeeperDive(x: 0), seed: 77))
    }

    func testHighPowerCanSprayOffTarget() {
        // A near-post max-power shot misses for at least one seed (spread).
        let shot = Shot(aimX: 0.98, aimY: 0.5, power: 1, curve: 0)
        let anyMiss = (UInt64(1)...200).contains { resolve(shot, KeeperDive(x: -0.9), seed: $0) == .miss }
        XCTAssertTrue(anyMiss)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter PenaltyEngineTests`
Expected: FAIL — "cannot find 'PenaltyEngine' in scope".

- [ ] **Step 3: Write the engine**

`GameCore/Sources/GameCore/Penalty/PenaltyEngine.swift`:

```swift
/// Resolves a single penalty in goal-coordinate space.
public enum PenaltyEngine {
    /// Max lateral shift produced by full curve.
    static let curveFactor = 0.25
    /// Max random deviation at full power (risk/reward of power).
    static let maxSpread = 0.35
    /// Half-width the keeper covers around its dive x.
    static let keeperReach = 0.40
    /// Shots above this height beat the keeper (top corners).
    static let keeperVerticalReach = 0.70

    public static func resolve(shot: Shot, keeper: KeeperDive,
                               using rng: inout SeededGenerator) -> PenaltyOutcome {
        // Always consume two draws so RNG sequencing is stable regardless of power.
        let noiseX = (rng.nextUnit() * 2 - 1) * shot.power * maxSpread
        let noiseY = (rng.nextUnit() * 2 - 1) * shot.power * maxSpread

        let landingX = shot.aimX + shot.curve * curveFactor + noiseX
        let landingY = shot.aimY + noiseY

        // Off the frame (wide, over, or into the ground) -> miss.
        if landingX < -1 || landingX > 1 || landingY < 0 || landingY > 1 {
            return .miss
        }
        // Keeper saves if it covers the landing spot horizontally and can reach the height.
        if abs(landingX - keeper.x) <= keeperReach && landingY <= keeperVerticalReach {
            return .saved
        }
        return .goal
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter PenaltyEngineTests`
Expected: PASS (all six).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Penalty/PenaltyEngine.swift GameCore/Tests/GameCoreTests/PenaltyEngineTests.swift
git commit -m "feat: add PenaltyEngine resolve"
```

---

## Task 3: KeeperAI

**Files:**
- Create: `GameCore/Sources/GameCore/Penalty/KeeperAI.swift`
- Test: `GameCore/Tests/GameCoreTests/KeeperAITests.swift`

A stronger keeper "reads" the shot (dives toward its horizontal target) with a
probability of `(strength/100) * maxReadChance`; otherwise it guesses a random
side. The difficulty test pairs `KeeperAI` with `PenaltyEngine` and confirms a
99-strength keeper saves clearly more than a 0-strength keeper.

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/KeeperAITests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter KeeperAITests`
Expected: FAIL — "cannot find 'KeeperAI' in scope".

- [ ] **Step 3: Write the keeper AI**

`GameCore/Sources/GameCore/Penalty/KeeperAI.swift`:

```swift
/// Chooses the keeper's dive. Stronger keepers read the shot more often.
public enum KeeperAI {
    /// The best keeper reads the shot this fraction of the time.
    static let maxReadChance = 0.75

    public static func dive(strength: Int, against shot: Shot,
                            using rng: inout SeededGenerator) -> KeeperDive {
        let readChance = (Double(strength) / 100.0) * maxReadChance
        if rng.nextUnit() < readChance {
            // Reads it: dive toward where the shot is actually heading.
            let target = shot.aimX + shot.curve * PenaltyEngine.curveFactor
            return KeeperDive(x: min(1.0, max(-1.0, target)))
        }
        // Guesses a random side.
        return KeeperDive(x: rng.nextUnit() * 2 - 1)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter KeeperAITests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Penalty/KeeperAI.swift GameCore/Tests/GameCoreTests/KeeperAITests.swift
git commit -m "feat: add KeeperAI with strength-based reading"
```

---

## Task 4: ShooterAI

**Files:**
- Create: `GameCore/Sources/GameCore/Penalty/ShooterAI.swift`
- Test: `GameCore/Tests/GameCoreTests/ShooterAITests.swift`

The opponent's shot when the player keeps. A stronger shooter places wider
(toward the corner, beyond the keeper's reach) and higher, with controlled
power (so less spread). The strength test fires against a centered keeper and
confirms a 99-strength shooter scores clearly more than a 5-strength shooter.

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/ShooterAITests.swift`:

```swift
import XCTest
@testable import GameCore

final class ShooterAITests: XCTestCase {
    func testShotComponentsInRange() {
        for seed in UInt64(1)...300 {
            var g = SeededGenerator(seed: seed)
            let shot = ShooterAI.shoot(strength: 60, using: &g)
            XCTAssertGreaterThanOrEqual(shot.aimX, -1.0)
            XCTAssertLessThanOrEqual(shot.aimX, 1.0)
            XCTAssertGreaterThanOrEqual(shot.aimY, 0.0)
            XCTAssertLessThanOrEqual(shot.aimY, 1.0)
            XCTAssertGreaterThanOrEqual(shot.power, 0.0)
            XCTAssertLessThanOrEqual(shot.power, 1.0)
        }
    }

    func testDeterministicForSeed() {
        var a = SeededGenerator(seed: 9)
        var b = SeededGenerator(seed: 9)
        XCTAssertEqual(ShooterAI.shoot(strength: 70, using: &a),
                       ShooterAI.shoot(strength: 70, using: &b))
    }

    func testStrongShooterScoresMoreThanWeak() {
        func goals(strength: Int) -> Int {
            var count = 0
            for seed in UInt64(1)...400 {
                var g = SeededGenerator(seed: seed)
                let shot = ShooterAI.shoot(strength: strength, using: &g)
                if PenaltyEngine.resolve(shot: shot, keeper: KeeperDive(x: 0), using: &g) == .goal {
                    count += 1
                }
            }
            return count
        }
        let strong = goals(strength: 99)
        let weak = goals(strength: 5)
        XCTAssertGreaterThan(strong, weak)
        XCTAssertGreaterThan(strong, 200)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter ShooterAITests`
Expected: FAIL — "cannot find 'ShooterAI' in scope".

- [ ] **Step 3: Write the shooter AI**

`GameCore/Sources/GameCore/Penalty/ShooterAI.swift`:

```swift
/// Chooses the opponent's penalty when the player is the keeper.
/// Stronger shooters place wider and higher with controlled power.
public enum ShooterAI {
    public static func shoot(strength: Int, using rng: inout SeededGenerator) -> Shot {
        let skill = Double(strength) / 100.0
        let side: Double = rng.nextUnit() < 0.5 ? -1.0 : 1.0
        // Placement away from center grows with skill (0 = center, ~0.6 = corner).
        let placement = (0.45 + 0.15 * rng.nextUnit()) * skill
        let aimX = min(1.0, max(-1.0, side * placement))
        let aimY = min(1.0, max(0.0, 0.3 + 0.4 * skill))
        // Lower power = less spread; weak shooters are slightly wilder.
        let power = min(1.0, max(0.0, 0.3 + 0.3 * skill))
        return Shot(aimX: aimX, aimY: aimY, power: power, curve: 0)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter ShooterAITests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Penalty/ShooterAI.swift GameCore/Tests/GameCoreTests/ShooterAITests.swift
git commit -m "feat: add ShooterAI with strength-based placement"
```

---

## Task 5: ShootoutScorer

**Files:**
- Create: `GameCore/Sources/GameCore/Penalty/ShootoutScorer.swift`
- Test: `GameCore/Tests/GameCoreTests/ShootoutScorerTests.swift`

Rules: each side takes five regulation kicks, then sudden-death pairs. The
shootout is decided once both sides have taken the same number of kicks
(at least five) and the scores differ. (Regulation is not cut short early — a
documented v1 simplification.)

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/ShootoutScorerTests.swift`:

```swift
import XCTest
@testable import GameCore

final class ShootoutScorerTests: XCTestCase {
    private func take(_ s: inout ShootoutScorer, home: [Bool], away: [Bool]) {
        // Alternating home then away, per kick index.
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
        take(&s, home: [true, true, true, false, false],   // 3
                away: [true, false, true, false, false])   // 2
        XCTAssertTrue(s.isDecided)
        XCTAssertEqual(s.winner, .home)
    }

    func testTiedAfterRegulationIsNotDecided() {
        var s = ShootoutScorer()
        take(&s, home: [true, true, true, false, false],   // 3
                away: [true, true, true, false, false])    // 3
        XCTAssertFalse(s.isDecided)
        XCTAssertNil(s.winner)
    }

    func testSuddenDeathDecidesOnUnequalPair() {
        var s = ShootoutScorer()
        take(&s, home: [true, true, true, false, false],   // 3 after 5
                away: [true, true, true, false, false])    // 3 after 5
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter ShootoutScorerTests`
Expected: FAIL — "cannot find 'ShootoutScorer' in scope".

- [ ] **Step 3: Write the scorer**

`GameCore/Sources/GameCore/Penalty/ShootoutScorer.swift`:

```swift
/// Tracks an interactive penalty shootout and decides the winner.
/// Five regulation kicks per side, then sudden-death pairs. Decided once both
/// sides have taken the same number of kicks (>= 5) and the scores differ.
public struct ShootoutScorer: Equatable {
    public enum Side { case home, away }

    public private(set) var homeScored = 0
    public private(set) var awayScored = 0
    public private(set) var homeTaken = 0
    public private(set) var awayTaken = 0

    /// Number of regulation kicks each side takes before sudden death.
    public static let regulationKicks = 5

    public init() {}

    public mutating func record(side: Side, scored: Bool) {
        switch side {
        case .home:
            homeTaken += 1
            if scored { homeScored += 1 }
        case .away:
            awayTaken += 1
            if scored { awayScored += 1 }
        }
    }

    public var isDecided: Bool {
        homeTaken == awayTaken
            && homeTaken >= Self.regulationKicks
            && homeScored != awayScored
    }

    public var winner: Side? {
        guard isDecided else { return nil }
        return homeScored > awayScored ? .home : .away
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter ShootoutScorerTests`
Expected: PASS (all five).

- [ ] **Step 5: Run the full suite**

Run: `cd GameCore && swift test`
Expected: every test across the package PASSES.

- [ ] **Step 6: Commit**

```bash
git add GameCore/Sources/GameCore/Penalty/ShootoutScorer.swift GameCore/Tests/GameCoreTests/ShootoutScorerTests.swift
git commit -m "feat: add ShootoutScorer interactive shootout rules"
```

---

## Done criteria

- `cd GameCore && swift test` builds and passes every test.
- `GameCore` still imports only `Foundation` (no SpriteKit/UIKit/SwiftUI).
- `PenaltyEngine.resolve` returns goal/save/miss deterministically for a seed, with
  power adding spread (risk/reward) and top shots beating the keeper.
- `KeeperAI` makes stronger keepers save more; `ShooterAI` makes stronger shooters
  score more — both verified by paired statistical tests against the engine.
- `ShootoutScorer` correctly decides regulation and sudden-death outcomes.

## What this plan deliberately leaves out

- SpriteKit `PenaltyScene`, swipe-to-`Shot` mapping, animations, and rendering → next plan (Gameplay). The scene drives this engine: it builds a `Shot` from the player's swipe (or a `KeeperDive` when defending), calls `KeeperAI`/`ShooterAI` for the opponent, calls `PenaltyEngine.resolve`, feeds the result to `ShootoutScorer`, and renders the outcome.
- SwiftUI app shell, `TournamentState` save model, Game Center, audio → later plans.
