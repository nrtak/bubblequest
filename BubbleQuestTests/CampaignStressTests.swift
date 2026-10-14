import XCTest
@testable import BubbleQuest

final class CampaignStressTests: XCTestCase {
    func testAllLevelsAcrossVariedQueuesAndPressureRemainValidAndSaveable() throws {
        for level in LevelCatalog.levels {
            for seed in 1...8 {
                var random = LevelReplayTests.SeededRandom(state: UInt64(seed * 997 + level.number))
                var board = level.board
                var bag: [Int] = []
                var previousOffset = 0.0
                for shotNumber in 0..<min(level.shots, 24) {
                    if board.bubbles.isEmpty { break }
                    let color = BubbleColorQueue.draw(board: board, bag: &bag, using: &random)
                    XCTAssertTrue(board.bubbles.values.contains(color))
                    let offset = level.ceilingOffset(after: shotNumber, seed: UInt64(seed))
                    XCTAssertGreaterThanOrEqual(offset, previousOffset)
                    XCTAssertLessThanOrEqual(offset, 240)
                    previousOffset = offset
                    let angle = Double(Int(random.next() % 25) - 12) / 10
                    let flight = BubbleGeometry.flight(angle: angle, board: board, ceilingOffset: offset)
                    XCTAssertTrue(flight.points.allSatisfy { $0.x.isFinite && $0.y.isFinite })
                    guard let cell = flight.landing else { break }
                    XCTAssertNil(board.bubbles[cell])
                    XCTAssertTrue(BubbleBoard.valid(cell))
                    _ = board.place(.color(color), at: cell)
                    if board.bubbles.isEmpty { break }
                    let nextOffset = level.ceilingOffset(after: shotNumber + 1, seed: UInt64(seed))
                    if board.bubbles.keys.contains(where: { BubbleGeometry.point($0, ceilingOffset: nextOffset).y < BubbleGeometry.lossLine }) { break }
                    let checkpoint = GameCheckpoint(level: level.index, board: board, shots: level.shots,
                                                    score: 0, current: color, next: color, bag: bag,
                                                    rainbow: 1, bomb: 1, play: QuestPlay(),
                                                    ceilingOffset: nextOffset, shotsFired: shotNumber + 1,
                                                    pressureSeed: UInt64(seed))
                    let data = try JSONEncoder().encode(checkpoint)
                    let restored = try JSONDecoder().decode(GameCheckpoint.self, from: data)
                    XCTAssertEqual(restored.board?.bubbles, board.bubbles, "Level \(level.number), seed \(seed), shot \(shotNumber)")
                    XCTAssertEqual(restored.board?.specials, board.specials)
                }
            }
        }
    }
}
