import XCTest
@testable import Handbook

/// How a table's columns share its page (1.7.0).
final class TableLayoutTests: XCTestCase {
    func testATableThatFitsKeepsItsColumnsAndTheLastTakesTheRest() {
        XCTAssertEqual(HandbookTableLayout.widths(natural: [60, 200, 140], width: 600), [60, 200, 340])
    }

    /// The Pen's badges: a short first column on one line, the two of sentences sharing the
    /// rest by how much each says, so neither reads a word a line.
    func testShortColumnsStayAndTheLongOnesShareTheRest() {
        let widths = HandbookTableLayout.widths(natural: [60, 600, 900], width: 900)
        XCTAssertEqual(widths[0], 60, "the badges stay on one line")
        XCTAssertEqual(widths[1], 840 * 600 / 1500, accuracy: 0.5)
        XCTAssertEqual(widths[2], 840 * 900 / 1500, accuracy: 0.5)
        XCTAssertEqual(widths.reduce(0, +), 900, accuracy: 0.5, "never past the page")
    }

    func testAWrappingColumnIsNeverNarrowerThanItsLeastUnlessThePageIs() {
        let widths = HandbookTableLayout.widths(natural: [180, 2000, 150], width: 500)
        XCTAssertEqual(widths[0], 180)
        XCTAssertEqual(widths[2], 150)
        XCTAssertEqual(widths[1], 170, accuracy: 0.5)
        XCTAssertGreaterThanOrEqual(widths[1], HandbookTableLayout.leastColumn)
    }

    func testShortColumnsTooWideForThePageShareItAll() {
        let widths = HandbookTableLayout.widths(natural: [150, 150, 150], width: 300)
        XCTAssertEqual(widths.reduce(0, +), 300, accuracy: 0.5)
    }
}
