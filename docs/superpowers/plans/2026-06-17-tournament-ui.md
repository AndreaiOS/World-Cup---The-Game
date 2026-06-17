# Tournament UI Implementation Plan

> **For agentic workers:** This plan is verified by BUILDING and RUNNING in the iOS Simulator, not by `swift test`. Execute it INLINE/interactively (superpowers:executing-plans). Steps use checkbox (`- [ ]`) syntax. Build/run recipe is the same as the iOS app plan (scheme `WorldFootball`, simulator UDID `F3CF22C7-067E-482C-84F0-974B6F1843F0`, `simctl terminate` before relaunch).

**Goal:** Turn the single-shootout app into full Tournament mode: pick one of the 48 nations, then play your nation's path (group stage → knockout) one shootout at a time against the real opponents, with the result fed back into `TournamentEngine` and the run persisted with `SaveStore`.

**Architecture:** An `AppModel` (`ObservableObject`) owns the `TournamentSave`, the dataset, and a `SaveStore`, and derives the current `TournamentSnapshot` from `TournamentEngine`. SwiftUI screens (menu → nation select → tournament hub → match) route off the model's state. The existing `PenaltyScene` becomes a configurable per-match view: it takes the opponent's strength and a seed, runs one shootout, and reports the final `(playerScore, opponentScore)` up; the model appends a `MatchResult`, persists, and re-derives the snapshot to advance. All tournament rules stay in `GameCore`.

**Tech Stack:** Swift 5.9, SwiftUI, SpriteKit, XcodeGen, iOS 16 Simulator. Depends on `GameCore` (`TournamentEngine`, `TournamentSave`, `TournamentSnapshot`, `Nation`, `Stage`, `MatchResult`, `DataStore`, `SaveStore`, `ShootoutController`, `SwipeMapper`).

---

## Verification model

- **Build** must succeed every task: `xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball -destination 'platform=iOS Simulator,id=F3CF22C7-067E-482C-84F0-974B6F1843F0' -derivedDataPath /tmp/wf-dd build` → `BUILD SUCCEEDED`.
- **Static screens (Tasks 1-3)** verified by screenshot.
- **Gameplay loop (Task 4)** build/launch automated; the actual play-through (shoot, advance, win/lose group, reach knockout) is verified by the human.
- After adding/removing source files run `cd App && xcodegen generate` before building. Install/launch: `simctl terminate ... co.socialsprint.worldfootball2026` then `install`/`launch`/`io ... screenshot`.

---

## File Structure

```
App/Sources/
├── WorldFootballApp.swift     # MODIFY: inject AppModel, show RootView
├── AppModel.swift             # NEW: ObservableObject — save, dataset, SaveStore, routing
├── RootView.swift             # NEW: routes on model.screen
├── MenuView.swift             # NEW: title + New / Continue
├── NationSelectView.swift     # NEW: grid of 48 nations
├── TournamentHubView.swift    # NEW: stage, opponent, standings, Play; + eliminated/champion
├── MatchView.swift            # NEW: hosts PenaltyScene for one match, reports result
├── PenaltyScene.swift         # MODIFY: configurable opponentStrength/seed + onComplete
├── GoalGeometry.swift         # unchanged
├── SwipeReader.swift          # unchanged
└── GameView.swift             # DELETE: replaced by RootView + MatchView
```

---

## Task 1: AppModel + RootView routing

**Files:**
- Create: `App/Sources/AppModel.swift`
- Create: `App/Sources/RootView.swift`
- Modify: `App/Sources/WorldFootballApp.swift`
- Delete: `App/Sources/GameView.swift`

- [ ] **Step 1: Write `App/Sources/AppModel.swift`**

