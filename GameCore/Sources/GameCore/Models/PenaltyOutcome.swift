/// The result of a single penalty.
public enum PenaltyOutcome: String, Codable, Equatable {
    case goal
    case saved
    case miss
}
