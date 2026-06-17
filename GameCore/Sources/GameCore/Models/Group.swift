/// A first-round group: four nations identified by id.
public struct Group: Codable, Equatable, Identifiable {
    public let id: String          // "A" ... "L"
    public let nationIds: [String] // exactly four nation ids

    public init(id: String, nationIds: [String]) {
        self.id = id
        self.nationIds = nationIds
    }
}
