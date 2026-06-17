# Services: Audio + Game Center Implementation Plan

> **For agentic workers:** Verified by BUILDING and RUNNING in the iOS Simulator (audio is verified by the human listening; Game Center degrades gracefully and is verified by build + no crash). Execute INLINE/interactively (superpowers:executing-plans). Build/run recipe as before (scheme `WorldFootball`, simulator UDID `F3CF22C7-067E-482C-84F0-974B6F1843F0`, `simctl terminate` before relaunch).

**Goal:** Add sound effects to the shootout (synthesized in code, no asset files) with a mute toggle, and wire a Game Center leaderboard service that submits the tournament total score — code-complete and graceful, ready to activate once a leaderboard is configured in App Store Connect.

**Architecture:** An `AudioManager` synthesizes short tone/noise buffers with `AVAudioEngine` for kick/goal/save/miss, gated by a persisted mute flag; `PenaltyScene` calls it on the relevant events. A `LeaderboardService` wraps GameKit: it authenticates the local player on launch and submits `ScoreCalculator.totalScore(...)` when a tournament ends. Without a configured leaderboard / Game Center capability it no-ops silently (the spec's "works offline" requirement). All scoring math stays in `GameCore`.

**Tech Stack:** Swift 5.9, AVFoundation (AVAudioEngine), GameKit, SwiftUI/SpriteKit. Depends on `GameCore` (`ScoreCalculator`, `TournamentStats`, `MatchResult`, `TournamentSave`).

---

## Verification model

- **Build** must succeed each task.
- **Audio (Tasks 1-2):** the human plays a shootout and hears a thud on each kick and a distinct tone for goal / save / miss; the menu mute button silences them.
- **Game Center (Tasks 3-4):** build succeeds and the app does not crash. On a bare simulator dev build Game Center is unavailable, so authentication fails silently and submission no-ops — that is the intended graceful state. Full operation requires the user to add the Game Center capability and a leaderboard with id `worldfootball.totalscore` in App Store Connect (documented in Done criteria).

---

## File Structure

```
App/Sources/
├── AudioManager.swift        # NEW: synthesized SFX + mute (AVAudioEngine)
├── LeaderboardService.swift  # NEW: GameKit auth + score submission
├── PenaltyScene.swift        # MODIFY: play SFX on kick/goal/save/miss
├── MenuView.swift            # MODIFY: mute toggle button
├── AppModel.swift            # MODIFY: total score + submit on tournament end
├── RootView.swift            # MODIFY: authenticate Game Center on appear
└── TournamentHubView.swift   # MODIFY: show total score on the result screen
```

---

## Task 1: AudioManager — synthesized sound effects + mute

**Files:**
- Create: `App/Sources/AudioManager.swift`

- [ ] **Step 1: Write `App/Sources/AudioManager.swift`**

```swift
import AVFoundation

/// Plays short synthesized sound effects. No audio asset files — each effect is
/// a generated tone/noise buffer. Gated by a persisted mute flag.
final class AudioManager {
    static let shared = AudioManager()
    enum SFX { case kick, goal, save, miss }

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
    private var started = false

    var isMuted: Bool {
        didSet { UserDefaults.standard.set(isMuted, forKey: "audio.muted") }
    }

    private init() {
        isMuted = UserDefaults.standard.bool(forKey: "audio.muted")
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    private func startIfNeeded() {
        guard !started else { return }
        try? AVAudioSession.sharedInstance().setCategory(.ambient, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
        try? engine.start()
        player.play()
        started = engine.isRunning
    }

    func play(_ sfx: SFX) {
        guard !isMuted else { return }
        startIfNeeded()
        guard engine.isRunning else { return }
        player.scheduleBuffer(buffer(for: sfx), at: nil, options: [], completionHandler: nil)
    }

    private func buffer(for sfx: SFX) -> AVAudioPCMBuffer {
        switch sfx {
        case .kick: return tone(freqs: [140], duration: 0.12, decay: 14, noise: 0.18)
        case .goal: return tone(freqs: [523, 659, 784], duration: 0.45, decay: 4)
        case .save: return tone(freqs: [320], duration: 0.16, decay: 10, noise: 0.6)
        case .miss: return tone(freqs: [196], duration: 0.30, decay: 5)
        }
    }

    private func tone(freqs: [Double], duration: Double, decay: Double,
                      noise: Double = 0) -> AVAudioPCMBuffer {
        let sr = 44_100.0
        let count = AVAudioFrameCount(duration * sr)
        let buf = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: count)!
        buf.frameLength = count
        let channel = buf.floatChannelData![0]
        for i in 0..<Int(count) {
            let t = Double(i) / sr
            var sample = 0.0
            for f in freqs { sample += sin(2 * .pi * f * t) }
            sample /= Double(freqs.count)
            if noise > 0 { sample = sample * (1 - noise) + noise * Double.random(in: -1...1) }
            channel[i] = Float(sample * exp(-t * decay) * 0.35)
        }
        return buf
    }
}
```

- [ ] **Step 2: Regenerate and build**

```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,id=F3CF22C7-067E-482C-84F0-974B6F1843F0' -derivedDataPath /tmp/wf-dd build
```
Expected: `BUILD SUCCEEDED` (AudioManager compiles; not yet wired).

- [ ] **Step 3: Commit**

```bash
git add App/Sources/AudioManager.swift
git commit -m "feat: add AudioManager with synthesized sound effects"
```

---

## Task 2: Wire audio into the scene + mute toggle in the menu

**Files:**
- Modify: `App/Sources/PenaltyScene.swift`
- Modify: `App/Sources/MenuView.swift`

- [ ] **Step 1: Play a kick sound when a shot is taken** — in `PenaltyScene.swift`, at the START of `shoot(_:)` (right after `busy = true`):

```swift
        AudioManager.shared.play(.kick)
```

and at the START of `dive(_:)` (right after `busy = true`):

```swift
        AudioManager.shared.play(.kick)
```

- [ ] **Step 2: Play the outcome sound** — in `PenaltyScene.swift`, at the START of `flashOutcome(_:)` (first line of the method body):

```swift
        AudioManager.shared.play(outcome == .goal ? .goal : outcome == .saved ? .save : .miss)
```

- [ ] **Step 3: Add a mute toggle to the menu** — in `MenuView.swift`, add mute state and a button. Replace the whole `MenuView` struct with:

```swift
struct MenuView: View {
    @ObservedObject var model: AppModel
    @State private var muted = AudioManager.shared.isMuted

    var body: some View {
        ZStack(alignment: .topTrailing) {
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

            Button {
                muted.toggle()
                AudioManager.shared.isMuted = muted
            } label: {
                Image(systemName: muted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                    .font(.title2)
                    .foregroundColor(.white)
                    .padding(16)
            }
        }
    }
}
```

- [ ] **Step 4: Regenerate, build, launch**

```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,id=F3CF22C7-067E-482C-84F0-974B6F1843F0' -derivedDataPath /tmp/wf-dd build
xcrun simctl terminate booted co.socialsprint.worldfootball2026 2>/dev/null || true
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: `BUILD SUCCEEDED`; the menu shows a speaker icon in the top-right.
**Human check:** start a match and take a shot — a thud plays on the kick and a distinct tone on GOAL / SAVED / MISS; the speaker button mutes/unmutes and the choice persists across relaunch.

- [ ] **Step 5: Commit**

```bash
git add App/Sources/PenaltyScene.swift App/Sources/MenuView.swift
git commit -m "feat: play shootout sound effects and add menu mute toggle"
```

---

## Task 3: LeaderboardService + Game Center authentication

**Files:**
- Create: `App/Sources/LeaderboardService.swift`
- Modify: `App/Sources/RootView.swift`

- [ ] **Step 1: Write `App/Sources/LeaderboardService.swift`**

```swift
import GameKit

/// Wraps Game Center. Authenticates the local player and submits the tournament
/// total score. If Game Center is unavailable or the leaderboard is not yet
/// configured in App Store Connect, every call no-ops silently (offline-safe).
final class LeaderboardService {
    static let shared = LeaderboardService()

    /// Create a leaderboard with this id in App Store Connect to go live.
    static let leaderboardID = "worldfootball.totalscore"

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { _, _ in
            // Intentionally ignore the presenting view controller and errors:
            // if sign-in is needed or unavailable we stay offline rather than
            // interrupting the game.
        }
    }

    func submit(score: Int) {
        guard score > 0, GKLocalPlayer.local.isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.leaderboardID]) { _ in }
    }
}
```

- [ ] **Step 2: Authenticate on launch** — in `RootView.swift`, add an `.onAppear` to the switch's container. Replace the whole `RootView` struct with:

```swift
import SwiftUI

