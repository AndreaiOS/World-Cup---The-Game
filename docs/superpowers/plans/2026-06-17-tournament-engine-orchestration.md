# Tournament Engine Orchestration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build the pure-logic tournament orchestrator in `GameCore` — a deterministic state machine that takes the player's chosen nation and the results of the player's own shootouts, and derives the entire World Cup run (group standings, qualification, knockout bracket, advancement, elimination, champion) by simulating every other match from a seed.

**Architecture:** The whole tournament is a deterministic function of `(dataset, chosenNation, seed, the player's own match results)`. So the save state is tiny — `TournamentSave { playerNationId, seed, playerResults }` — and `TournamentEngine.snapshot(...)` recomputes everything on demand by replaying a single seeded `SeededGenerator` over all non-player matches in a fixed order. The player is always `home` in their recorded results, so `result.winnerId == playerNationId` means the player won. No SpriteKit/SwiftUI; built on the Plan 2 pieces (`GroupTable`, `KnockoutBracket`, `MatchSimulator`).

**Tech Stack:** Swift 5.9+, Swift Package Manager, XCTest. Builds on `Nation`, `Group`, `GroupStanding`, `Qualifier`, `BracketMatch`, `MatchResult`, `Stage`, `GroupTable`, `KnockoutBracket`, `MatchSimulator`, `SeededGenerator`, `DataStore` (bundled 48-nation / 12-group dataset).

---

## File Structure

```
GameCore/Sources/GameCore/Tournament/
├── TournamentSave.swift       # TournamentSave (Codable) + TournamentPhase + TournamentSnapshot
└── TournamentEngine.swift     # deterministic replay: snapshot(nations:groups:save:)
```

**Responsibilities:**
- `TournamentSave` — the entire persistable state: chosen nation id, seed, and the ordered list of the player's own shootout results (player is `home` in each). Codable for use with `SaveStore`.
- `TournamentPhase` — `.playing`, `.eliminated`, `.champion`.
- `TournamentSnapshot` — the derived view the UI renders: current `stage`, `phase`, the next `opponentId` (when playing), the player's group standings, and how many matches the player has played.
- `TournamentEngine` — pure functions. `snapshot(nations:groups:save:)` replays the tournament; helpers `playerGroup`, `groupOpponents`, and `allGroupResults` are the testable building blocks.

**Determinism contract:** every call creates one `SeededGenerator(seed:)` and simulates non-player matches in a FIXED order — group matches first (groups in their array order, `roundRobinPairs` order, skipping the player's own matches), then knockout rounds in order (matches in bracket order, skipping the player's match). The same save always yields the same snapshot.

**Player ↔ match convention:** the UI builds each recorded result as
`MatchResult(homeId: playerNationId, awayId: opponentId, homeScore: playerScore, awayScore: opponentScore)`.
The engine relies only on `winnerId` to decide advancement, so the `awayId` need not be re-derived.

---

## Task 1: Save, phase, snapshot types + navigation helpers

**Files:**
- Create: `GameCore/Sources/GameCore/Tournament/TournamentSave.swift`
- Create: `GameCore/Sources/GameCore/Tournament/TournamentEngine.swift` (helpers only for now)
- Test: `GameCore/Tests/GameCoreTests/TournamentTypesTests.swift`

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/TournamentTypesTests.swift`:

```swift
import XCTest
@testable import GameCore

final class TournamentTypesTests: XCTestCase {
    func testSaveRoundTrips() throws {
        let save = TournamentSave(playerNationId: "BRA", seed: 42, playerResults: [
            MatchResult(homeId: "BRA", awayId: "MAR", homeScore: 5, awayScore: 3)
        ])
        let data = try JSONEncoder().encode(save)
        let decoded = try JSONDecoder().decode(TournamentSave.self, from: data)
        XCTAssertEqual(decoded, save)
    }

