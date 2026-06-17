# Activating Game Center & shipping the app

The app is wired for Game Center but inert until you connect an Apple Developer
account and configure App Store Connect.

## 1. Signing
- Regenerate and open the project: `cd App && xcodegen generate`, then open
  `App/WorldFootball.xcodeproj` in Xcode.
- Select the `WorldFootball` target → Signing & Capabilities → pick your Team and
  let Xcode manage signing.

## 2. Game Center capability
- `App/project.yml` already declares the `com.apple.developer.game-center`
  entitlement (regenerating writes `App/WorldFootball.entitlements`). In Xcode's
  Signing & Capabilities you should see **Game Center**; if not, press
  **+ Capability** and add it.

## 3. App Store Connect
- Create the app record (bundle id `co.socialsprint.worldfootball2026`).
- Under Features → Game Center, create a **Leaderboard**:
  - Reference name: Total Score
  - Leaderboard ID: `worldfootball.totalscore` (must match
    `LeaderboardService.leaderboardID`)
  - Score format: Integer, Sort: High to Low.

## 4. Test
- Run on a real device (or a simulator signed into a sandbox Game Center
  account). Sign in when prompted; the floating Game Center access point appears
  top-left and finishing a tournament submits the total score.

## 5. TestFlight / App Store
- Archive (Product → Archive) and upload to App Store Connect via the Organizer,
  then distribute via TestFlight or submit for review.

## Legal reminder
The app uses real nation names/flags and factual schedule data only. Keep all
FIFA marks, official tournament logos/mascots, and real player names out of the
assets. Use an original product name and icon.
