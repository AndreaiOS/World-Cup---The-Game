import XCTest
@testable import GameCore

final class KnockoutBracketTests: XCTestCase {
    private func makeQualifiers() -> [Qualifier] {
        // 32 qualifiers, same position so seeding falls through to points:
        // N0 (100 pts) strongest ... N31 (69 pts) weakest. Order is deterministic.
        (0..<32).map { i in
            Qualifier(nationId: "N\(i)", groupId: "G", position: 1,
                      points: 100 - i, goalDifference: 0, goalsFor: 0)
        }
    }

    func testRoundOf32HasSixteenMatches() {
        let r32 = KnockoutBracket.buildRoundOf32(from: makeQualifiers())
        XCTAssertEqual(r32.count, 16)
    }

    func testTopSeedFacesBottomSeed() {
        let qs = makeQualifiers()                  // N0 strongest, N31 weakest
        let r32 = KnockoutBracket.buildRoundOf32(from: qs)
        XCTAssertEqual(r32.first?.homeId, "N0")
        XCTAssertEqual(r32.first?.awayId, "N31")
    }

    func testNextRoundPairsConsecutiveWinners() {
        let matches = [
            BracketMatch(homeId: "A", awayId: "B"),
            BracketMatch(homeId: "C", awayId: "D"),
            BracketMatch(homeId: "E", awayId: "F"),
            BracketMatch(homeId: "G", awayId: "H"),
        ]
        let results = [
            MatchResult(homeId: "A", awayId: "B", homeScore: 3, awayScore: 1), // A
            MatchResult(homeId: "C", awayId: "D", homeScore: 1, awayScore: 2), // D
            MatchResult(homeId: "E", awayId: "F", homeScore: 5, awayScore: 4), // E
            MatchResult(homeId: "G", awayId: "H", homeScore: 0, awayScore: 2), // H
        ]
        let next = KnockoutBracket.nextRound(from: matches, results: results)
        XCTAssertEqual(next, [
            BracketMatch(homeId: "A", awayId: "D"),
            BracketMatch(homeId: "E", awayId: "H"),
        ])
    }

    func testFullBracketReducesToOneWinner() {
        var matches = KnockoutBracket.buildRoundOf32(from: makeQualifiers())
        var rng = SeededGenerator(seed: 1)
        let lookup = Dictionary(uniqueKeysWithValues:
            makeQualifiers().map { ($0.nationId,
                Nation(id: $0.nationId, name: $0.nationId, flag: "🏳️",
                       strength: $0.points)) })
        while matches.count > 1 {
            let results = matches.map { m in
                MatchSimulator.simulate(home: lookup[m.homeId]!,
                                        away: lookup[m.awayId]!, using: &rng)
            }
            matches = KnockoutBracket.nextRound(from: matches, results: results)
        }
        XCTAssertEqual(matches.count, 1) // the final
    }
}