    func testPlayerGroupAndOpponentsFromRealData() throws {
        let groups = try DataStore.loadGroups()
        let group = TournamentEngine.playerGroup(in: groups, playerId: "BRA")
        XCTAssertTrue(group.nationIds.contains("BRA"))
        let opponents = TournamentEngine.groupOpponents(group: group, playerId: "BRA")
        XCTAssertEqual(opponents.count, 3)
        XCTAssertFalse(opponents.contains("BRA"))
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter TournamentTypesTests`
Expected: FAIL — "cannot find 'TournamentSave' in scope".

- [ ] **Step 3: Write the types**

`GameCore/Sources/GameCore/Tournament/TournamentSave.swift`:

```swift
/// The entire persistable tournament state. The player is `home` in every
/// recorded result, so `result.winnerId == playerNationId` means a player win.
public struct TournamentSave: Codable, Equatable {
    public let playerNationId: String
    public let seed: UInt64
    public var playerResults: [MatchResult]

    public init(playerNationId: String, seed: UInt64, playerResults: [MatchResult] = []) {
        self.playerNationId = playerNationId
        self.seed = seed
        self.playerResults = playerResults
    }
}

/// Where the player stands in their run.
public enum TournamentPhase: String, Codable, Equatable {
    case playing
    case eliminated
    case champion
}

/// The derived view the UI renders.
public struct TournamentSnapshot: Equatable {
    public let stage: Stage
    public let phase: TournamentPhase
    /// The next opponent's id when `phase == .playing`, else nil.
    public let opponentId: String?
    public let playerGroupStandings: [GroupStanding]
    public let playerMatchesPlayed: Int

    public init(stage: Stage, phase: TournamentPhase, opponentId: String?,
                playerGroupStandings: [GroupStanding], playerMatchesPlayed: Int) {
        self.stage = stage
        self.phase = phase
        self.opponentId = opponentId
        self.playerGroupStandings = playerGroupStandings
        self.playerMatchesPlayed = playerMatchesPlayed
    }
}
```

- [ ] **Step 4: Write the navigation helpers**

`GameCore/Sources/GameCore/Tournament/TournamentEngine.swift`:

```swift
/// Deterministic tournament orchestration over the bundled dataset.
public enum TournamentEngine {

    /// The group the player's nation belongs to.
    public static func playerGroup(in groups: [Group], playerId: String) -> Group {
        guard let g = groups.first(where: { $0.nationIds.contains(playerId) }) else {
            preconditionFailure("nation \(playerId) is not in any group")
        }
        return g
    }

    /// The player's three group opponents, in group order.
    public static func groupOpponents(group: Group, playerId: String) -> [String] {
        group.nationIds.filter { $0 != playerId }
    }
}
```

- [ ] **Step 5: Run test to verify it passes**

Run: `cd GameCore && swift test --filter TournamentTypesTests`
Expected: PASS (both).

- [ ] **Step 6: Commit**

```bash
git add GameCore/Sources/GameCore/Tournament GameCore/Tests/GameCoreTests/TournamentTypesTests.swift
git commit -m "feat: add TournamentSave types and navigation helpers"
```

---

## Task 2: allGroupResults — player results + simulated others

**Files:**
- Modify: `GameCore/Sources/GameCore/Tournament/TournamentEngine.swift` (add `allGroupResults`)
- Test: `GameCore/Tests/GameCoreTests/AllGroupResultsTests.swift`

`allGroupResults` builds every group-stage result: the player's own matches come
from `save.playerResults` (matched to opponents by id), and every other match in
every group is simulated, consuming the generator in a fixed order (groups in
array order, `roundRobinPairs` order). It must only be called once the player has
played all three group matches.

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/AllGroupResultsTests.swift`:

```swift
import XCTest
@testable import GameCore

final class AllGroupResultsTests: XCTestCase {
    private func brazilSave(seed: UInt64) throws -> ([Nation], [Group], TournamentSave) {
        let nations = try DataStore.loadNations()
        let groups = try DataStore.loadGroups()
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"),
            playerId: "BRA")
        let results = opps.map { MatchResult(homeId: "BRA", awayId: $0, homeScore: 5, awayScore: 0) }
        return (nations, groups, TournamentSave(playerNationId: "BRA", seed: seed, playerResults: results))
    }

    func testProducesSixResultsPerGroup() throws {
        let (nations, groups, save) = try brazilSave(seed: 1)
        var gen = SeededGenerator(seed: save.seed)
        let byId = Dictionary(uniqueKeysWithValues: nations.map { ($0.id, $0) })
        let results = TournamentEngine.allGroupResults(nations: byId, groups: groups,
                                                       save: save, gen: &gen)
        XCTAssertEqual(results.count, groups.count * 6)   // 12 * 6 = 72
    }

    func testPlayerResultsArePresent() throws {
        let (nations, groups, save) = try brazilSave(seed: 1)
        var gen = SeededGenerator(seed: save.seed)
        let byId = Dictionary(uniqueKeysWithValues: nations.map { ($0.id, $0) })
        let results = TournamentEngine.allGroupResults(nations: byId, groups: groups,
                                                       save: save, gen: &gen)
        let brazilMatches = results.filter { $0.homeId == "BRA" || $0.awayId == "BRA" }
        XCTAssertEqual(brazilMatches.count, 3)
        XCTAssertTrue(brazilMatches.allSatisfy { $0.winnerId == "BRA" })
    }

    func testDeterministicForSeed() throws {
        let (nations, groups, save) = try brazilSave(seed: 99)
        let byId = Dictionary(uniqueKeysWithValues: nations.map { ($0.id, $0) })
        var g1 = SeededGenerator(seed: save.seed)
        var g2 = SeededGenerator(seed: save.seed)
        let r1 = TournamentEngine.allGroupResults(nations: byId, groups: groups, save: save, gen: &g1)
        let r2 = TournamentEngine.allGroupResults(nations: byId, groups: groups, save: save, gen: &g2)
        XCTAssertEqual(r1, r2)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter AllGroupResultsTests`
Expected: FAIL — "type 'TournamentEngine' has no member 'allGroupResults'".

- [ ] **Step 3: Add `allGroupResults`** — insert inside the `TournamentEngine` enum:

```swift
    /// Every group-stage result: the player's own matches come from the save,
    /// all other matches are simulated. Consumes `gen` for the simulated matches
    /// in a fixed order. Call only when the player has played all three group
    /// matches.
    static func allGroupResults(nations: [String: Nation], groups: [Group],
                                save: TournamentSave,
                                gen: inout SeededGenerator) -> [MatchResult] {
        let player = save.playerNationId
        let pGroup = playerGroup(in: groups, playerId: player)
        let opponents = groupOpponents(group: pGroup, playerId: player)

        var playerResultByOpponent: [String: MatchResult] = [:]
        for (i, opp) in opponents.enumerated() where i < save.playerResults.count {
            playerResultByOpponent[opp] = save.playerResults[i]
        }

        var results: [MatchResult] = []
        for group in groups {
            for (a, b) in GroupTable.roundRobinPairs(group.nationIds) {
                if group.id == pGroup.id && (a == player || b == player) {
                    let opp = (a == player) ? b : a
                    if let r = playerResultByOpponent[opp] {
                        results.append(r)
                    }
                } else {
                    let home = nations[a]!
                    let away = nations[b]!
                    results.append(MatchSimulator.simulate(home: home, away: away, using: &gen))
                }
            }
        }
        return results
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter AllGroupResultsTests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Tournament/TournamentEngine.swift GameCore/Tests/GameCoreTests/AllGroupResultsTests.swift
git commit -m "feat: add allGroupResults (player + simulated group matches)"
```

---

## Task 3: snapshot — group stage navigation and qualification

**Files:**
- Modify: `GameCore/Sources/GameCore/Tournament/TournamentEngine.swift` (add `snapshot`)
- Test: `GameCore/Tests/GameCoreTests/TournamentSnapshotGroupTests.swift`

`snapshot` is the public entry point. This task implements the group portion:
before three group matches it returns the next opponent and partial standings;
after three it computes qualification and either advances into the knockout
(Task 4 wires the bracket) or marks the player eliminated. To keep this task
self-contained, the knockout branch returns a placeholder that Task 4 replaces;
here we only assert the group-stage and the eliminated outcomes.

Deterministic facts: a player who wins all three group matches has 9 points —
uniquely first in a four-team group — so they always qualify. A player who loses
all three 0–5 finishes last and never qualifies.

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/TournamentSnapshotGroupTests.swift`:

```swift
import XCTest
@testable import GameCore

final class TournamentSnapshotGroupTests: XCTestCase {
    private func data() throws -> ([Nation], [Group]) {
        (try DataStore.loadNations(), try DataStore.loadGroups())
    }

    func testStartsPlayingFirstGroupOpponent() throws {
        let (nations, groups) = try data()
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
        let save = TournamentSave(playerNationId: "BRA", seed: 1)
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.phase, .playing)
        XCTAssertEqual(snap.stage, .group)
        XCTAssertEqual(snap.opponentId, opps[0])
        XCTAssertEqual(snap.playerMatchesPlayed, 0)
    }

    func testSecondGroupOpponentAfterOneWin() throws {
        let (nations, groups) = try data()
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
        let save = TournamentSave(playerNationId: "BRA", seed: 1, playerResults: [
            MatchResult(homeId: "BRA", awayId: opps[0], homeScore: 4, awayScore: 2)
        ])
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.opponentId, opps[1])
        XCTAssertEqual(snap.playerMatchesPlayed, 1)
    }

