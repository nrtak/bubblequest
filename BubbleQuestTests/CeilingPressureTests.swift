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
                XCTAssertTrue(flight.points.allSatisfy { $0.x >= BubbleGeometry.flightLeft && $0.x <= BubbleGeometry.flightRight })
            }
        }
    }

    func testPressureIncreasesAcrossLevelsAndSurvivesSaving() throws {
        let rates = LevelCatalog.levels.map { $0.ceilingStep / Double($0.ceilingInterval) }
        XCTAssertTrue(zip(rates, rates.dropFirst()).allSatisfy { pair in pair.0 < pair.1 })
        let checkpoint = GameCheckpoint(level: 0, board: LevelCatalog.level(0).board, shots: 10, score: 100, current: 0, next: 1,
                                        bag: [0, 1], rainbow: 1, bomb: 1, play: QuestPlay(), ceilingOffset: 12, shotsFired: 36, pressureSeed: 472)
        let reopened = try JSONDecoder().decode(GameCheckpoint.self, from: JSONEncoder().encode(checkpoint))
        XCTAssertEqual(reopened.ceilingOffset, 12)
        XCTAssertEqual(reopened.shotsFired, 36)
        XCTAssertEqual(reopened.pressureSeed, 472)
        let level = LevelCatalog.level(28)
        XCTAssertEqual(level.ceilingOffset(after: 36, seed: 472), level.ceilingOffset(after: 36, seed: reopened.pressureSeed!))
        let schedules = (1...12).map { seed in (1...30).map { level.ceilingOffset(after: $0, seed: UInt64(seed)) } }
        XCTAssertGreaterThan(Set(schedules).count, 1, "Attempts should vary while resumed schedules stay stable")
        XCTAssertNotNil(reopened.board)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint)) as? [String: Any])
        legacy.removeValue(forKey: "ceilingOffset"); legacy.removeValue(forKey: "shotsFired")
        legacy.removeValue(forKey: "pressureSeed")
        let oldSave = try JSONDecoder().decode(GameCheckpoint.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(oldSave.ceilingOffset)
        XCTAssertNotNil(oldSave.board, "Pre-update puzzles must remain resumable")
        let unsafe = GameCheckpoint(level: 0, board: LevelCatalog.level(0).board, shots: 10, score: 100, current: 0, next: 1,
                                    bag: [], rainbow: 1, bomb: 1, play: QuestPlay(), ceilingOffset: .nan)
        XCTAssertNil(unsafe.board)
    }
}
