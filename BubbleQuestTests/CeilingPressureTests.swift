import XCTest
@testable import BubbleQuest

final class CeilingPressureTests: XCTestCase {
    func testDescendingBoardUsesTheSameCoordinatesForCollisionAndLanding() throws {
        let board = LevelCatalog.level(8).board
        for offset in [0.0, 20, 45, 70] {
            for angle in stride(from: -1.2, through: 1.2, by: 0.15) {
                let flight = BubbleGeometry.flight(angle: angle, board: board, ceilingOffset: offset)
                let cell = try XCTUnwrap(flight.landing)
                XCTAssertNil(board.bubbles[cell])
                XCTAssertEqual(flight.points.last, BubbleGeometry.point(cell, ceilingOffset: offset))
                XCTAssertTrue(flight.points.allSatisfy { $0.x >= BubbleGeometry.left && $0.x <= BubbleGeometry.right })
            }
        }
    }

    func testPressureIncreasesAcrossLevelsAndSurvivesSaving() throws {
        let rates = LevelCatalog.levels.map { $0.ceilingStep / Double($0.ceilingInterval) }
        XCTAssertTrue(zip(rates, rates.dropFirst()).allSatisfy { pair in pair.0 < pair.1 })
        let checkpoint = GameCheckpoint(level: 0, board: LevelCatalog.level(0).board, shots: 10, score: 100, current: 0, next: 1,
                                        bag: [0, 1], rainbow: 1, bomb: 1, play: QuestPlay(), ceilingOffset: 12, shotsFired: 36)
        let reopened = try JSONDecoder().decode(GameCheckpoint.self, from: JSONEncoder().encode(checkpoint))
        XCTAssertEqual(reopened.ceilingOffset, 12)
        XCTAssertEqual(reopened.shotsFired, 36)
        XCTAssertNotNil(reopened.board)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint)) as? [String: Any])
        legacy.removeValue(forKey: "ceilingOffset"); legacy.removeValue(forKey: "shotsFired")
        let oldSave = try JSONDecoder().decode(GameCheckpoint.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(oldSave.ceilingOffset)
        XCTAssertNotNil(oldSave.board, "Pre-update puzzles must remain resumable")
        let unsafe = GameCheckpoint(level: 0, board: LevelCatalog.level(0).board, shots: 10, score: 100, current: 0, next: 1,
                                    bag: [], rainbow: 1, bomb: 1, play: QuestPlay(), ceilingOffset: .nan)
        XCTAssertNil(unsafe.board)
    }
}