    func testWinningAllThreeQualifies() throws {
        let (nations, groups) = try data()
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
        let save = TournamentSave(playerNationId: "BRA", seed: 1,
            playerResults: opps.map { MatchResult(homeId: "BRA", awayId: $0, homeScore: 5, awayScore: 0) })
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertNotEqual(snap.phase, .eliminated)
        XCTAssertEqual(snap.playerMatchesPlayed, 3)
    }

    func testLosingAllThreeIsEliminated() throws {
        let (nations, groups) = try data()
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
        let save = TournamentSave(playerNationId: "BRA", seed: 1,
            playerResults: opps.map { MatchResult(homeId: "BRA", awayId: $0, homeScore: 0, awayScore: 5) })
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.phase, .eliminated)
        XCTAssertEqual(snap.stage, .group)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter TournamentSnapshotGroupTests`
Expected: FAIL — "type 'TournamentEngine' has no member 'snapshot'".

- [ ] **Step 3: Add `snapshot`** — insert inside the `TournamentEngine` enum:

```swift
    /// Replay the whole tournament from the save and return the current view.
    public static func snapshot(nations: [Nation], groups: [Group],
                                save: TournamentSave) -> TournamentSnapshot {
        let player = save.playerNationId
        let byId = Dictionary(uniqueKeysWithValues: nations.map { ($0.id, $0) })
        precondition(byId[player] != nil, "unknown nation \(player)")
        let pGroup = playerGroup(in: groups, playerId: player)
        let opponents = groupOpponents(group: pGroup, playerId: player)

        // --- Group stage, still playing the player's three matches ---
        if save.playerResults.count < 3 {
            let standings = GroupTable.standings(nationIds: pGroup.nationIds,
                                                 results: save.playerResults)
            return TournamentSnapshot(
                stage: .group, phase: .playing,
                opponentId: opponents[save.playerResults.count],
                playerGroupStandings: standings,
                playerMatchesPlayed: save.playerResults.count)
        }

        // --- Group stage resolved: simulate the rest and check qualification ---
        var gen = SeededGenerator(seed: save.seed)
        let groupResults = allGroupResults(nations: byId, groups: groups, save: save, gen: &gen)
        let groupStandings = GroupTable.standings(nationIds: pGroup.nationIds, results: groupResults)
        let qualifiers = GroupTable.qualifiers(groups: groups, results: groupResults)

        guard qualifiers.contains(where: { $0.nationId == player }) else {
            return TournamentSnapshot(
                stage: .group, phase: .eliminated, opponentId: nil,
                playerGroupStandings: groupStandings,
                playerMatchesPlayed: save.playerResults.count)
        }

        // --- Knockout (Task 4 replaces this placeholder) ---
        return knockoutSnapshot(byId: byId, qualifiers: qualifiers, save: save,
                                groupStandings: groupStandings, gen: &gen)
    }