struct RootView: View {
    @StateObject private var model = AppModel()

    var body: some View {
        Group {
            switch model.screen {
            case .menu:         MenuView(model: model)
            case .nationSelect: NationSelectView(model: model)
            case .hub:          TournamentHubView(model: model)
            case .match:        MatchView(model: model)
            }
        }
        .onAppear { LeaderboardService.shared.authenticate() }
    }
}
```

- [ ] **Step 3: Regenerate and build**

```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,id=F3CF22C7-067E-482C-84F0-974B6F1843F0' -derivedDataPath /tmp/wf-dd build
xcrun simctl terminate booted co.socialsprint.worldfootball2026 2>/dev/null || true
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: `BUILD SUCCEEDED`; the app launches and does not crash. (On the simulator dev build Game Center is unavailable, so no sign-in banner appears — that is the graceful state.)

- [ ] **Step 4: Commit**

```bash
git add App/Sources/LeaderboardService.swift App/Sources/RootView.swift
git commit -m "feat: add LeaderboardService and authenticate Game Center on launch"
```

---

## Task 4: Submit the total score and show it on the result screen

**Files:**
- Modify: `App/Sources/AppModel.swift`
- Modify: `App/Sources/TournamentHubView.swift`

The run's stats are derived from `save.playerResults`: goals scored = sum of the
player's shootout scores, matches won = results the player won, champion = the
terminal phase. (Per-match saves are not persisted, so `saves` is 0 in v1 — a
documented simplification.)

