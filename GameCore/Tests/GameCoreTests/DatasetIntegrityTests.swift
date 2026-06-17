import XCTest
@testable import GameCore

final class DatasetIntegrityTests: XCTestCase {
    func testHas48UniqueNations() throws {
        let nations = try DataStore.loadNations()
        XCTAssertEqual(nations.count, 48)
        XCTAssertEqual(Set(nations.map { $0.id }).count, 48)
    }

    func testStrengthsInRange() throws {
        for n in try DataStore.loadNations() {
            XCTAssertTrue((1...100).contains(n.strength), "\(n.id)=\(n.strength)")
        }
    }

    func testTwelveGroupsPartitionAll48Nations() throws {
        let nations = try DataStore.loadNations()
        let groups = try DataStore.loadGroups()
        let nationIds = Set(nations.map { $0.id })

        XCTAssertEqual(groups.count, 12)
        var seen = Set<String>()
        for g in groups {
            XCTAssertEqual(g.nationIds.count, 4, "group \(g.id) size")
            for id in g.nationIds {
                XCTAssertTrue(nationIds.contains(id), "unknown nation \(id)")
                XCTAssertFalse(seen.contains(id), "\(id) in two groups")
                seen.insert(id)
            }
        }
        XCTAssertEqual(seen.count, 48)
    }

    func testHostsPresent() throws {
        let ids = Set(try DataStore.loadNations().map { $0.id })
        XCTAssertTrue(ids.isSuperset(of: ["CAN", "MEX", "USA"]))
    }
}
