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
            // interrupting the game. Show the floating access point only when
            // actually signed in (inert on a bare simulator build).
            if GKLocalPlayer.local.isAuthenticated {
                GKAccessPoint.shared.location = .topLeading
                GKAccessPoint.shared.isActive = true
            }
        }
    }

    func submit(score: Int) {
        guard score > 0, GKLocalPlayer.local.isAuthenticated else { return }
        GKLeaderboard.submitScore(score, context: 0, player: GKLocalPlayer.local,
                                  leaderboardIDs: [Self.leaderboardID]) { _ in }
    }
}
