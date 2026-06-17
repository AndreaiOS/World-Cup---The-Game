/// The stages of the tournament, in order.
public enum Stage: String, Codable, CaseIterable {
    case group
    case roundOf32
    case roundOf16
    case quarterFinal
    case semiFinal
    case final
}