```swift
import SwiftUI
import GameCore

@MainActor
final class AppModel: ObservableObject {
    enum Screen: Equatable { case menu, nationSelect, hub, match }

    @Published var screen: Screen = .menu
    @Published private(set) var save: TournamentSave?

    let nations: [Nation]
    let groups: [Group]
    private let byId: [String: Nation]
    private let store: SaveStore
    private let saveURL: URL

    init() {
        nations = (try? DataStore.loadNations()) ?? []
        groups = (try? DataStore.loadGroups()) ?? []
        byId = Dictionary(uniqueKeysWithValues: nations.map { ($0.id, $0) })
        saveURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("tournament.json")
        store = SaveStore(url: saveURL)
        do { save = try store.load() } catch { save = nil }
    }

    var hasSave: Bool { save != nil }

    func nation(_ id: String?) -> Nation? { id.flatMap { byId[$0] } }

    var snapshot: TournamentSnapshot? {
        guard let save else { return nil }
        return TournamentEngine.snapshot(nations: nations, groups: groups, save: save)
    }

    func goToNationSelect() { screen = .nationSelect }

    func startTournament(nationId: String) {
        save = TournamentSave(playerNationId: nationId, seed: UInt64.random(in: 1...999_999))
        persist()
        screen = .hub
    }

    func continueTournament() { screen = .hub }

    func playMatch() { screen = .match }

    /// A per-match seed for the interactive shootout's own AI randomness.
    /// Independent of the tournament simulation; only affects how the played
    /// match feels, not the recorded result.
    var matchSeed: UInt64 {
        guard let save else { return 1 }
        return save.seed &+ UInt64(save.playerResults.count) &+ 1
    }

    func recordMatch(playerScore: Int, opponentScore: Int) {
        guard var s = save, let oppId = snapshot?.opponentId else { return }
        s.playerResults.append(MatchResult(homeId: s.playerNationId, awayId: oppId,
                                           homeScore: playerScore, awayScore: opponentScore))
        save = s
        persist()
        screen = .hub
    }

    func abandonToMenu() { screen = .menu }

    func resetAndChooseNation() {
        save = nil
        try? FileManager.default.removeItem(at: saveURL)
        screen = .nationSelect
    }

    private func persist() {
        guard let save else { return }
        try? store.save(save)
    }
}
```

- [ ] **Step 2: Write `App/Sources/RootView.swift`**

```swift
import SwiftUI

struct RootView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        switch model.screen {
        case .menu:         MenuView(model: model)
        case .nationSelect: NationSelectView(model: model)
        case .hub:          TournamentHubView(model: model)
        case .match:        MatchView(model: model)
        }
    }
}
```

- [ ] **Step 3: Point the app at `RootView`** — replace the body of `App/Sources/WorldFootballApp.swift`:

```swift
import SwiftUI

@main
struct WorldFootballApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}
```

- [ ] **Step 4: Delete the obsolete single-shootout view**

```bash
rm App/Sources/GameView.swift
```

> The screens referenced by `RootView` (`MenuView`, `NationSelectView`,
> `TournamentHubView`, `MatchView`) are created in Tasks 2-4. The project will
> not build until Task 4; that is expected. To keep Task 1 independently
> verifiable, the next step adds minimal placeholder stubs that Tasks 2-4 replace.

- [ ] **Step 5: Add temporary stubs so Task 1 builds** — create `App/Sources/_Stubs.swift`:

```swift
import SwiftUI

struct MenuView: View {
    let model: AppModel
    var body: some View { Text("Menu").onAppear { } }
}
struct NationSelectView: View {
    let model: AppModel
    var body: some View { Text("Nation Select") }
}
struct TournamentHubView: View {
    let model: AppModel
    var body: some View { Text("Hub") }
}
struct MatchView: View {
    let model: AppModel
    var body: some View { Text("Match") }
}
```

- [ ] **Step 6: Build, launch, screenshot**

```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,id=F3CF22C7-067E-482C-84F0-974B6F1843F0' -derivedDataPath /tmp/wf-dd build
xcrun simctl terminate booted co.socialsprint.worldfootball2026 2>/dev/null || true
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: `BUILD SUCCEEDED`; screenshot shows "Menu".

- [ ] **Step 7: Commit**

```bash
git add App/Sources/AppModel.swift App/Sources/RootView.swift App/Sources/WorldFootballApp.swift App/Sources/_Stubs.swift
git rm App/Sources/GameView.swift
git commit -m "feat: add AppModel and RootView routing for tournament mode"
```

---

## Task 2: Menu and nation selection

**Files:**
- Create: `App/Sources/MenuView.swift`
- Create: `App/Sources/NationSelectView.swift`
- Modify: `App/Sources/_Stubs.swift` (remove the `MenuView` and `NationSelectView` stubs)

- [ ] **Step 1: Write `App/Sources/MenuView.swift`**

```swift
import SwiftUI

struct MenuView: View {
    @ObservedObject var model: AppModel

    var body: some View {
        ZStack {
            LinearGradient(colors: [.green, .teal], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()
                Text("WORLD\nFOOTBALL")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 52, weight: .black, design: .rounded))
                    .foregroundColor(.white)
                Text("2026")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white.opacity(0.9))
                Spacer()
                if model.hasSave, let snap = model.snapshot, snap.phase == .playing {
                    Button("CONTINUE") { model.continueTournament() }
                        .buttonStyle(MenuButton(primary: true))
                }
                Button("NEW TOURNAMENT") { model.goToNationSelect() }
                    .buttonStyle(MenuButton(primary: !model.hasSave))
                Spacer().frame(height: 40)
            }
            .padding(.horizontal, 32)
        }
    }
}

