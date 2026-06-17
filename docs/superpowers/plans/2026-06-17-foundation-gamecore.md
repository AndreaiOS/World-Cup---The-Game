# Foundation: GameCore Package Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Create a pure-Swift `GameCore` package containing the data models, data loading, and save/load persistence for the World Football 2026 penalty game — fully testable from the command line with `swift test`, with no dependency on SpriteKit or SwiftUI.

**Architecture:** A Swift Package Manager library target `GameCore` holds all platform-independent logic. The iOS app (built in later plans) will consume this package. By keeping models, data loading, and persistence in a pure package, every behavior here is verified with `swift test` on the command line — no Xcode GUI, no simulator. This plan delivers the data layer only; game logic and UI come in later plans.

**Tech Stack:** Swift 5.9+, Swift Package Manager, XCTest, `Codable` for JSON and persistence.

---

## File Structure

```
World/
├── GameCore/
│   ├── Package.swift
│   ├── Sources/
│   │   └── GameCore/
│   │       ├── Models/
│   │       │   ├── Nation.swift          # Nation value type
│   │       │   ├── Stage.swift           # Tournament stage enum
│   │       │   └── MatchResult.swift     # Result of one shootout
│   │       ├── Data/
│   │       │   ├── DataStore.swift       # Loads bundled JSON into models
│   │       │   └── Resources/
│   │       │       └── nations.json      # Seed nation dataset
│   │       └── Persistence/
│   │           └── SaveStore.swift       # Generic Codable save/load
│   └── Tests/
│       └── GameCoreTests/
│           ├── NationTests.swift
│           ├── DataStoreTests.swift
│           ├── SaveStoreTests.swift
│           └── Fixtures/
│               └── nations_fixture.json
```

**Responsibilities:**
- `Nation.swift` — one nation: id, name, flag, strength. Pure value type.
- `Stage.swift` — enumerates the tournament stages. Used by later plans; defined here so models compile as a set.
- `MatchResult.swift` — outcome of a single played shootout (scores + winner).
- `DataStore.swift` — decodes the bundled `nations.json` into `[Nation]`. Single responsibility: turn bundled JSON into models.
- `SaveStore.swift` — generic save/load of any `Codable` to a file URL, with graceful handling of a missing or corrupted file. Single responsibility: durable persistence.

---

## Task 1: Package scaffold

**Files:**
- Create: `GameCore/Package.swift`
- Create: `GameCore/Sources/GameCore/GameCore.swift`
- Create: `GameCore/Tests/GameCoreTests/SmokeTests.swift`

- [ ] **Step 1: Create `Package.swift`**

```swift
// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "GameCore",
    platforms: [.iOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
    ],
    targets: [
        .target(name: "GameCore"),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"]
        ),
    ]
)
```

> Resource declarations are added in Task 4, once the resource and fixture
> directories actually exist. SPM errors on a declared resource path that does
> not exist, so they cannot be declared up front.

- [ ] **Step 2: Create a placeholder source so the target compiles**

`GameCore/Sources/GameCore/GameCore.swift`:

```swift
// GameCore: platform-independent game logic and data.
public enum GameCore {
    public static let version = "0.1.0"
}
```

- [ ] **Step 3: Write a smoke test**

`GameCore/Tests/GameCoreTests/SmokeTests.swift`:

```swift
import XCTest
@testable import GameCore

final class SmokeTests: XCTestCase {
    func testVersionIsSet() {
        XCTAssertEqual(GameCore.version, "0.1.0")
    }
}
```

- [ ] **Step 4: Run tests to verify the package builds and passes**

Run: `cd GameCore && swift test`
Expected: build succeeds, `testVersionIsSet` PASSES.

- [ ] **Step 5: Commit**

```bash
git add GameCore
git commit -m "chore: scaffold GameCore Swift package"
```

---

## Task 2: Nation model

**Files:**
- Create: `GameCore/Sources/GameCore/Models/Nation.swift`
- Create: `GameCore/Sources/GameCore/Models/Stage.swift`
- Test: `GameCore/Tests/GameCoreTests/NationTests.swift`

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/NationTests.swift`:

```swift
import XCTest
@testable import GameCore

