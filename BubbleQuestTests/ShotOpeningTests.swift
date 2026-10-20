import XCTest
@testable import BubbleQuest

final class ShotOpeningTests: XCTestCase {
    private var opening: [Cell: Int] {
        [Cell(row: 0, column: 0): 2, Cell(row: 0, column: 1): 2, Cell(row: 0, column: 2): 2,
         Cell(row: 0, column: 3): 0, Cell(row: 0, column: 4): 0,
         Cell(row: 1, column: 0): 1, Cell(row: 1, column: 2): 2,
         Cell(row: 2, column: 3): 0,
         Cell(row: 3, column: 1): 1, Cell(row: 3, column: 2): 1,
         Cell(row: 4, column: 2): 0, Cell(row: 4, column: 3): 2,
         Cell(row: 4, column: 4): 2, Cell(row: 4, column: 5): 0]
    }

    func testBankShotThreadsTheScreenshotOpeningAndMatchesTheUpperBlueGroup() throws {
        for reflected in [false, true] {
            func cell(_ cell: Cell) -> Cell {
                Cell(row: cell.row, column: reflected ? BubbleBoard.columns - cell.row % 2 - 1 - cell.column : cell.column)
            }
            var board = BubbleBoard(bubbles: Dictionary(uniqueKeysWithValues: opening.map { (cell($0.key), $0.value) }))
            let preview = BubbleGeometry.flight(angle: reflected ? 0.406 : -0.406, board: board)
            XCTAssertEqual(preview.bounces.count, 1)
            let landing = try XCTUnwrap(preview.landing)
            XCTAssertNil(board.bubbles[landing])
            let cleared = board.place(.color(2), at: landing)
            XCTAssertTrue(cleared.matched.contains(cell(Cell(row: 1, column: 2))))
            XCTAssertTrue(cleared.matched.contains(cell(Cell(row: 0, column: 2))))
            XCTAssertFalse(cleared.matched.contains(cell(Cell(row: 3, column: 1))))
        }
    }


    func testStraightShotPassesTheWideGapInIMG3664() throws {
        let cells = [
            [0,0], [0,1], [0,2], [0,3], [0,4], [0,5], [0,6], [0,7],
            [1,0], [1,1], [1,2], [1,3], [1,4], [1,5], [1,6],
            [2,0], [2,1], [2,6], [2,7], [3,0], [3,1], [3,5], [3,6],
            [4,1], [4,2], [4,3], [4,5], [4,6], [5,2], [5,4]
        ].map { Cell(row: $0[0], column: $0[1]) }
        let board = BubbleBoard(bubbles: Dictionary(uniqueKeysWithValues: cells.map { ($0, 0) }))
        for offset in [0.0, 40, 80] {
            let gap = BubbleGeometry.point(Cell(row: 4, column: 4), ceilingOffset: offset)
            let angle = offset == 0 ? 0.012 : atan2(6, gap.y - BubbleGeometry.origin.y)
            let path = BubbleGeometry.flight(angle: angle, board: board, ceilingOffset: offset)
            let landing = try XCTUnwrap(path.landing)
            XCTAssertLessThanOrEqual(landing.row, 2, "The shot should reach the upper gap, not stop at the lower blue bubbles")
            XCTAssertNil(board.bubbles[landing])
        }
    }


    func testIsolatedBubbleKeepsItsNormalContactDistance() throws {
        let cell = Cell(row: 0, column: 4)
        let board = BubbleBoard(bubbles: [cell: 0])
        let center = BubbleGeometry.point(cell)
        let angle = atan2(center.x - BubbleGeometry.origin.x, center.y - BubbleGeometry.origin.y)
        let path = BubbleGeometry.flight(angle: angle, board: board)
        XCTAssertNotNil(path.landing)
        let contact = try XCTUnwrap(path.points.dropLast().last)
        XCTAssertGreaterThan(BubbleGeometry.distance(contact, center), 29)
        XCTAssertLessThanOrEqual(BubbleGeometry.distance(contact, center), BubbleGeometry.collisionDistance)
    }

    func testForgivingEdgesStillBlockAnUnbrokenRowAtDifferentCeilingHeights() throws {
        let row = Dictionary(uniqueKeysWithValues: (0..<8).map { (Cell(row: 0, column: $0), $0 % 3) })
        let board = BubbleBoard(bubbles: row)
        for offset in [0.0, 80, 160] {
            for angle in stride(from: -1.2, through: 1.2, by: 0.05) {
                let flight = BubbleGeometry.flight(angle: angle, board: board, ceilingOffset: offset)
                let landing = try XCTUnwrap(flight.landing)
                XCTAssertEqual(landing.row, 1)
                XCTAssertNil(board.bubbles[landing])
                XCTAssertTrue(flight.points.dropLast().allSatisfy { $0.y < BubbleGeometry.ceiling - offset })
            }
        }
    }
}
