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
            let preview = BubbleGeometry.flight(angle: reflected ? 0.501 : -0.501, board: board)
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


    func testBankShotUsesTheClearDiagonalLaneBetweenStaggeredRows() throws {
        let opening = Set((0..<8).map { Cell(row: 0, column: $0) }).union([
            Cell(row: 1, column: 2), Cell(row: 1, column: 4), Cell(row: 1, column: 6),
            Cell(row: 2, column: 2), Cell(row: 2, column: 4), Cell(row: 3, column: 3),
            Cell(row: 4, column: 3), Cell(row: 5, column: 3), Cell(row: 5, column: 4), Cell(row: 5, column: 5)
        ])
        for mirrored in [false, true] {
            let cells = opening.map { Cell(row: $0.row, column: mirrored ? 7 - $0.row % 2 - $0.column : $0.column) }
            let board = BubbleBoard(bubbles: Dictionary(uniqueKeysWithValues: cells.map { ($0, 0) }))
            let path = BubbleGeometry.flight(angle: mirrored ? 0.65 : -0.65, board: board)
            XCTAssertEqual(path.bounces.count, 1)
            let landing = try XCTUnwrap(path.landing)
            XCTAssertEqual(landing.row, 1, "The visible diagonal lane must reach the upper supports rather than catching row 3")
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

    func testFullSizeClearCorridorsReachUpperSupportsAcrossAnglesAndCeilingPositions() throws {
        func distance(_ p: BubblePoint, to a: BubblePoint, _ b: BubblePoint) -> Double {
            let dx = b.x - a.x, dy = b.y - a.y
            let length = dx * dx + dy * dy
            guard length > 0 else { return BubbleGeometry.distance(p, a) }
            let t = min(1, max(0, ((p.x - a.x) * dx + (p.y - a.y) * dy) / length))
            return hypot(p.x - a.x - t * dx, p.y - a.y - t * dy)
        }
        for offset in [0.0, 40, 80, 120] {
            for angle in [-1.2, -0.8, -0.65, -0.2, 0, 0.2, 0.65, 0.8, 1.2] {
                let path = Array(BubbleGeometry.flight(angle: angle, board: BubbleBoard(), ceilingOffset: offset).points.dropLast())
                var cells = Dictionary(uniqueKeysWithValues: (0..<8).map { (Cell(row: 0, column: $0), 0) })
                for row in 1..<8 {
                    for column in -1..<8 {
                        let cell = Cell(row: row, column: column)
                        let center = BubbleGeometry.point(cell, ceilingOffset: offset)
                        guard BubbleBoard.valid(cell), center.y > BubbleGeometry.lossLine + BubbleGeometry.radius else { continue }
                        let clearance = zip(path, path.dropFirst()).map { distance(center, to: $0.0, $0.1) }.min() ?? 0
                        if clearance > BubbleGeometry.radius * 2 + 0.1 { cells[cell] = column % 3 == 0 ? 1 : 0 }
                    }
                }
                var board = BubbleBoard(bubbles: cells)
                let anchored = (0..<8).reduce(into: Set<Cell>()) { result, column in
                    result.formUnion(board.connected(from: Cell(row: 0, column: column), matchingColor: false))
                }
                board.bubbles = board.bubbles.filter { anchored.contains($0.key) }
                let flight = BubbleGeometry.flight(angle: angle, board: board, ceilingOffset: offset)
                let landing = try XCTUnwrap(flight.landing, "A genuinely open full-size lane must not fail.")
                XCTAssertLessThanOrEqual(landing.row, 1, "Open lane at angle \(angle), ceiling \(offset)")
                XCTAssertNil(board.bubbles[landing])
            }
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

    func testBothDeviceWallsKeepTheWholeBubbleVisibleAndReflectAtTheGuideMarker() throws {
        for angle in stride(from: -1.2, through: 1.2, by: 0.025) {
            let path = BubbleGeometry.flight(angle: angle, board: BubbleBoard())
            let landing = try XCTUnwrap(path.landing)
            XCTAssertTrue(BubbleBoard.valid(landing))
            XCTAssertEqual(landing.row, 0)
            for point in path.points {
                XCTAssertGreaterThanOrEqual(point.x - BubbleGeometry.radius, 1 - 0.00001)
                XCTAssertLessThanOrEqual(point.x + BubbleGeometry.radius, BubbleGeometry.sceneWidth - 1 + 0.00001)
            }
            for bounce in path.bounces {
                XCTAssertTrue(bounce.x == BubbleGeometry.flightLeft || bounce.x == BubbleGeometry.flightRight)
                XCTAssertTrue(path.points.contains { $0.x == bounce.x && $0.y == bounce.y },
                              "The animated path must reach the exact bank marker before reflecting")
            }
        }
        for angle in [-0.8, 0.8] {
            let path = BubbleGeometry.flight(angle: angle, board: BubbleBoard())
            let first = try XCTUnwrap(path.bounces.first)
            XCTAssertEqual(first.x, angle < 0 ? BubbleGeometry.flightLeft : BubbleGeometry.flightRight)
            XCTAssertLessThan(BubbleGeometry.flightLeft, BubbleGeometry.left)
            XCTAssertGreaterThan(BubbleGeometry.flightRight, BubbleGeometry.right)
        }
        // Wider flight space must not move existing boards or saved cells.
        XCTAssertEqual(BubbleGeometry.point(Cell(row: 0, column: 0)).x, 48)
        XCTAssertEqual(BubbleGeometry.point(Cell(row: 0, column: 7)).x, 342)
    }

    func testOuterWallShotAttachesInsteadOfEndingTheLevelAtASealedEdgeCell() throws {
        let cells = [(0,0),(0,1),(0,2),(0,3),(0,4),(0,5),(0,6),(0,7),
                     (1,0),(1,1),(1,2),(1,3),(1,4),(1,6),
                     (2,0),(2,3),(2,6),(2,7),(3,2),(3,3),(3,5),(3,6)]
        for reflected in [false, true] {
            let values = Dictionary(uniqueKeysWithValues: cells.map { row, column in
                (Cell(row: row, column: reflected ? 7 - row % 2 - column : column), 0)
            })
            let board = BubbleBoard(bubbles: values)
            for offset in [0.0, 40, 80] {
                let flight = BubbleGeometry.flight(angle: reflected ? -0.4 : 0.4, board: board, ceilingOffset: offset)
                let landing = try XCTUnwrap(flight.landing, "A reachable exposed edge must not cause an instant loss")
                XCTAssertTrue(BubbleBoard.valid(landing))
                XCTAssertNil(board.bubbles[landing])
                XCTAssertTrue(BubbleBoard.neighbors(of: landing).contains { board.bubbles[$0] != nil })
            }
        }
    }

    func testDescendingScreenshotBoardUsesTheAvailableOuterAttachmentSlot() throws {
        let rows = ["00112200", "0112200", "00....22", ".00..22"]
        var bubbles: [Cell: Int] = [:]
        for (row, text) in rows.enumerated() {
            for (column, character) in text.enumerated() {
                if let color = character.wholeNumberValue { bubbles[Cell(row: row, column: column)] = color }
            }
        }
        let board = BubbleBoard(bubbles: bubbles)
        let flight = BubbleGeometry.flight(angle: 0.45, board: board, ceilingOffset: 45)
        let landing = try XCTUnwrap(flight.landing)
        XCTAssertEqual(landing, Cell(row: 3, column: 7))
        XCTAssertNil(board.bubbles[landing])
    }

}
