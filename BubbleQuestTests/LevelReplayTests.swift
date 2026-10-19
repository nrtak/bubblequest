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
    // Harder boards may require saving a booster for a blocked support. Retry the
    // same queue and pressure schedule with different booster timing, not more shots.
    func testEveryLevelHasACompletionRouteWithTheActualShotQueue() {
        for base in LevelCatalog.levels {
            let level = base.randomized(seed: UInt64(base.number) * 991)
            for pressureSeed in [UInt64(0), UInt64(level.number)] {
                let cleared = [(25, 2000), (600, 300), (1000, 0)].contains { strategy in
                    hasClearingRoute(level: level, pressureSeed: pressureSeed, specialPenalty: strategy.0, targetPriority: strategy.1)
                }
                XCTAssertTrue(cleared, "Level \(level.number) needs a better layout or shot budget")
            }
        }
    }

    func testDifficultyMilestonesHaveRoutesAcrossDifferentLayouts() {
        for index in [0] + Array(stride(from: LevelCatalog.levelsPerArea - 1, to: LevelCatalog.levelCount, by: LevelCatalog.levelsPerArea)) {
            for seed in 1...4 {
                let level = LevelCatalog.level(index).randomized(seed: UInt64(seed))
                let cleared = [(25, 2000), (600, 300), (1000, 0)].contains { strategy in
                    hasClearingRoute(level: level, pressureSeed: UInt64(seed), specialPenalty: strategy.0, targetPriority: strategy.1)
                }
                XCTAssertTrue(cleared, "Level \(index + 1), layout seed \(seed) needs balance adjustment")
            }
        }
    }

    private func hasClearingRoute(level: GameLevel, pressureSeed: UInt64, specialPenalty: Int, targetPriority: Int) -> Bool {
        var random = SeededRandom(state: UInt64(level.number))
        var board = level.board
        var goal = level.goal
        var bag: [Int] = []
        func draw() -> Int {
            BubbleColorQueue.draw(board: board, bag: &bag, using: &random)
        }
        var current = draw()
        var next = draw()
        var rainbow = true
        var bomb = true
        for shotNumber in 0..<level.shots {
            if goal.completed(on: board) { return true }
            var landings = Set<Cell>()
            for angle in stride(from: -1.2, through: 1.2, by: 0.04) {
                if let cell = BubbleGeometry.flight(angle: angle, board: board, ceilingOffset: level.ceilingOffset(after: shotNumber, seed: pressureSeed)).landing { landings.insert(cell) }
            }
            var choices: [BubbleShot] = [.color(current), .color(next)]
            if rainbow { choices.append(.rainbow) }
            if bomb { choices.append(.bomb) }
            var best: (quality: Int, shot: BubbleShot, board: BubbleBoard, removed: Set<Cell>)?
            let cells = landings.sorted { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }
            for shot in choices {
                for cell in cells {
                    var candidate = board
                    let cleared = candidate.place(shot, at: cell)
                    let setup = candidate.connected(from: cell, matchingColor: true).count
                    let specialCost = shot == .rainbow || shot == .bomb ? specialPenalty : 0
                    let removed = cleared.matched.union(cleared.dropped)
                    let objectiveValue = goal.remaining.intersection(removed).count * targetPriority
                    let cracks = board.armor.subtracting(candidate.armor).count * 80
                    let quality = objectiveValue + (cleared.matched.count + cleared.dropped.count) * 100 + cracks + setup * 10 - cell.row - specialCost
                    if best == nil || quality > best!.quality { best = (quality, shot, candidate, removed) }
                }
            }
            guard let selected = best else { break }
            if selected.shot == .color(next) { swap(&current, &next) }
            if selected.shot == .rainbow { rainbow = false }
            if selected.shot == .bomb { bomb = false }
            board = selected.board
            goal.collect(selected.removed)
            if goal.completed(on: board) { return true }
            if board.bubbles.keys.contains(where: { BubbleGeometry.point($0, ceilingOffset: level.ceilingOffset(after: shotNumber + 1, seed: pressureSeed)).y < BubbleGeometry.lossLine }) { break }
            current = board.playableColors.contains(next) ? next : draw()
            next = draw()
        }
        return goal.completed(on: board)
    }
}