struct MenuButton: ButtonStyle {
    let primary: Bool
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3.bold())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(primary ? Color.white : Color.white.opacity(0.2))
            .foregroundColor(primary ? .green : .white)
            .clipShape(Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
```

- [ ] **Step 2: Write `App/Sources/NationSelectView.swift`**

```swift
import SwiftUI
import GameCore

struct NationSelectView: View {
    @ObservedObject var model: AppModel

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.30, blue: 0.16).ignoresSafeArea()
            VStack(spacing: 0) {
                Text("CHOOSE YOUR NATION")
                    .font(.headline.bold())
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(model.nations.sorted { $0.strength > $1.strength }, id: \.id) { nation in
                            Button { model.startTournament(nationId: nation.id) } label: {
                                VStack(spacing: 6) {
                                    Text(nation.flag).font(.system(size: 40))
                                    Text(nation.name)
                                        .font(.caption2.bold())
                                        .foregroundColor(.white)
                                        .lineLimit(1).minimumScaleFactor(0.7)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.white.opacity(0.10))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                }
                Button("Back") { model.abandonToMenu() }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.vertical, 12)
            }
        }
    }
}
```

- [ ] **Step 3: Remove the now-replaced stubs** — in `App/Sources/_Stubs.swift`, delete the `MenuView` and `NationSelectView` structs (keep only `TournamentHubView` and `MatchView`). The file becomes:

```swift
import SwiftUI

struct TournamentHubView: View {
    let model: AppModel
    var body: some View { Text("Hub") }
}
struct MatchView: View {
    let model: AppModel
    var body: some View { Text("Match") }
}
```

- [ ] **Step 4: Regenerate, build, launch, screenshot**

```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,id=F3CF22C7-067E-482C-84F0-974B6F1843F0' -derivedDataPath /tmp/wf-dd build
xcrun simctl terminate booted co.socialsprint.worldfootball2026 2>/dev/null || true
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: `BUILD SUCCEEDED`; screenshot shows the "WORLD FOOTBALL 2026" menu with a "NEW TOURNAMENT" button. (Tapping through to the nation grid is a human check; the grid shows 48 nations with flags.)

- [ ] **Step 5: Commit**

```bash
git add App/Sources/MenuView.swift App/Sources/NationSelectView.swift App/Sources/_Stubs.swift
git commit -m "feat: add menu and nation selection screens"
```

---

## Task 3: Tournament hub (stage, opponent, standings, result)

**Files:**
- Create: `App/Sources/TournamentHubView.swift`
- Modify: `App/Sources/_Stubs.swift` (remove the `TournamentHubView` stub)

- [ ] **Step 1: Write `App/Sources/TournamentHubView.swift`**

