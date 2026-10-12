import XCTest
@testable import BubbleQuest

final class BubbleBoardTests: XCTestCase {
    func testNeighborsAreSymmetricAndValid() {
        for row in 0..<BubbleBoard.rows {
            for column in 0..<(BubbleBoard.columns - row % 2) {
                let cell = Cell(row: row, column: column)
                for neighbor in BubbleBoard.neighbors(of: cell) {
                    XCTAssertTrue(BubbleBoard.valid(neighbor))
                    XCTAssertTrue(BubbleBoard.neighbors(of: neighbor).contains(cell))
                }
            }
        }
    }

    func testMatchingDropsUnanchoredColors() {
        var board = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0,
                                         Cell(row: 0, column: 1): 0,
                                         Cell(row: 1, column: 0): 1,
                                         Cell(row: 2, column: 0): 2])
        let result = board.place(0, at: Cell(row: 0, column: 2))
        XCTAssertEqual(result.matched.count, 3)
        XCTAssertEqual(result.dropped.count, 2)
        XCTAssertTrue(board.bubbles.isEmpty)
    }

    func testPairRemainsAndOccupiedCellCannotBeReplaced() {
        var board = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0])
        XCTAssertTrue(board.place(0, at: Cell(row: 0, column: 1)).matched.isEmpty)
        _ = board.place(2, at: Cell(row: 0, column: 0))
        XCTAssertEqual(board.bubbles[Cell(row: 0, column: 0)], 0)
        XCTAssertEqual(board.bubbles.count, 2)
    }
}
