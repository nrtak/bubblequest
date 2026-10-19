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
