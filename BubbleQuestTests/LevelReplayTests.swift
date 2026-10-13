import XCTest
@testable import BubbleQuest

final class LevelReplayTests: XCTestCase {
    struct SeededRandom: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return state
        }
    }

    // Exercise real trajectories, legal colors, free swapping and one of each booster.
    // This is a clearing-route regression check; human difficulty still needs playtesting.
    func testEveryLevelHasAClearingRouteWithTheActualShotQueue() {
        for level in LevelCatalog.levels {
            var random = SeededRandom(state: UInt64(level.number))
            var board = level.board
            var bag: [Int] = []
            func draw() -> Int {
                BubbleColorQueue.draw(board: board, bag: &bag, using: &random)
            }
            var current = draw()
            var next = draw()
            var rainbow = true
            var bomb = true
            for _ in 0..<level.shots {
                if board.bubbles.isEmpty { break }
                var landings = Set<Cell>()
                for angle in stride(from: -1.2, through: 1.2, by: 0.08) {
                    if let cell = BubbleGeometry.flight(angle: angle, board: board).landing { landings.insert(cell) }
                }
                var choices: [BubbleShot] = [.color(current), .color(next)]
                if rainbow { choices.append(.rainbow) }
                if bomb { choices.append(.bomb) }
                var best: (quality: Int, shot: BubbleShot, board: BubbleBoard)?
                let cells = landings.sorted { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }
                for shot in choices {
                    for cell in cells {
                        var candidate = board
                        let cleared = candidate.place(shot, at: cell)
                        let setup = candidate.connected(from: cell, matchingColor: true).count
                        let specialCost = shot == .rainbow || shot == .bomb ? 25 : 0
                        let quality = (cleared.matched.count + cleared.dropped.count) * 100 + setup * 10 - cell.row - specialCost
                        if best == nil || quality > best!.quality { best = (quality, shot, candidate) }
                    }
                }
                guard let selected = best else { break }
                if selected.shot == .color(next) { swap(&current, &next) }
                if selected.shot == .rainbow { rainbow = false }
                if selected.shot == .bomb { bomb = false }
                board = selected.board
                if board.bubbles.keys.contains(where: { BubbleGeometry.point($0).y < BubbleGeometry.lossLine }) { break }
                current = Set(board.bubbles.values).contains(next) ? next : draw()
                next = draw()
            }
            XCTAssertTrue(board.bubbles.isEmpty, "Level \(level.number) needs a better layout or shot budget; \(board.bubbles.count) bubbles remain")
        }
    }
}