final class NationTests: XCTestCase {
    func testDecodesFromJSON() throws {
        let json = """
        { "id": "ITA", "name": "Italy", "flag": "🇮🇹", "strength": 84 }
        """.data(using: .utf8)!

        let nation = try JSONDecoder().decode(Nation.self, from: json)

        XCTAssertEqual(nation.id, "ITA")
        XCTAssertEqual(nation.name, "Italy")
        XCTAssertEqual(nation.flag, "🇮🇹")
        XCTAssertEqual(nation.strength, 84)
    }

    func testEquatableById() {
        let a = Nation(id: "ITA", name: "Italy", flag: "🇮🇹", strength: 84)
        let b = Nation(id: "ITA", name: "Italy", flag: "🇮🇹", strength: 84)
        XCTAssertEqual(a, b)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter NationTests`
Expected: FAIL — "cannot find 'Nation' in scope".

- [ ] **Step 3: Write the model**

`GameCore/Sources/GameCore/Models/Nation.swift`:

```swift
/// A national team competing in the tournament.
public struct Nation: Codable, Identifiable, Equatable, Hashable {
    /// Stable ISO-style code, e.g. "ITA". Used as identity.
    public let id: String
    public let name: String
    /// Flag emoji used for lightweight display.
    public let flag: String
    /// Relative strength 1-100, drives keeper AI and match simulation.
    public let strength: Int

    public init(id: String, name: String, flag: String, strength: Int) {
        self.id = id
        self.name = name
        self.flag = flag
        self.strength = strength
    }
}
```

`GameCore/Sources/GameCore/Models/Stage.swift`:

```swift
/// The stages of the tournament, in order.
public enum Stage: String, Codable, CaseIterable {
    case group
    case roundOf32
    case roundOf16
    case quarterFinal
    case semiFinal
    case final
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter NationTests`
Expected: PASS (both tests).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Models GameCore/Tests/GameCoreTests/NationTests.swift
git commit -m "feat: add Nation model and Stage enum"
```

---

## Task 3: MatchResult model

**Files:**
- Create: `GameCore/Sources/GameCore/Models/MatchResult.swift`
- Test: `GameCore/Tests/GameCoreTests/MatchResultTests.swift`

- [ ] **Step 1: Write the failing test**

`GameCore/Tests/GameCoreTests/MatchResultTests.swift`:

```swift
import XCTest
@testable import GameCore

final class MatchResultTests: XCTestCase {
    func testWinnerIsHigherScorer() {
        let result = MatchResult(homeId: "ITA", awayId: "FRA",
                                 homeScore: 4, awayScore: 3)
        XCTAssertEqual(result.winnerId, "ITA")
        XCTAssertEqual(result.loserId, "FRA")
    }

    func testWinnerWhenAwayScoresMore() {
        let result = MatchResult(homeId: "ITA", awayId: "FRA",
                                 homeScore: 2, awayScore: 5)
        XCTAssertEqual(result.winnerId, "FRA")
        XCTAssertEqual(result.loserId, "ITA")
    }

    func testRoundTripCodable() throws {
        let result = MatchResult(homeId: "ITA", awayId: "FRA",
                                 homeScore: 4, awayScore: 3)
        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(MatchResult.self, from: data)
        XCTAssertEqual(decoded, result)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter MatchResultTests`
Expected: FAIL — "cannot find 'MatchResult' in scope".

- [ ] **Step 3: Write the model**

`GameCore/Sources/GameCore/Models/MatchResult.swift`:

```swift
/// Outcome of one played penalty shootout. Shootouts never tie:
/// the engine that produces a MatchResult guarantees unequal scores.
public struct MatchResult: Codable, Equatable {
    public let homeId: String
    public let awayId: String
    public let homeScore: Int
    public let awayScore: Int

    public init(homeId: String, awayId: String, homeScore: Int, awayScore: Int) {
        self.homeId = homeId
        self.awayId = awayId
        self.homeScore = homeScore
        self.awayScore = awayScore
    }

    public var winnerId: String { homeScore >= awayScore ? homeId : awayId }
    public var loserId: String { homeScore >= awayScore ? awayId : homeId }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter MatchResultTests`
Expected: PASS (all three tests).

- [ ] **Step 5: Commit**

```bash
git add GameCore/Sources/GameCore/Models/MatchResult.swift GameCore/Tests/GameCoreTests/MatchResultTests.swift
git commit -m "feat: add MatchResult model"
```

---

## Task 4: DataStore loads bundled nations

**Files:**
- Create: `GameCore/Sources/GameCore/Data/DataStore.swift`
- Create: `GameCore/Sources/GameCore/Data/Resources/nations.json`
- Create: `GameCore/Tests/GameCoreTests/Fixtures/nations_fixture.json`
- Test: `GameCore/Tests/GameCoreTests/DataStoreTests.swift`

> **Data note:** `nations.json` below ships with the three confirmed host
> nations as a seed. Completing the full 48-team dataset (with the real groups
> and per-nation strength values from public rankings) is a dedicated data task
> in Plan 2. Tests in this task read a fixed test fixture, not the seed file, so
> they stay stable as the seed grows.

- [ ] **Step 1: Create the test fixture**

`GameCore/Tests/GameCoreTests/Fixtures/nations_fixture.json`:

```json
[
  { "id": "CAN", "name": "Canada", "flag": "🇨🇦", "strength": 70 },
  { "id": "MEX", "name": "Mexico", "flag": "🇲🇽", "strength": 74 },
  { "id": "USA", "name": "United States", "flag": "🇺🇸", "strength": 76 }
]
```

- [ ] **Step 2: Create the seed resource file**

`GameCore/Sources/GameCore/Data/Resources/nations.json`:

```json
[
  { "id": "CAN", "name": "Canada", "flag": "🇨🇦", "strength": 70 },
  { "id": "MEX", "name": "Mexico", "flag": "🇲🇽", "strength": 74 },
  { "id": "USA", "name": "United States", "flag": "🇺🇸", "strength": 76 }
]
```

- [ ] **Step 3: Declare the resources in `Package.swift`**

Now that `Data/Resources/` and `Fixtures/` exist, add them. Replace the
`targets:` array in `GameCore/Package.swift` with:

```swift
    targets: [
        .target(
            name: "GameCore",
            resources: [.process("Data/Resources")]
        ),
        .testTarget(
            name: "GameCoreTests",
            dependencies: ["GameCore"],
            resources: [.process("Fixtures")]
        ),
    ]
```

- [ ] **Step 4: Write the failing test**

`GameCore/Tests/GameCoreTests/DataStoreTests.swift`:

```swift
import XCTest
@testable import GameCore

final class DataStoreTests: XCTestCase {
    func testDecodesNationsFromData() throws {
        let url = Bundle.module.url(forResource: "nations_fixture",
                                    withExtension: "json")!
        let data = try Data(contentsOf: url)

        let nations = try DataStore.decodeNations(from: data)

        XCTAssertEqual(nations.count, 3)
        XCTAssertEqual(nations.first?.id, "CAN")
        XCTAssertTrue(nations.contains(where: { $0.id == "USA" }))
    }

    func testLoadsBundledSeed() throws {
        let nations = try DataStore.loadNations()
        XCTAssertFalse(nations.isEmpty)
        // Hosts are guaranteed present in the seed.
        XCTAssertTrue(nations.contains(where: { $0.id == "USA" }))
        XCTAssertTrue(nations.contains(where: { $0.id == "CAN" }))
        XCTAssertTrue(nations.contains(where: { $0.id == "MEX" }))
    }
}
```

- [ ] **Step 5: Run test to verify it fails**

Run: `cd GameCore && swift test --filter DataStoreTests`
Expected: FAIL — "cannot find 'DataStore' in scope".

- [ ] **Step 6: Write the DataStore**

`GameCore/Sources/GameCore/Data/DataStore.swift`:

```swift
import Foundation

/// Loads bundled game data (currently nations) into models.
public enum DataStore {

    public enum DataError: Error, Equatable {
        case resourceNotFound(String)
    }

    /// Decode a `[Nation]` array from raw JSON data.
    public static func decodeNations(from data: Data) throws -> [Nation] {
        try JSONDecoder().decode([Nation].self, from: data)
    }

    /// Load the nations shipped with the package bundle.
    public static func loadNations() throws -> [Nation] {
        guard let url = Bundle.module.url(forResource: "nations",
                                          withExtension: "json") else {
            throw DataError.resourceNotFound("nations.json")
        }
        let data = try Data(contentsOf: url)
        return try decodeNations(from: data)
    }
}
```

- [ ] **Step 7: Run test to verify it passes**

Run: `cd GameCore && swift test --filter DataStoreTests`
Expected: PASS (both tests).

- [ ] **Step 8: Commit**

```bash
git add GameCore/Package.swift GameCore/Sources/GameCore/Data GameCore/Tests/GameCoreTests/DataStoreTests.swift GameCore/Tests/GameCoreTests/Fixtures
git commit -m "feat: add DataStore with bundled nations seed"
```

---

## Task 5: SaveStore persistence (save/load round-trip)

**Files:**
- Create: `GameCore/Sources/GameCore/Persistence/SaveStore.swift`
- Test: `GameCore/Tests/GameCoreTests/SaveStoreTests.swift`

- [ ] **Step 1: Write the failing test for round-trip**

`GameCore/Tests/GameCoreTests/SaveStoreTests.swift`:

```swift
import XCTest
@testable import GameCore

private struct SampleSave: Codable, Equatable {
    let nationId: String
    let round: Int
}

final class SaveStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    func testSaveThenLoadReturnsIdenticalValue() throws {
        let url = tempURL()
        let store = SaveStore(url: url)
        let value = SampleSave(nationId: "ITA", round: 3)

        try store.save(value)
        let loaded: SampleSave? = try store.load()

        XCTAssertEqual(loaded, value)
        try? FileManager.default.removeItem(at: url)
    }

    func testLoadMissingFileReturnsNil() throws {
        let store = SaveStore(url: tempURL())
        let loaded: SampleSave? = try store.load()
        XCTAssertNil(loaded)
    }

    func testLoadCorruptedFileReturnsNil() throws {
        let url = tempURL()
        try "not valid json".data(using: .utf8)!.write(to: url)
        let store = SaveStore(url: url)

        let loaded: SampleSave? = try store.load()

        XCTAssertNil(loaded)
        try? FileManager.default.removeItem(at: url)
    }
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `cd GameCore && swift test --filter SaveStoreTests`
Expected: FAIL — "cannot find 'SaveStore' in scope".

- [ ] **Step 3: Write the SaveStore**

`GameCore/Sources/GameCore/Persistence/SaveStore.swift`:

```swift
import Foundation

/// Durable save/load of any Codable value to a single file URL.
/// A missing or corrupted file loads as `nil` rather than throwing,
/// so a damaged save degrades to "start a new tournament".
public struct SaveStore {
    private let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func save<T: Encodable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        try data.write(to: url, options: .atomic)
    }

    public func load<T: Decodable>() throws -> T? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `cd GameCore && swift test --filter SaveStoreTests`
Expected: PASS (all three tests).

- [ ] **Step 5: Run the full suite**

Run: `cd GameCore && swift test`
Expected: all tests across all files PASS.

- [ ] **Step 6: Commit**

```bash
git add GameCore/Sources/GameCore/Persistence GameCore/Tests/GameCoreTests/SaveStoreTests.swift
git commit -m "feat: add SaveStore with corruption-safe load"
```

---

## Done criteria

- `cd GameCore && swift test` builds and passes every test.
- `GameCore` has no import of SpriteKit, UIKit, or SwiftUI.
- `Nation`, `Stage`, `MatchResult` models decode/encode via Codable.
- `DataStore.loadNations()` returns the bundled seed (hosts present).
- `SaveStore` round-trips any Codable and returns `nil` for missing/corrupted files.

## What this plan deliberately leaves out

- Game logic (`PenaltyEngine`, `MatchSimulator`, `TournamentEngine`, scoring) → Plan 2.
- The full 48-nation dataset and real groups/calendar → data task in Plan 2.
- SpriteKit gameplay scene and swipe input → Plan 3.
- SwiftUI app shell, screens, and persistence wiring → Plan 4.
- Game Center and audio services → Plan 5.
