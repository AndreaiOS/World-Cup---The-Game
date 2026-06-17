/// Turns a tournament run into a single Game Center score.
public enum ScoreCalculator {
    public static func totalScore(_ stats: TournamentStats) -> Int {
        stats.goalsScored * 100
            + stats.saves * 60
            + stats.matchesWon * 250
            + (stats.wonTournament ? 1000 : 0)
    }
}
