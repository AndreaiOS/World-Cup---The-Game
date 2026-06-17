# Tournament Core Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the data-driven tournament core in `GameCore` — the real WC2026 48-nation/12-group dataset, a deterministic match simulator, group standings + qualification (top 2 + 8 best thirds), the knockout bracket, and total-score scoring — all pure logic verified with `swift test`.

**Architecture:** Extends the existing pure-Swift `GameCore` SPM package (Plan 1). All new types depend only on `Foundation`. Randomness is injected through a seeded generator so every simulation is deterministic and testable. The penalty *gameplay* engine (single-shot physics) is a separate follow-up plan; here a shootout result is produced statistically by `MatchSimulator`, which is what the "simulate the other matches" and "resolve a match the player isn't playing" paths need.

**Tech Stack:** Swift 5.9+, Swift Package Manager, XCTest, `Codable`. Builds on Plan 1 (`Nation`, `Stage`, `MatchResult`, `DataStore`, `SaveStore`).

---

## File Structure

```
GameCore/Sources/GameCore/
├── Random/
│   └── SeededGenerator.swift     # deterministic RNG (RandomNumberGenerator)
├── Models/
│   ├── Group.swift               # a group: id + 4 nation ids
│   ├── GroupStanding.swift       # one row of a group table
│   ├── Qualifier.swift           # a nation that advanced, with seeding stats
│   ├── BracketMatch.swift        # one knockout pairing (home vs away)
│   └── TournamentStats.swift     # aggregate player stats for scoring
├── Logic/
│   ├── MatchSimulator.swift      # two nations -> MatchResult (seeded)
│   ├── GroupTable.swift          # round-robin pairs, standings, qualifiers
│   ├── KnockoutBracket.swift     # build Round of 32, advance rounds
│   └── ScoreCalculator.swift     # TournamentStats -> total score
└── Data/
    ├── DataStore.swift           # MODIFIED: add loadGroups()
    └── Resources/
        ├── nations.json          # MODIFIED: expand seed -> full 48 nations
        └── groups.json           # NEW: the 12 real groups
```

**Responsibilities:**
- `SeededGenerator` — deterministic `RandomNumberGenerator` (SplitMix64) plus a `nextUnit()` helper returning a `Double` in `[0, 1)`. Single source of randomness for all simulation.
- `Group` — a group's id (`"A"`…`"L"`) and its four nation ids.
- `GroupStanding` — one nation's record within a group (played/wins/losses/goals), with computed `points` and `goalDifference`. No draws (shootouts always have a winner).
- `Qualifier` — a nation that advanced, carrying the stats needed to seed the bracket.
- `BracketMatch` — a single knockout pairing.
- `TournamentStats` — the player's aggregate run stats fed to scoring.
- `MatchSimulator` — given two nations and a seeded generator, produces a non-tie `MatchResult` biased by strength.
- `GroupTable` — round-robin fixture pairs, group standings, and qualification (top 2 + best 8 thirds).
- `KnockoutBracket` — build the Round of 32 from qualifiers (deterministic seeding) and advance one round to the next.
- `ScoreCalculator` — turn `TournamentStats` into a single Game Center score.
- `DataStore.loadGroups()` — load `groups.json`.

**Documented simplifications (faithful in spirit, tractable to build):**
- The official FIFA Round-of-32 slotting table (which specific third-placed teams land in which slots) is replaced by a deterministic seeded bracket: all 32 qualifiers are ranked (winners above runners-up above thirds; then by points, goal difference, goals for) and paired seed 1 vs 32, 2 vs 31, … This produces a valid 32→16→8→4→2 single-elimination bracket where stronger finishers meet later. Real groups and the real top-2 + best-8-thirds qualification counts are preserved.
- A shootout is simulated as five kicks per side plus sudden death, each kick converted with a strength-derived probability. `MatchSimulator` guarantees the scores are never equal, upholding the no-tie invariant that `MatchResult` documents but does not enforce.

---

## Task 1: SeededGenerator (deterministic RNG)

**Files:**
- Create: `GameCore/Sources/GameCore/Random/SeededGenerator.swift`
- Test: `GameCore/Tests/GameCoreTests/SeededGeneratorTests.swift`

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/SeededGeneratorTests.swift`:

```swift
import XCTest
@testable import GameCore