```swift
import SwiftUI
import GameCore

struct TournamentHubView: View {
    @ObservedObject var model: AppModel

    private func stageName(_ stage: Stage) -> String {
        switch stage {
        case .group: return "GROUP STAGE"
        case .roundOf32: return "ROUND OF 32"
        case .roundOf16: return "ROUND OF 16"
        case .quarterFinal: return "QUARTER-FINAL"
        case .semiFinal: return "SEMI-FINAL"
        case .final: return "FINAL"
        }
    }

    var body: some View {
        ZStack {
            Color(red: 0.10, green: 0.30, blue: 0.16).ignoresSafeArea()
            if let snap = model.snapshot {
                switch snap.phase {
                case .champion:   resultScreen(title: "CHAMPIONS!", emoji: "🏆", color: .yellow)
                case .eliminated: resultScreen(title: "ELIMINATED", emoji: "😞", color: .red)
                case .playing:    playingScreen(snap)
                }
            } else {
                Text("No tournament").foregroundColor(.white)
            }
        }
    }

    @ViewBuilder
    private func playingScreen(_ snap: TournamentSnapshot) -> some View {
        let you = model.nation(model.save?.playerNationId)
        let opp = model.nation(snap.opponentId)
        VStack(spacing: 20) {
            Text(stageName(snap.stage))
                .font(.headline.bold()).foregroundColor(.white.opacity(0.85))
                .padding(.top, 24)

            HStack(spacing: 16) {
                nationBadge(you)
                Text("vs").font(.title3.bold()).foregroundColor(.white.opacity(0.7))
                nationBadge(opp)
            }
            .padding(.vertical, 8)

            if snap.stage == .group {
                standings(snap.playerGroupStandings)
            }

            Spacer()

            Button("PLAY MATCH") { model.playMatch() }
                .font(.title3.bold())
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(.white).foregroundColor(.green)
                .clipShape(Capsule())
                .padding(.horizontal, 32)
            Button("Quit to menu") { model.abandonToMenu() }
                .foregroundColor(.white.opacity(0.7))
                .padding(.bottom, 24)
        }
    }

    private func nationBadge(_ nation: Nation?) -> some View {
        VStack(spacing: 4) {
            Text(nation?.flag ?? "🏳️").font(.system(size: 44))
            Text(nation?.name ?? "—").font(.caption.bold())
                .foregroundColor(.white).lineLimit(1).minimumScaleFactor(0.7)
        }
        .frame(width: 110)
    }

    private func standings(_ rows: [GroupStanding]) -> some View {
        VStack(spacing: 6) {
            ForEach(rows, id: \.nationId) { row in
                HStack {
                    Text(model.nation(row.nationId)?.flag ?? "🏳️")
                    Text(model.nation(row.nationId)?.name ?? row.nationId)
                        .font(.caption).foregroundColor(.white).lineLimit(1)
                    Spacer()
                    Text("\(row.wins)-\(row.losses)").font(.caption2).foregroundColor(.white.opacity(0.7))
                    Text("\(row.points) pts").font(.caption.bold()).foregroundColor(.white)
                        .frame(width: 54, alignment: .trailing)
                }
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(row.nationId == model.save?.playerNationId
                            ? Color.white.opacity(0.18) : Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.horizontal, 24)
    }

    private func resultScreen(title: String, emoji: String, color: Color) -> some View {
        VStack(spacing: 24) {
            Spacer()
            Text(emoji).font(.system(size: 90))
            Text(title).font(.system(size: 44, weight: .black, design: .rounded))
                .foregroundColor(color)
            if let you = model.nation(model.save?.playerNationId) {
                Text("\(you.flag) \(you.name)").font(.title3.bold()).foregroundColor(.white)
            }
            Spacer()
            Button("NEW TOURNAMENT") { model.resetAndChooseNation() }
                .font(.title3.bold())
                .frame(maxWidth: .infinity).padding(.vertical, 16)
                .background(.white).foregroundColor(.green).clipShape(Capsule())
                .padding(.horizontal, 32)
            Button("Menu") { model.abandonToMenu() }
                .foregroundColor(.white.opacity(0.7)).padding(.bottom, 24)
        }
    }
}
```

- [ ] **Step 2: Remove the hub stub** — in `App/Sources/_Stubs.swift`, delete the `TournamentHubView` struct. The file becomes:

```swift
import SwiftUI

struct MatchView: View {
    let model: AppModel
    var body: some View { Text("Match") }
}
```

- [ ] **Step 3: Regenerate, build, launch, screenshot the hub**

To reach the hub from a fresh launch the human taps New Tournament → a nation;
for an automated screenshot we rely on the build succeeding and the menu render.

```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,id=F3CF22C7-067E-482C-84F0-974B6F1843F0' -derivedDataPath /tmp/wf-dd build
xcrun simctl terminate booted co.socialsprint.worldfootball2026 2>/dev/null || true
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: `BUILD SUCCEEDED`; app launches at the menu. **Human check:** New Tournament → pick a nation → the hub shows GROUP STAGE, you-vs-opponent badges, the four-team group standings, and a PLAY MATCH button.

- [ ] **Step 4: Commit**

```bash
git add App/Sources/TournamentHubView.swift App/Sources/_Stubs.swift
git commit -m "feat: add tournament hub with stage, opponent, standings, result screens"
```

---

## Task 4: Configurable PenaltyScene + MatchView — the full loop

**Files:**
- Modify: `App/Sources/PenaltyScene.swift` (configurable opponent strength/seed + `onComplete`)
- Create: `App/Sources/MatchView.swift`
- Delete: `App/Sources/_Stubs.swift`

- [ ] **Step 1: Make `PenaltyScene` configurable** — replace the controller/config declarations and add completion reporting. In `PenaltyScene.swift`, replace this block:

```swift
    private let controller = ShootoutController(opponentStrength: 75,
                                                seed: UInt64.random(in: 1...999_999))
```

with:

```swift
    var opponentStrength: Int = 75
    var matchSeed: UInt64 = 1
    /// Called once when the shootout is decided, with the final score.
    var onComplete: ((Int, Int) -> Void)?
    private var controller: ShootoutController!
    private var reported = false
