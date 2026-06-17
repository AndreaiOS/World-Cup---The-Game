import XCTest
@testable import GameCore

private struct SampleSave: Codable, Equatable {
    let nationId: String
    let round: Int
}

final class SaveStoreTests: XCTestCase {
    private func tempURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("json")
    }

    func testSaveThenLoadReturnsIdenticalValue() throws {
        let url = tempURL()
        let store = SaveStore(url: url)
        let value = SampleSave(nationId: "ITA", round: 3)

        try store.save(value)
        let loaded: SampleSave? = try store.load()

        XCTAssertEqual(loaded, value)
        try? FileManager.default.removeItem(at: url)
    }

    func testLoadMissingFileReturnsNil() throws {
        let store = SaveStore(url: tempURL())
        let loaded: SampleSave? = try store.load()
        XCTAssertNil(loaded)
    }

    func testLoadCorruptedFileReturnsNil() throws {
        let url = tempURL()
        try "not valid json".data(using: .utf8)!.write(to: url)
        let store = SaveStore(url: url)

        let loaded: SampleSave? = try store.load()

        XCTAssertNil(loaded)
        try? FileManager.default.removeItem(at: url)
    }
}
