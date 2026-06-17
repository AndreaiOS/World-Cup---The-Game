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