- [ ] **Step 1: Add total-score computation and submission to `AppModel.swift`** — add these methods inside `AppModel`:

```swift
    var totalScore: Int {
        guard let save else { return 0 }
        let goals = save.playerResults.reduce(0) { $0 + $1.homeScore }
        let wins = save.playerResults.filter { $0.winnerId == save.playerNationId }.count
        let won = snapshot?.phase == .champion
        let stats = TournamentStats(goalsScored: goals, saves: 0,
                                    matchesWon: wins, wonTournament: won)
        return ScoreCalculator.totalScore(stats)
    }

    private func submitScoreIfFinished() {
        guard let snap = snapshot, snap.phase != .playing else { return }
        LeaderboardService.shared.submit(score: totalScore)
    }
```

- [ ] **Step 2: Call submission when a match ends the tournament** — in `AppModel.recordMatch(playerScore:opponentScore:)`, after `persist()` and before `screen = .hub`, add:

```swift
        submitScoreIfFinished()
```

- [ ] **Step 3: Show the score on the result screen** — in `TournamentHubView.swift`, in `resultScreen(title:emoji:color:)`, add a score line after the nation line. Replace the `if let you = ...` block with:

```swift
            if let you = model.nation(model.save?.playerNationId) {
                Text("\(you.flag) \(you.name)").font(.title3.bold()).foregroundColor(.white)
            }
            Text("Score: \(model.totalScore)")
                .font(.title2.bold()).foregroundColor(.white.opacity(0.9))
```

- [ ] **Step 4: Regenerate, build, launch**

```bash
cd App && xcodegen generate && cd ..
xcodebuild -project App/WorldFootball.xcodeproj -scheme WorldFootball \
  -destination 'platform=iOS Simulator,id=F3CF22C7-067E-482C-84F0-974B6F1843F0' -derivedDataPath /tmp/wf-dd build
xcrun simctl terminate booted co.socialsprint.worldfootball2026 2>/dev/null || true
xcrun simctl install booted /tmp/wf-dd/Build/Products/Debug-iphonesimulator/WorldFootball.app
xcrun simctl launch booted co.socialsprint.worldfootball2026
sleep 2 && xcrun simctl io booted screenshot /tmp/wf.png
```
Expected: `BUILD SUCCEEDED`.
**Human check:** finish a tournament (win it or get eliminated) — the result screen shows "Score: N". (Submission to Game Center is attempted but no-ops until the leaderboard is configured.)

- [ ] **Step 5: Commit**

```bash
git add App/Sources/AppModel.swift App/Sources/TournamentHubView.swift
git commit -m "feat: compute and show total score; submit to Game Center on finish"
```

---

## Done criteria

- `xcodebuild ... build` succeeds.
- The shootout plays a kick sound and distinct goal/save/miss tones; a menu
  speaker button mutes/unmutes and persists the choice.
- A finished tournament shows the total score (`ScoreCalculator`) and attempts a
  Game Center submission that degrades gracefully when Game Center is unavailable.

### To activate Game Center (user, when publishing)

1. In Xcode, add the **Game Center** capability to the WorldFootball target (this
   adds the `com.apple.developer.game-center` entitlement and requires a signing
   team / provisioning profile).
2. In **App Store Connect**, create the app record, then a **leaderboard** with
   the id `worldfootball.totalscore` (single best score, integer, higher is
   better).
3. Run on a real device (or a simulator signed into a sandbox Game Center
   account). Authentication will then succeed and scores will submit.

## What this plan deliberately leaves out

- Background music (the menu/gameplay loop) — only short SFX are synthesized for
  v1; a music track would need an audio asset.
- Persisting per-match saves to feed the `saves` component of the score (it is 0
  in v1). Recording saves would be a small `GameCore` addition (extend the saved
  result) for a future pass.
- A crowd-ambience bed and richer mixing.
