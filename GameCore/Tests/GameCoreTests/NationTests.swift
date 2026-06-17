import XCTest
@testable import GameCore

final class NationTests: XCTestCase {
    func testDecodesFromJSON() throws {
        let json = """
        { "id": "ITA", "name": "Italy", "flag": "🇮🇹", "strength": 84 }
        """.data(using: .utf8)!

        let nation = try JSONDecoder().decode(Nation.self, from: json)

        XCTAssertEqual(nation.id, "ITA")
        XCTAssertEqual(nation.name, "Italy")
        XCTAssertEqual(nation.flag, "🇮🇹")
        XCTAssertEqual(nation.strength, 84)
    }

    func testEquatableById() {
        let a = Nation(id: "ITA", name: "Italy", flag: "🇮🇹", strength: 84)
        let b = Nation(id: "ITA", name: "Italy", flag: "🇮🇹", strength: 84)
        XCTAssertEqual(a, b)
    }
}