final class SeededGeneratorTests: XCTestCase {
    func testSameSeedProducesSameSequence() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        let seqA = (0..<5).map { _ in a.next() }
        let seqB = (0..<5).map { _ in b.next() }
        XCTAssertEqual(seqA, seqB)
    }

    func testDifferentSeedsDiffer() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func testNextUnitIsInZeroToOne() {
        var g = SeededGenerator(seed: 7)
        for _ in 0..<1000 {
            let u = g.nextUnit()
            XCTAssertGreaterThanOrEqual(u, 0.0)
            XCTAssertLessThan(u, 1.0)
        }
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter SeededGeneratorTests`
Expected: FAIL — "cannot find 'SeededGenerator' in scope".

- [ ] **Step 3: Write the generator**

`GameCore/Sources/GameCore/Random/SeededGenerator.swift`:

```swift
/// Deterministic pseudo-random generator (SplitMix64).
/// Injected wherever simulation needs randomness so tests are repeatable.
public struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    public init(seed: UInt64) {
        // Avoid the all-zero state, which would weaken the first outputs.
        self.state = seed != 0 ? seed : 0x9E37_79B9_7F4A_7C15
    }

    public mutating func next() -> UInt64 {
        state = state &+ 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A Double in [0, 1) using the top 53 bits (full mantissa precision).
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) * (1.0 / 9_007_199_254_740_992.0)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter SeededGeneratorTests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Random GameCore/Tests/GameCoreTests/SeededGeneratorTests.swift
git commit -m "feat: add SeededGenerator deterministic RNG"
```

---

## Task 2: Group and GroupStanding models

**Files:**
- Create: `GameCore/Sources/GameCore/Models/Group.swift`
- Create: `GameCore/Sources/GameCore/Models/GroupStanding.swift`
- Test: `GameCore/Tests/GameCoreTests/GroupModelTests.swift`

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/GroupModelTests.swift`:

```swift
import XCTest
@testable import GameCore

final class GroupModelTests: XCTestCase {
    func testGroupDecodes() throws {
        let json = """
        { "id": "A", "nationIds": ["MEX", "CAN", "USA", "ITA"] }
        """.data(using: .utf8)!
        let group = try JSONDecoder().decode(Group.self, from: json)
        XCTAssertEqual(group.id, "A")
        XCTAssertEqual(group.nationIds.count, 4)
        XCTAssertEqual(group.nationIds.first, "MEX")
    }

    func testStandingComputesPointsAndDifference() {
        let s = GroupStanding(nationId: "ITA", played: 3, wins: 2, losses: 1,
                              goalsFor: 9, goalsAgainst: 6)
        XCTAssertEqual(s.points, 6)            // wins * 3, no draws
        XCTAssertEqual(s.goalDifference, 3)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter GroupModelTests`
Expected: FAIL — "cannot find 'Group' in scope".

- [ ] **Step 3: Write the models**

`GameCore/Sources/GameCore/Models/Group.swift`:

```swift
/// A first-round group: four nations identified by id.
public struct Group: Codable, Equatable, Identifiable {
    public let id: String          // "A" ... "L"
    public let nationIds: [String] // exactly four nation ids

    public init(id: String, nationIds: [String]) {
        self.id = id
        self.nationIds = nationIds
    }
}
```

`GameCore/Sources/GameCore/Models/GroupStanding.swift`:

```swift
/// One nation's record within a group. Shootouts never tie, so there are
/// no draws: points are simply wins * 3.
public struct GroupStanding: Equatable {
    public let nationId: String
    public var played: Int
    public var wins: Int
    public var losses: Int
    public var goalsFor: Int
    public var goalsAgainst: Int

    public init(nationId: String, played: Int = 0, wins: Int = 0, losses: Int = 0,
                goalsFor: Int = 0, goalsAgainst: Int = 0) {
        self.nationId = nationId
        self.played = played
        self.wins = wins
        self.losses = losses
        self.goalsFor = goalsFor
        self.goalsAgainst = goalsAgainst
    }

    public var points: Int { wins * 3 }
    public var goalDifference: Int { goalsFor - goalsAgainst }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter GroupModelTests`
Expected: PASS (both).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Models/Group.swift GameCore/Sources/GameCore/Models/GroupStanding.swift GameCore/Tests/GameCoreTests/GroupModelTests.swift
git commit -m "feat: add Group and GroupStanding models"
```

---

## Task 3: MatchSimulator

**Files:**
- Create: `GameCore/Sources/GameCore/Logic/MatchSimulator.swift`
- Test: `GameCore/Tests/GameCoreTests/MatchSimulatorTests.swift`

Design: each side takes five kicks; each kick is converted with probability
`0.55 + 0.40 * (strength / 100)` (range ~0.55–0.95). If level after five, play
sudden-death rounds (one kick each) until a round is decisive, capped at 50
rounds; if still level (vanishingly unlikely), the higher strength wins, ties
broken toward the home nation. The result is guaranteed non-tie.

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/MatchSimulatorTests.swift`:

```swift
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
        // A 99 vs 5 mismatch should win clearly more than half the time.
        XCTAssertGreaterThan(strongWins, 350)
    }

    func testResultCarriesNationIds() {
        var g = SeededGenerator(seed: 9)
        let r = MatchSimulator.simulate(home: strong, away: weak, using: &g)
        XCTAssertEqual(r.homeId, "STR")
        XCTAssertEqual(r.awayId, "WEK")
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter MatchSimulatorTests`
Expected: FAIL — "cannot find 'MatchSimulator' in scope".

- [ ] **Step 3: Write the simulator**

`GameCore/Sources/GameCore/Logic/MatchSimulator.swift`:

```swift
/// Simulates a penalty shootout between two nations. Used for every match the
/// player does not play in person. Strength biases conversion. The returned
/// MatchResult is always non-tie, upholding the shootout invariant.
public enum MatchSimulator {

    private static func conversionProbability(strength: Int) -> Double {
        0.55 + 0.40 * (Double(strength) / 100.0)
    }

    private static func kicks(count: Int, strength: Int,
                              using rng: inout SeededGenerator) -> Int {
        let p = conversionProbability(strength: strength)
        var made = 0
        for _ in 0..<count where rng.nextUnit() < p { made += 1 }
        return made
    }

    public static func simulate(home: Nation, away: Nation,
                                using rng: inout SeededGenerator) -> MatchResult {
        var homeScore = kicks(count: 5, strength: home.strength, using: &rng)
        var awayScore = kicks(count: 5, strength: away.strength, using: &rng)

        let homeP = conversionProbability(strength: home.strength)
        let awayP = conversionProbability(strength: away.strength)

        var rounds = 0
        while homeScore == awayScore && rounds < 50 {
            let homeMade = rng.nextUnit() < homeP
            let awayMade = rng.nextUnit() < awayP
            if homeMade { homeScore += 1 }
            if awayMade { awayScore += 1 }
            rounds += 1
        }

        if homeScore == awayScore {
            // Vanishingly unlikely: decide deterministically, never a tie.
            if home.strength >= away.strength { homeScore += 1 } else { awayScore += 1 }
        }

        return MatchResult(homeId: home.id, awayId: away.id,
                           homeScore: homeScore, awayScore: awayScore)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter MatchSimulatorTests`
Expected: PASS (all four).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Logic/MatchSimulator.swift GameCore/Tests/GameCoreTests/MatchSimulatorTests.swift
git commit -m "feat: add MatchSimulator with deterministic shootouts"
```

---

## Task 4: GroupTable — round-robin pairs and standings

**Files:**
- Create: `GameCore/Sources/GameCore/Logic/GroupTable.swift`
- Test: `GameCore/Tests/GameCoreTests/GroupTableTests.swift`

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/GroupTableTests.swift`:

```swift
import XCTest
@testable import GameCore

final class GroupTableTests: XCTestCase {
    func testRoundRobinProducesSixUniquePairs() {
        let pairs = GroupTable.roundRobinPairs(["A", "B", "C", "D"])
        XCTAssertEqual(pairs.count, 6)
        let normalized = Set(pairs.map { [$0.0, $0.1].sorted().joined(separator: "-") })
        XCTAssertEqual(normalized.count, 6)
    }

    func testStandingsAccumulateResults() {
        let ids = ["A", "B", "C", "D"]
        // A beats B 4-3, A beats C 5-2, A loses to D 1-2
        let results = [
            MatchResult(homeId: "A", awayId: "B", homeScore: 4, awayScore: 3),
            MatchResult(homeId: "A", awayId: "C", homeScore: 5, awayScore: 2),
            MatchResult(homeId: "D", awayId: "A", homeScore: 2, awayScore: 1),
        ]
        let table = GroupTable.standings(nationIds: ids, results: results)
        let a = table.first { $0.nationId == "A" }!
        XCTAssertEqual(a.played, 3)
        XCTAssertEqual(a.wins, 2)
        XCTAssertEqual(a.losses, 1)
        XCTAssertEqual(a.goalsFor, 10)      // 4 + 5 + 1
        XCTAssertEqual(a.goalsAgainst, 7)   // 3 + 2 + 2
        XCTAssertEqual(a.points, 6)
    }

    func testStandingsSortedByPointsThenDifference() {
        let ids = ["A", "B", "C", "D"]
        let results = [
            MatchResult(homeId: "A", awayId: "B", homeScore: 5, awayScore: 0), // A win, +5
            MatchResult(homeId: "C", awayId: "D", homeScore: 3, awayScore: 2), // C win, +1
            MatchResult(homeId: "A", awayId: "C", homeScore: 1, awayScore: 2), // C win, A loss
        ]
        // A: 1 win (+? ) ... ensure C (2 wins) is above A (1 win)
        let table = GroupTable.standings(nationIds: ids, results: results)
        XCTAssertEqual(table.first?.nationId, "C")     // 6 pts
        XCTAssertEqual(table.map { $0.nationId }.firstIndex(of: "A"), 1) // next
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter GroupTableTests`
Expected: FAIL — "cannot find 'GroupTable' in scope".

- [ ] **Step 3: Write GroupTable (pairs + standings)**

`GameCore/Sources/GameCore/Logic/GroupTable.swift`:

```swift
/// Group-stage computations: fixtures, standings, and qualification.
public enum GroupTable {

    /// All unique unordered pairings of the given ids (round robin).
    public static func roundRobinPairs(_ ids: [String]) -> [(String, String)] {
        var pairs: [(String, String)] = []
        for i in 0..<ids.count {
            for j in (i + 1)..<ids.count {
                pairs.append((ids[i], ids[j]))
            }
        }
        return pairs
    }

    /// Build the sorted table for a group from its played results.
    /// Sort: points, then goal difference, then goals for, then id (stable).
    public static func standings(nationIds: [String],
                                 results: [MatchResult]) -> [GroupStanding] {
        var byId: [String: GroupStanding] = [:]
        for id in nationIds { byId[id] = GroupStanding(nationId: id) }

        for r in results {
            guard var home = byId[r.homeId], var away = byId[r.awayId] else { continue }
            home.played += 1; away.played += 1
            home.goalsFor += r.homeScore; home.goalsAgainst += r.awayScore
            away.goalsFor += r.awayScore; away.goalsAgainst += r.homeScore
            if r.homeScore >= r.awayScore { home.wins += 1; away.losses += 1 }
            else { away.wins += 1; home.losses += 1 }
            byId[r.homeId] = home; byId[r.awayId] = away
        }

        return byId.values.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.goalDifference != rhs.goalDifference {
                return lhs.goalDifference > rhs.goalDifference
            }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.nationId < rhs.nationId
        }
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter GroupTableTests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Logic/GroupTable.swift GameCore/Tests/GameCoreTests/GroupTableTests.swift
git commit -m "feat: add GroupTable round-robin pairs and standings"
```

---

## Task 5: Qualifier model and qualification logic

**Files:**
- Create: `GameCore/Sources/GameCore/Models/Qualifier.swift`
- Modify: `GameCore/Sources/GameCore/Logic/GroupTable.swift` (add `qualifiers`)
- Test: `GameCore/Tests/GameCoreTests/QualificationTests.swift`

Qualification: top two of every group qualify, plus the eight best third-placed
nations across all groups (ranked by points, goal difference, goals for, id).

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/QualificationTests.swift`:

```swift
import XCTest
@testable import GameCore

final class QualificationTests: XCTestCase {
    // Build 12 groups of 4 with deterministic results so finishing order is known.
    private func makeGroups() -> [Group] {
        (0..<12).map { i in
            let letter = String(UnicodeScalar(65 + i)!) // A...L
            let ids = (0..<4).map { "\(letter)\($0)" }   // e.g. A0,A1,A2,A3
            return Group(id: letter, nationIds: ids)
        }
    }

    // In each group, seed results so that x0 > x1 > x2 > x3.
    private func makeResults(_ groups: [Group]) -> [MatchResult] {
        var results: [MatchResult] = []
        for g in groups {
            let p = GroupTable.roundRobinPairs(g.nationIds)
            for (home, away) in p {
                // lower suffix index is stronger -> it wins
                let hi = Int(home.suffix(1))!, ai = Int(away.suffix(1))!
                if hi < ai {
                    results.append(MatchResult(homeId: home, awayId: away,
                                               homeScore: 4 - hi, awayScore: 0))
                } else {
                    results.append(MatchResult(homeId: home, awayId: away,
                                               homeScore: 0, awayScore: 4 - ai))
                }
            }
        }
        return results
    }

    func testQualifiersCountIs32() {
        let groups = makeGroups()
        let results = makeResults(groups)
        let qs = GroupTable.qualifiers(groups: groups, results: results)
        XCTAssertEqual(qs.count, 32)
    }

    func testEveryGroupWinnerQualifiesFirst() {
        let groups = makeGroups()
        let results = makeResults(groups)
        let qs = GroupTable.qualifiers(groups: groups, results: results)
        for g in groups {
            let winner = qs.first { $0.nationId == "\(g.id)0" }
            XCTAssertNotNil(winner)
            XCTAssertEqual(winner?.position, 1)
        }
    }

    func testExactlyEightThirdsQualify() {
        let groups = makeGroups()
        let results = makeResults(groups)
        let qs = GroupTable.qualifiers(groups: groups, results: results)
        let thirds = qs.filter { $0.position == 3 }
        XCTAssertEqual(thirds.count, 8)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter QualificationTests`
Expected: FAIL — "cannot find 'Qualifier' in scope" / "no member 'qualifiers'".

- [ ] **Step 3: Write the Qualifier model**

`GameCore/Sources/GameCore/Models/Qualifier.swift`:

```swift
/// A nation that advanced from the group stage, carrying the stats used to
/// seed the knockout bracket.
public struct Qualifier: Equatable {
    public let nationId: String
    public let groupId: String
    public let position: Int        // 1, 2, or 3 within its group
    public let points: Int
    public let goalDifference: Int
    public let goalsFor: Int

    public init(nationId: String, groupId: String, position: Int,
                points: Int, goalDifference: Int, goalsFor: Int) {
        self.nationId = nationId
        self.groupId = groupId
        self.position = position
        self.points = points
        self.goalDifference = goalDifference
        self.goalsFor = goalsFor
    }
}
```

- [ ] **Step 4: Add `qualifiers` to GroupTable**

Append this method inside the `GroupTable` enum in
`GameCore/Sources/GameCore/Logic/GroupTable.swift`:

```swift
    /// Top two of every group plus the eight best third-placed nations.
    /// Returns 32 qualifiers (24 + 8). Best thirds ranked by points, then
    /// goal difference, then goals for, then id.
    public static func qualifiers(groups: [Group],
                                  results: [MatchResult]) -> [Qualifier] {
        var advancing: [Qualifier] = []
        var thirds: [Qualifier] = []

        for group in groups {
            let table = standings(nationIds: group.nationIds, results: results)
            for (index, standing) in table.enumerated() {
                let q = Qualifier(nationId: standing.nationId, groupId: group.id,
                                  position: index + 1, points: standing.points,
                                  goalDifference: standing.goalDifference,
                                  goalsFor: standing.goalsFor)
                if index < 2 { advancing.append(q) }
                else if index == 2 { thirds.append(q) }
            }
        }

        let bestThirds = thirds.sorted { lhs, rhs in
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.goalDifference != rhs.goalDifference {
                return lhs.goalDifference > rhs.goalDifference
            }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.nationId < rhs.nationId
        }.prefix(8)

        return advancing + bestThirds
    }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd GameCore && swift test --filter QualificationTests`
Expected: PASS (all three).

- [ ] **Step 6: Commit**

```bash
git add GameCore/Sources/GameCore/Models/Qualifier.swift GameCore/Sources/GameCore/Logic/GroupTable.swift GameCore/Tests/GameCoreTests/QualificationTests.swift
git commit -m "feat: add qualification (top 2 + best 8 thirds)"
```

---

## Task 6: KnockoutBracket — build Round of 32 and advance rounds

**Files:**
- Create: `GameCore/Sources/GameCore/Models/BracketMatch.swift`
- Create: `GameCore/Sources/GameCore/Logic/KnockoutBracket.swift`
- Test: `GameCore/Tests/GameCoreTests/KnockoutBracketTests.swift`

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/KnockoutBracketTests.swift`:

```swift
import XCTest
@testable import GameCore

final class KnockoutBracketTests: XCTestCase {
    private func makeQualifiers() -> [Qualifier] {
        // 32 qualifiers, same position so seeding falls through to points:
        // N0 (100 pts) strongest ... N31 (69 pts) weakest. Order is deterministic.
        (0..<32).map { i in
            Qualifier(nationId: "N\(i)", groupId: "G", position: 1,
                      points: 100 - i, goalDifference: 0, goalsFor: 0)
        }
    }

    func testRoundOf32HasSixteenMatches() {
        let r32 = KnockoutBracket.buildRoundOf32(from: makeQualifiers())
        XCTAssertEqual(r32.count, 16)
    }

    func testTopSeedFacesBottomSeed() {
        let qs = makeQualifiers()                  // N0 strongest, N31 weakest
        let r32 = KnockoutBracket.buildRoundOf32(from: qs)
        XCTAssertEqual(r32.first?.homeId, "N0")
        XCTAssertEqual(r32.first?.awayId, "N31")
    }

    func testNextRoundPairsConsecutiveWinners() {
        let matches = [
            BracketMatch(homeId: "A", awayId: "B"),
            BracketMatch(homeId: "C", awayId: "D"),
            BracketMatch(homeId: "E", awayId: "F"),
            BracketMatch(homeId: "G", awayId: "H"),
        ]
        let results = [
            MatchResult(homeId: "A", awayId: "B", homeScore: 3, awayScore: 1), // A
            MatchResult(homeId: "C", awayId: "D", homeScore: 1, awayScore: 2), // D
            MatchResult(homeId: "E", awayId: "F", homeScore: 5, awayScore: 4), // E
            MatchResult(homeId: "G", awayId: "H", homeScore: 0, awayScore: 2), // H
        ]
        let next = KnockoutBracket.nextRound(from: matches, results: results)
        XCTAssertEqual(next, [
            BracketMatch(homeId: "A", awayId: "D"),
            BracketMatch(homeId: "E", awayId: "H"),
        ])
    }

    func testFullBracketReducesToOneWinner() {
        var matches = KnockoutBracket.buildRoundOf32(from: makeQualifiers())
        var rng = SeededGenerator(seed: 1)
        let lookup = Dictionary(uniqueKeysWithValues:
            makeQualifiers().map { ($0.nationId,
                Nation(id: $0.nationId, name: $0.nationId, flag: "🏳️",
                       strength: $0.points)) })
        while matches.count > 1 {
            let results = matches.map { m in
                MatchSimulator.simulate(home: lookup[m.homeId]!,
                                        away: lookup[m.awayId]!, using: &rng)
            }
            matches = KnockoutBracket.nextRound(from: matches, results: results)
        }
        XCTAssertEqual(matches.count, 1) // the final
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter KnockoutBracketTests`
Expected: FAIL — "cannot find 'BracketMatch' in scope".

- [ ] **Step 3: Write the BracketMatch model**

`GameCore/Sources/GameCore/Models/BracketMatch.swift`:

```swift
/// A single knockout pairing.
public struct BracketMatch: Codable, Equatable {
    public let homeId: String
    public let awayId: String

    public init(homeId: String, awayId: String) {
        self.homeId = homeId
        self.awayId = awayId
    }
}
```

- [ ] **Step 4: Write KnockoutBracket**

`GameCore/Sources/GameCore/Logic/KnockoutBracket.swift`:

```swift
/// Builds and advances the single-elimination knockout bracket.
///
/// Seeding note: the official FIFA Round-of-32 slotting table is replaced by a
/// deterministic seeded bracket. All 32 qualifiers are ranked (winners above
/// runners-up above thirds; then points, goal difference, goals for, id) and
/// paired seed 1 vs 32, 2 vs 31, … so stronger finishers meet later.
public enum KnockoutBracket {

    public static func buildRoundOf32(from qualifiers: [Qualifier]) -> [BracketMatch] {
        let seeded = qualifiers.sorted { lhs, rhs in
            if lhs.position != rhs.position { return lhs.position < rhs.position }
            if lhs.points != rhs.points { return lhs.points > rhs.points }
            if lhs.goalDifference != rhs.goalDifference {
                return lhs.goalDifference > rhs.goalDifference
            }
            if lhs.goalsFor != rhs.goalsFor { return lhs.goalsFor > rhs.goalsFor }
            return lhs.nationId < rhs.nationId
        }

        let count = seeded.count
        var matches: [BracketMatch] = []
        for i in 0..<(count / 2) {
            matches.append(BracketMatch(homeId: seeded[i].nationId,
                                        awayId: seeded[count - 1 - i].nationId))
        }
        return matches
    }

    /// Pair the winners of consecutive matches into the next round.
    /// `results[i]` must correspond to `matches[i]`.
    public static func nextRound(from matches: [BracketMatch],
                                 results: [MatchResult]) -> [BracketMatch] {
        let winners = results.map { $0.winnerId }
        var next: [BracketMatch] = []
        var i = 0
        while i + 1 < winners.count {
            next.append(BracketMatch(homeId: winners[i], awayId: winners[i + 1]))
            i += 2
        }
        return next
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd GameCore && swift test --filter KnockoutBracketTests`
Expected: PASS (all four).

- [ ] **Step 6: Commit**

```bash
git add GameCore/Sources/GameCore/Models/BracketMatch.swift GameCore/Sources/GameCore/Logic/KnockoutBracket.swift GameCore/Tests/GameCoreTests/KnockoutBracketTests.swift
git commit -m "feat: add KnockoutBracket build and advance"
```

---

## Task 7: TournamentStats and ScoreCalculator

**Files:**
- Create: `GameCore/Sources/GameCore/Models/TournamentStats.swift`
- Create: `GameCore/Sources/GameCore/Logic/ScoreCalculator.swift`
- Test: `GameCore/Tests/GameCoreTests/ScoreCalculatorTests.swift`

Scoring (per the spec — goals, saves, wins, plus a tournament-won bonus):
`goalsScored*100 + saves*60 + matchesWon*250 + (wonTournament ? 1000 : 0)`.

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/ScoreCalculatorTests.swift`:

```swift
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
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter ScoreCalculatorTests`
Expected: FAIL — "cannot find 'TournamentStats' in scope".

- [ ] **Step 3: Write the model and calculator**

`GameCore/Sources/GameCore/Models/TournamentStats.swift`:

```swift
/// Aggregate stats from a player's tournament run, fed to scoring.
public struct TournamentStats: Codable, Equatable {
    public var goalsScored: Int
    public var saves: Int
    public var matchesWon: Int
    public var wonTournament: Bool

    public init(goalsScored: Int = 0, saves: Int = 0,
                matchesWon: Int = 0, wonTournament: Bool = false) {
        self.goalsScored = goalsScored
        self.saves = saves
        self.matchesWon = matchesWon
        self.wonTournament = wonTournament
    }
}
```

`GameCore/Sources/GameCore/Logic/ScoreCalculator.swift`:

```swift
/// Turns a tournament run into a single Game Center score.
public enum ScoreCalculator {
    public static func totalScore(_ stats: TournamentStats) -> Int {
        stats.goalsScored * 100
            + stats.saves * 60
            + stats.matchesWon * 250
            + (stats.wonTournament ? 1000 : 0)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter ScoreCalculatorTests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Models/TournamentStats.swift GameCore/Sources/GameCore/Logic/ScoreCalculator.swift GameCore/Tests/GameCoreTests/ScoreCalculatorTests.swift
git commit -m "feat: add TournamentStats and ScoreCalculator"
```

---

## Task 8: Full WC2026 dataset and DataStore.loadGroups

**Files:**
- Modify: `GameCore/Sources/GameCore/Data/Resources/nations.json` (expand to 48)
- Create: `GameCore/Sources/GameCore/Data/Resources/groups.json`
- Modify: `GameCore/Sources/GameCore/Data/DataStore.swift` (add `loadGroups`)
- Test: `GameCore/Tests/GameCoreTests/DatasetIntegrityTests.swift`

> **Data sourcing instructions (read before implementing):** Use the WebSearch
> and WebFetch tools to obtain the real 2026 tournament: the 48 participating
> nations, and the 12 groups (A–L) with their four nations each. Cross-check at
> least two independent public sources for the group composition (the draw is
> public). For each nation set `strength` to an integer 1–100 derived from a
> public ranking (FIFA World Ranking points normalized to 1–100, cross-checked
> against eloratings.net). Use stable ISO-3166 alpha-3 codes for `id` (e.g.
> "USA", "MEX", "BRA", "ARG"). Keep the three host ids already present (CAN,
> MEX, USA). Use flag emoji for `flag`. If any group's composition cannot be
> confirmed from sources, STOP and report NEEDS_CONTEXT rather than guessing —
> do not invent the draw. The integrity test below checks structure, not
> specific teams, so the controller will verify team accuracy during review.

- [ ] **Step 1: Write the failing integrity test**

`GameCore/Tests/GameCoreTests/DatasetIntegrityTests.swift`:

```swift
import XCTest
@testable import GameCore

final class DatasetIntegrityTests: XCTestCase {
    func testHas48UniqueNations() throws {
        let nations = try DataStore.loadNations()
        XCTAssertEqual(nations.count, 48)
        XCTAssertEqual(Set(nations.map { $0.id }).count, 48)
    }

    func testStrengthsInRange() throws {
        for n in try DataStore.loadNations() {
            XCTAssertTrue((1...100).contains(n.strength), "\(n.id)=\(n.strength)")
        }
    }

    func testTwelveGroupsPartitionAll48Nations() throws {
        let nations = try DataStore.loadNations()
        let groups = try DataStore.loadGroups()
        let nationIds = Set(nations.map { $0.id })

        XCTAssertEqual(groups.count, 12)
        var seen = Set<String>()
        for g in groups {
            XCTAssertEqual(g.nationIds.count, 4, "group \(g.id) size")
            for id in g.nationIds {
                XCTAssertTrue(nationIds.contains(id), "unknown nation \(id)")
                XCTAssertFalse(seen.contains(id), "\(id) in two groups")
                seen.insert(id)
            }
        }
        XCTAssertEqual(seen.count, 48) // every nation in exactly one group
    }

    func testHostsPresent() throws {
        let ids = Set(try DataStore.loadNations().map { $0.id })
        XCTAssertTrue(ids.isSuperset(of: ["CAN", "MEX", "USA"]))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter DatasetIntegrityTests`
Expected: FAIL — `loadGroups` missing and nations count is 3, not 48.

- [ ] **Step 3: Populate `nations.json` with all 48 nations**

Replace `GameCore/Sources/GameCore/Data/Resources/nations.json` with a JSON
array of 48 objects, each `{ "id", "name", "flag", "strength" }`, sourced as
described in the data-sourcing note above. Keep CAN/MEX/USA. Example shape (the
implementer fills all 48 with real data):

```json
[
  { "id": "CAN", "name": "Canada", "flag": "🇨🇦", "strength": 70 },
  { "id": "MEX", "name": "Mexico", "flag": "🇲🇽", "strength": 74 },
  { "id": "USA", "name": "United States", "flag": "🇺🇸", "strength": 76 }
]
```

- [ ] **Step 4: Create `groups.json` with the 12 real groups**

Create `GameCore/Sources/GameCore/Data/Resources/groups.json` as an array of 12
objects `{ "id": "A"…"L", "nationIds": [four ids] }`, using the real draw and
the same ids as `nations.json`. Example shape (fill with real data):

```json
[
  { "id": "A", "nationIds": ["MEX", "...", "...", "..."] }
]
```

- [ ] **Step 5: Add `loadGroups` to DataStore**

Add this method inside the `DataStore` enum in
`GameCore/Sources/GameCore/Data/DataStore.swift`:

```swift
    /// Load the 12 groups shipped with the package bundle.
    public static func loadGroups() throws -> [Group] {
        guard let url = Bundle.module.url(forResource: "groups",
                                          withExtension: "json") else {
            throw DataError.resourceNotFound("groups.json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Group].self, from: data)
    }
```

- [ ] **Step 6: Run the integrity test to verify it passes**

Run: `cd GameCore && swift test --filter DatasetIntegrityTests`
Expected: PASS (all four). If a group cannot be confirmed, report NEEDS_CONTEXT.

- [ ] **Step 7: Run the full suite**

Run: `cd GameCore && swift test`
Expected: every test across the package PASSES.

- [ ] **Step 8: Commit**

```bash
git add GameCore/Sources/GameCore/Data GameCore/Tests/GameCoreTests/DatasetIntegrityTests.swift
git commit -m "feat: add full 48-nation WC2026 dataset and groups"
```

---

## Done criteria

- `cd GameCore && swift test` builds and passes every test.
- `GameCore` still imports only `Foundation` (no SpriteKit/UIKit/SwiftUI).
- Deterministic simulation: a fixed seed reproduces the same `MatchResult`.
- Standings, qualification (top 2 + best 8 thirds = 32), and a full 32→1 knockout
  bracket all compute correctly.
- `ScoreCalculator` produces the documented total.
- The bundled dataset has 48 unique nations partitioned into 12 groups of 4,
  with strengths in 1–100 and the three hosts present.

## What this plan deliberately leaves out

- The single-shot penalty gameplay engine (swipe → goal/save/miss) → next plan
  (Penalty engine). `MatchSimulator` here is statistical, used for matches the
  player does not play.
- A `TournamentState`/save model tying choice-of-nation to a persisted run →
  built when wiring the app flow (Plan: app shell), reusing `SaveStore`.
- SpriteKit, SwiftUI, Game Center, audio → later plans.
- Real fixture dates and venues (the spec lists them in `tournament.json`) are
  display-only metadata, not needed by the tournament logic — the group
  fixtures are the round-robin pairs computed here. Dates/venues are added as
  presentation data in the app-shell plan if the UI surfaces them.
