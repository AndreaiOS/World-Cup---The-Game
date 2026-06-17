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

    /// Load the 12 groups shipped with the package bundle.
    public static func loadGroups() throws -> [Group] {
        guard let url = Bundle.module.url(forResource: "groups",
                                          withExtension: "json") else {
            throw DataError.resourceNotFound("groups.json")
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([Group].self, from: data)
    }
}
