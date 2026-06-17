import XCTest
@testable import GameCore

final class SeededGeneratorTests: XCTestCase {
    func testSameSeedProducesSameSequence() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        let seqA = (0..<5).map { _ in a.next() }
        let seqB = (0..<5).map { _ in b.next() }
        XCTAssertEqual(seqA, seqB)
    }

    func testDifferentSeedsDiffer() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        XCTAssertNotEqual(a.next(), b.next())
    }

    func testNextUnitIsInZeroToOne() {
        var g = SeededGenerator(seed: 7)
        for _ in 0..<1000 {
            let u = g.nextUnit()
            XCTAssertGreaterThanOrEqual(u, 0.0)
            XCTAssertLessThan(u, 1.0)
        }
    }
}
