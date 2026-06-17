import XCTest
@testable import GameCore

final class DataStoreTests: XCTestCase {
    func testDecodesNationsFromData() throws {
        let url = Bundle.module.url(forResource: "nations_fixture",
                                    withExtension: "json")!
        let data = try Data(contentsOf: url)

        let nations = try DataStore.decodeNations(from: data)

        XCTAssertEqual(nations.count, 3)
        XCTAssertEqual(nations.first?.id, "CAN")
        XCTAssertTrue(nations.contains(where: { $0.id == "USA" }))
    }

    func testLoadsBundledSeed() throws {
        let nations = try DataStore.loadNations()
        XCTAssertFalse(nations.isEmpty)
        XCTAssertTrue(nations.contains(where: { $0.id == "USA" }))
        XCTAssertTrue(nations.contains(where: { $0.id == "CAN" }))
        XCTAssertTrue(nations.contains(where: { $0.id == "MEX" }))
    }
}