```

Then in `didMove(to:)`, build the controller before anything that uses it — add as the FIRST line of `didMove`:

```swift
        controller = ShootoutController(opponentStrength: opponentStrength, seed: matchSeed)
```

- [ ] **Step 2: Report completion when the shootout is decided** — in `PenaltyScene.swift`, in BOTH `finishKick(_:)` and `finishKeep(_:)`, inside the final `.run { ... }` block right after `self.updatePrompt()`, add the completion check. The block in each becomes:

```swift
                self.busy = false
                self.updatePrompt()
                self.reportIfFinished()
```

Then add this method to `PenaltyScene`:

```swift
    private func reportIfFinished() {
        guard !reported, controller.state().isOver else { return }
        reported = true
        let s = controller.state()
        run(.sequence([
            .wait(forDuration: 0.6),
            .run { [weak self] in self?.onComplete?(s.playerScore, s.opponentScore) }
        ]))
    }
```

- [ ] **Step 3: Write `App/Sources/MatchView.swift`**

```swift
import SwiftUI
import SpriteKit
import GameCore

struct MatchView: View {
    let model: AppModel
    @State private var playerScore = 0
    @State private var opponentScore = 0
    @State private var scene: PenaltyScene

    init(model: AppModel) {
        self.model = model
        let scene = PenaltyScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .aspectFill
        scene.opponentStrength = model.nation(model.snapshot?.opponentId)?.strength ?? 70
        scene.matchSeed = model.matchSeed
        _scene = State(initialValue: scene)
    }

    var body: some View {
        ZStack(alignment: .top) {
            SpriteView(scene: scene)
                .ignoresSafeArea()
            HStack {
                badge(model.nation(model.save?.playerNationId))
                Text("\(playerScore) – \(opponentScore)")
                    .font(.system(size: 30, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 18).padding(.vertical, 6)
                    .background(.black.opacity(0.35), in: Capsule())
                badge(model.nation(model.snapshot?.opponentId))
            }
            .padding(.top, 12)
        }
        .onAppear {
            scene.onStateChange = { state in
                playerScore = state.playerScore
                opponentScore = state.opponentScore
            }
            scene.onComplete = { p, o in
                model.recordMatch(playerScore: p, opponentScore: o)
            }
        }
    }

    private func badge(_ nation: Nation?) -> some View {
        Text(nation?.flag ?? "🏳️").font(.system(size: 28))
    }
}
```

- [ ] **Step 4: Delete the stubs file**

```bash
rm App/Sources/_Stubs.swift
```

- [ ] **Step 5: Regenerate, build, launch**

```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,id=F3CF22C7-067E-482C-84F0-974B6F1843F0' -derivedDataPath /tmp/wf-dd build
xcrun simctl terminate booted co.socialsprint.worldfootball2026 2>/dev/null || true
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: `BUILD SUCCEEDED`; app launches at the menu.
**Human play-through check:** New Tournament → pick a nation → hub shows your first group opponent → PLAY MATCH → take the shootout → it returns to the hub with the result recorded, standings updated, and the next opponent shown. Play all three group matches; if you finish top-2 (or as a best third) you advance to the knockout, otherwise you see ELIMINATED. Winning through to the Final and winning it shows CHAMPIONS! Quitting to the menu and relaunching offers CONTINUE (the run is persisted).

- [ ] **Step 6: Commit**

```bash
git add App/Sources/PenaltyScene.swift App/Sources/MatchView.swift
git rm App/Sources/_Stubs.swift
git commit -m "feat: configurable penalty scene and match view; full tournament loop"
```

---

## Done criteria

- `xcodebuild ... build` succeeds.
- The app launches at a menu, lets you pick one of the 48 nations, and plays your
  nation's tournament path one shootout at a time, with the opponent's real
  strength, advancing through groups and knockout via `TournamentEngine`.
- Each result is recorded into `TournamentSave` and persisted with `SaveStore`;
  CONTINUE resumes a run after relaunch.
- ELIMINATED and CHAMPIONS! screens end the run; NEW TOURNAMENT restarts.
- All tournament rules and persistence come from `GameCore`.

## What this plan deliberately leaves out

- Aggregating the run into `TournamentStats` and submitting to Game Center, plus
  audio → services plan. (The hub could later show a final score via
  `ScoreCalculator`.)
- Showing other groups' tables and the full bracket tree (only the player's group
  standings and next opponent are shown) — a possible later polish.
- Art/animation polish beyond the existing scene; swipe tuning is already in place.
```
