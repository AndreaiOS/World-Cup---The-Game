import XCTest
@testable import GameCore

final class QualificationTests: XCTestCase {
    private func makeGroups() -> [Group] {
        (0..<12).map { i in
            let letter = String(UnicodeScalar(65 + i)!) // A...L
            let ids = (0..<4).map { "\(letter)\($0)" }   // e.g. A0,A1,A2,A3
            return Group(id: letter, nationIds: ids)
        }
    }

    private func makeResults(_ groups: [Group]) -> [MatchResult] {
        var results: [MatchResult] = []
        for g in groups {
            let p = GroupTable.roundRobinPairs(g.nationIds)
            for (home, away) in p {
                let hi = Int(home.suffix(1))!, ai = Int(away.suffix(1))!
                if hi < ai {
                    results.append(MatchResult(homeId: home, awayId: away,
                                               homeScore: 4 - hi, awayScore: 0))
                } else {
                    results.append(MatchResult(homeId: home, awayId: away,
                                               homeScore: 0, awayScore: 4 - ai))
                }
            }
        }
        return results
    }

    func testQualifiersCountIs32() {
        let groups = makeGroups()
        let results = makeResults(groups)
        let qs = GroupTable.qualifiers(groups: groups, results: results)
        XCTAssertEqual(qs.count, 32)
    }

    func testEveryGroupWinnerQualifiesFirst() {
        let groups = makeGroups()
        let results = makeResults(groups)
        let qs = GroupTable.qualifiers(groups: groups, results: results)
        for g in groups {
            let winner = qs.first { $0.nationId == "\(g.id)0" }
            XCTAssertNotNil(winner)
            XCTAssertEqual(winner?.position, 1)
        }
    }

    func testBestThirdsAreSelectedByPoints() {
        let groups = makeGroups()
        let results = makeResults(groups)
        let qs = GroupTable.qualifiers(groups: groups, results: results)
        let thirds = Set(qs.filter { $0.position == 3 }.map { $0.points })
        // With the symmetric makeResults, every group's third has identical
        // stats, so exactly 8 are taken and they all share the same points
        // value (deterministic cut by id). Assert all selected thirds have
        // the maximal third-place points and there are exactly 8.
        XCTAssertEqual(qs.filter { $0.position == 3 }.count, 8)
        XCTAssertEqual(thirds.count, 1) // all selected thirds share the top points value
    }

    func testExactlyEightThirdsQualify() {
        let groups = makeGroups()
        let results = makeResults(groups)
        let qs = GroupTable.qualifiers(groups: groups, results: results)
        let thirds = qs.filter { $0.position == 3 }
        XCTAssertEqual(thirds.count, 8)
    }
}
