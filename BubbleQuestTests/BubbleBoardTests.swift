import XCTest
@testable import BubbleQuest

final class BubbleBoardTests: XCTestCase {
    func testNeighborsAreSymmetricAndValid() {
        for row in 0..<BubbleBoard.rows {
            for column in (row % 2 == 0 ? 0 : -1)..<BubbleBoard.columns {
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
    func testScreenEdgeSlotsRemainVisibleConnectedAndSaveable() throws {
        for column in [-1, 7] {
            let edge = Cell(row: 1, column: column)
            let root = Cell(row: 0, column: column == -1 ? 0 : 7)
            XCTAssertTrue(BubbleBoard.valid(edge))
            let center = BubbleGeometry.point(edge)
            XCTAssertGreaterThanOrEqual(center.x - BubbleGeometry.radius, 0)
            XCTAssertLessThanOrEqual(center.x + BubbleGeometry.radius, BubbleGeometry.sceneWidth)
            let board = BubbleBoard(bubbles: [root: 0, edge: 1])
            let save = GameCheckpoint(level: 0, board: board, shots: 10, score: 0, current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay())
            let restored = try JSONDecoder().decode(GameCheckpoint.self, from: JSONEncoder().encode(save))
            XCTAssertEqual(restored.board?.bubbles, board.bubbles)
        }
        XCTAssertFalse(BubbleBoard.valid(Cell(row: 0, column: -1)))
        XCTAssertFalse(BubbleBoard.valid(Cell(row: 1, column: 8)))
    }

}