    /// Placeholder replaced in Task 4.
    static func knockoutSnapshot(byId: [String: Nation], qualifiers: [Qualifier],
                                 save: TournamentSave, groupStandings: [GroupStanding],
                                 gen: inout SeededGenerator) -> TournamentSnapshot {
        TournamentSnapshot(stage: .roundOf32, phase: .playing, opponentId: nil,
                           playerGroupStandings: groupStandings,
                           playerMatchesPlayed: save.playerResults.count)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter TournamentSnapshotGroupTests`
Expected: PASS (all four). (`testWinningAllThreeQualifies` reaches the placeholder
knockout, whose phase is `.playing` — not `.eliminated` — so the assertion holds.)

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Tournament/TournamentEngine.swift GameCore/Tests/GameCoreTests/TournamentSnapshotGroupTests.swift
git commit -m "feat: add snapshot group-stage navigation and qualification"
```

---

## Task 4: Knockout replay — advance, eliminate, champion

**Files:**
- Modify: `GameCore/Sources/GameCore/Tournament/TournamentEngine.swift` (replace `knockoutSnapshot`)
- Test: `GameCore/Tests/GameCoreTests/TournamentKnockoutTests.swift`

The knockout replay builds the Round of 32 from the qualifiers, then walks the
rounds. For each round it finds the player's match. If the player has a result
for that round, a loss ends the run (eliminated at that stage); a win advances —
the player's match uses their result and the others are simulated to build the
next round, until winning the final (one match) crowns the champion. If the
player has no result yet for the round, that round's opponent is returned.

Stage order: `roundOf32` (16 matches) → `roundOf16` (8) → `quarterFinal` (4) →
`semiFinal` (2) → `final` (1).

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/TournamentKnockoutTests.swift`:

```swift
import XCTest
@testable import GameCore

final class TournamentKnockoutTests: XCTestCase {
    private func data() throws -> ([Nation], [Group]) {
        (try DataStore.loadNations(), try DataStore.loadGroups())
    }

    private func threeGroupWins(_ groups: [Group]) -> [MatchResult] {
        let opps = TournamentEngine.groupOpponents(
            group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
        return opps.map { MatchResult(homeId: "BRA", awayId: $0, homeScore: 5, awayScore: 0) }
    }

    func testQualifiedPlayerFacesAKnockoutOpponent() throws {
        let (nations, groups) = try data()
        let save = TournamentSave(playerNationId: "BRA", seed: 1, playerResults: threeGroupWins(groups))
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.phase, .playing)
        XCTAssertEqual(snap.stage, .roundOf32)
        XCTAssertNotNil(snap.opponentId)
        XCTAssertNotEqual(snap.opponentId, "BRA")
    }

    func testLosingFirstKnockoutMatchEliminates() throws {
        let (nations, groups) = try data()
        var results = threeGroupWins(groups)
        results.append(MatchResult(homeId: "BRA", awayId: "OPP", homeScore: 2, awayScore: 4)) // loss
        let save = TournamentSave(playerNationId: "BRA", seed: 1, playerResults: results)
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.phase, .eliminated)
        XCTAssertEqual(snap.stage, .roundOf32)
    }

    func testWinningEveryRoundCrownsChampion() throws {
        let (nations, groups) = try data()
        var results = threeGroupWins(groups)
        for _ in 0..<5 {   // R32, R16, QF, SF, Final
            results.append(MatchResult(homeId: "BRA", awayId: "OPP", homeScore: 5, awayScore: 4))
        }
        let save = TournamentSave(playerNationId: "BRA", seed: 1, playerResults: results)
        let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(snap.phase, .champion)
        XCTAssertEqual(snap.stage, .final)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter TournamentKnockoutTests`
Expected: FAIL — `testLosingFirstKnockoutMatchEliminates` / `testWinningEveryRoundCrownsChampion` fail against the placeholder.

- [ ] **Step 3: Replace `knockoutSnapshot`** — swap the placeholder for:

```swift
    /// Walk the knockout bracket using the player's results for their own
    /// matches and simulating the others, returning the current view.
    static func knockoutSnapshot(byId: [String: Nation], qualifiers: [Qualifier],
                                 save: TournamentSave, groupStandings: [GroupStanding],
                                 gen: inout SeededGenerator) -> TournamentSnapshot {
        let player = save.playerNationId
        let stages: [Stage] = [.roundOf32, .roundOf16, .quarterFinal, .semiFinal, .final]
        let knockoutResults = Array(save.playerResults.dropFirst(3))

        var matches = KnockoutBracket.buildRoundOf32(from: qualifiers)
        var kIndex = 0

        for stage in stages {
            guard let playerMatch = matches.first(where: {
                $0.homeId == player || $0.awayId == player
            }) else { break }

            if kIndex < knockoutResults.count {
                let r = knockoutResults[kIndex]
                kIndex += 1
                if r.winnerId != player {
                    return snapshot(stage: stage, phase: .eliminated, opponentId: nil,
                                    groupStandings: groupStandings, save: save)
                }
                if matches.count == 1 {                       // won the final
                    return snapshot(stage: .final, phase: .champion, opponentId: nil,
                                    groupStandings: groupStandings, save: save)
                }
                let roundResults: [MatchResult] = matches.map { m in
                    if m.homeId == player || m.awayId == player {
                        return r
                    }
                    return MatchSimulator.simulate(home: byId[m.homeId]!,
                                                   away: byId[m.awayId]!, using: &gen)
                }
                matches = KnockoutBracket.nextRound(from: matches, results: roundResults)
            } else {
                let opponentId = playerMatch.homeId == player ? playerMatch.awayId
                                                              : playerMatch.homeId
                return snapshot(stage: stage, phase: .playing, opponentId: opponentId,
                                groupStandings: groupStandings, save: save)
            }
        }

        // Player won the final on the last stage.
        return snapshot(stage: .final, phase: .champion, opponentId: nil,
                        groupStandings: groupStandings, save: save)
    }

    private static func snapshot(stage: Stage, phase: TournamentPhase, opponentId: String?,
                                 groupStandings: [GroupStanding],
                                 save: TournamentSave) -> TournamentSnapshot {
        TournamentSnapshot(stage: stage, phase: phase, opponentId: opponentId,
                           playerGroupStandings: groupStandings,
                           playerMatchesPlayed: save.playerResults.count)
    }
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter TournamentKnockoutTests`
Expected: PASS (all three).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Tournament/TournamentEngine.swift GameCore/Tests/GameCoreTests/TournamentKnockoutTests.swift
git commit -m "feat: add knockout replay (advance, eliminate, champion)"
```

---

## Task 5: Full deterministic playthrough integration test

**Files:**
- Test: `GameCore/Tests/GameCoreTests/TournamentPlaythroughTests.swift`

Plays the tournament the way the app will: repeatedly read the snapshot, and
while `playing`, append a player win over the reported opponent — until the
player is champion. This exercises group navigation, qualification, the bracket,
and advancement end to end.

- [ ] **Step 1: Write the test**

`GameCore/Tests/GameCoreTests/TournamentPlaythroughTests.swift`:

```swift
import XCTest
@testable import GameCore

final class TournamentPlaythroughTests: XCTestCase {
    func testWinningEveryMatchReachesChampion() throws {
        let nations = try DataStore.loadNations()
        let groups = try DataStore.loadGroups()
        var save = TournamentSave(playerNationId: "BRA", seed: 7)

        var guardCount = 0
        while guardCount < 20 {
            guardCount += 1
            let snap = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
            if snap.phase != .playing { break }
            let opp = try XCTUnwrap(snap.opponentId)
            // Player wins every match.
            save.playerResults.append(
                MatchResult(homeId: "BRA", awayId: opp, homeScore: 5, awayScore: 4))
        }

        let final = TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
        XCTAssertEqual(final.phase, .champion)
        XCTAssertEqual(final.stage, .final)
        // 3 group + 5 knockout = 8 matches to win it all.
        XCTAssertEqual(save.playerResults.count, 8)
    }

    func testRunIsDeterministicForSeed() throws {
        let nations = try DataStore.loadNations()
        let groups = try DataStore.loadGroups()
        func firstKnockoutOpponent(seed: UInt64) -> String? {
            let opps = TournamentEngine.groupOpponents(
                group: TournamentEngine.playerGroup(in: groups, playerId: "BRA"), playerId: "BRA")
            let save = TournamentSave(playerNationId: "BRA", seed: seed,
                playerResults: opps.map { MatchResult(homeId: "BRA", awayId: $0, homeScore: 5, awayScore: 0) })
            return TournamentEngine.snapshot(nations: nations, groups: groups, save: save).opponentId
        }
        XCTAssertEqual(firstKnockoutOpponent(seed: 123), firstKnockoutOpponent(seed: 123))
    }
}
```

- [ ] **Step 2: Run test to verify it passes**

Run: `cd GameCore && swift test --filter TournamentPlaythroughTests`
Expected: PASS (both). If `testWinningEveryMatchReachesChampion` does not reach
champion, the most likely cause is the player not qualifying despite three wins —
re-check that `allGroupResults` includes the player's three wins in the player's
group; do NOT weaken the assertion.

- [ ] **Step 3: Run the full suite**

Run: `cd GameCore && swift test`
Expected: every test across the package PASSES.

- [ ] **Step 4: Commit**

```bash
git add GameCore/Tests/GameCoreTests/TournamentPlaythroughTests.swift
git commit -m "test: add full deterministic tournament playthrough"
```

---

## Done criteria

- `cd GameCore && swift test` builds and passes every test.
- `GameCore` still imports only `Foundation` (no SpriteKit/UIKit/SwiftUI).
- `TournamentEngine.snapshot` deterministically derives the player's whole run
  from `(nations, groups, TournamentSave)`: next group opponent → qualification →
  knockout opponent each round → elimination or champion.
- `TournamentSave` is Codable (ready for `SaveStore`).

## What this plan deliberately leaves out

- All UI (menu, nation selection, group/bracket screens) and wiring the
  `PenaltyScene` shootout result back into a `TournamentSave` → next plan
  (tournament UI), which is interactive (Xcode + simulator). The scene's result
  becomes `MatchResult(homeId: playerNationId, awayId: snapshot.opponentId, ...)`
  appended to `save.playerResults`; the UI re-reads `snapshot` to drive the next
  screen.
- Aggregating the run into `TournamentStats` for `ScoreCalculator` and Game
  Center submission → services plan.
- Persisting `TournamentSave` to disk via `SaveStore` is trivial wiring done in
  the UI plan; the type is already Codable here.
