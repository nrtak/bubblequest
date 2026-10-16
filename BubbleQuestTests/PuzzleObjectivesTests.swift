import XCTest
@testable import BubbleQuest

final class PuzzleObjectivesTests: XCTestCase {
    func testMarkedTargetsCanWinWithoutClearingOtherBubblesAndCannotBeRecollected() throws {
        let target = Cell(row: 0, column: 0)
        var goal = PuzzleGoal(kind: .lanterns, targets: [target])
        var board = BubbleBoard(bubbles: [target: 0, Cell(row: 0, column: 7): 1])
        XCTAssertFalse(goal.completed(on: board))
        board.bubbles.removeValue(forKey: target)
        goal.collect([target])
        XCTAssertTrue(goal.completed(on: board))
        board.bubbles[target] = 2
        XCTAssertTrue(goal.completed(on: board), "A new bubble in the old cell cannot bring a rescued item back")
        goal.collect([target])
        XCTAssertEqual(goal.progressText, "Rescue the lanterns 1/1")
        XCTAssertEqual(try JSONDecoder().decode(PuzzleGoal.self, from: JSONEncoder().encode(goal)), goal)
        XCTAssertFalse(PuzzleGoal().completed(on: board))
    }

    func testArmorAbsorbsOneMatchAndChainedLanternCannotHitItTwice() {
        let armored = Cell(row: 0, column: 0), lantern = Cell(row: 0, column: 1)
        var board = BubbleBoard(bubbles: [armored: 0, lantern: 0], specials: [lantern: .lantern], armor: [armored])
        let first = board.place(0, at: Cell(row: 1, column: 0))
        XCTAssertNotNil(board.bubbles[armored])
        XCTAssertFalse(first.matched.contains(armored))
        XCTAssertTrue(board.armor.isEmpty)
        _ = board.place(0, at: lantern)
        _ = board.place(0, at: Cell(row: 1, column: 0))
        XCTAssertTrue(board.bubbles.isEmpty)
    }

    func testWoodenBlockersCannotMatchButFallWithTheirSupports() {
        let block = Cell(row: 1, column: 0)
        var board = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0, Cell(row: 0, column: 1): 0, block: 0], blockers: [block])
        XCTAssertTrue(board.connected(from: block, matchingColor: true).isEmpty)
        let result = board.place(0, at: Cell(row: 1, column: 1))
        XCTAssertTrue(result.dropped.contains(block))
        XCTAssertTrue(board.bubbles.isEmpty)
        XCTAssertTrue(board.blockers.isEmpty)
    }

    func testObjectivesAndObstaclesSurviveCheckpointsAndOldSavesStillLoad() throws {
        let level = LevelCatalog.level(49)
        let saved = GameCheckpoint(level: level.index, board: level.board, shots: level.shots, score: 0,
                                   current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay(),
                                   goal: level.goal, bankMatches: 2, boosterShots: 1)
        let data = try JSONEncoder().encode(saved)
        let restored = try JSONDecoder().decode(GameCheckpoint.self, from: data)
        XCTAssertEqual(restored.goal, level.goal)
        XCTAssertEqual(restored.board?.armor, level.initialArmor)
        XCTAssertEqual(restored.board?.blockers, level.initialBlockers)
        XCTAssertEqual(restored.bankMatches, 2)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for key in ["armor", "blockers", "goal", "bankMatches", "boosterShots"] { legacy.removeValue(forKey: key) }
        let old = try JSONDecoder().decode(GameCheckpoint.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNotNil(old.board)
        XCTAssertNil(old.goal)
    }

    func testAllObjectivesAreReachableCellsAndObstaclesDoNotCoverTargetsOrSpecials() {
        XCTAssertEqual(LevelCatalog.levels.filter(\.isMilestone).count, 10)
        XCTAssertTrue(LevelCatalog.levels.prefix(20).allSatisfy { $0.initialArmor.isEmpty && $0.initialBlockers.isEmpty })
        for level in LevelCatalog.levels {
            XCTAssertTrue(level.goal.isValid(on: level.board), "Level \(level.number)")
            XCTAssertTrue(level.initialArmor.isDisjoint(with: level.initialBlockers))
            XCTAssertTrue(level.initialArmor.union(level.initialBlockers).isDisjoint(with: level.goal.remaining))
            XCTAssertTrue(level.initialArmor.union(level.initialBlockers).isDisjoint(with: Set(level.initialSpecials.keys)))
            XCTAssertFalse(level.initialBlockers.contains { $0.row == 0 })
        }
    }

    func testQueueDoesNotOfferColorsHiddenOnlyUnderWoodenBlocks() {
        let block = Cell(row: 1, column: 0)
        let board = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0, block: 4], blockers: [block])
        var bag = [4]
        var random = LevelReplayTests.SeededRandom(state: 42)
        XCTAssertEqual(BubbleColorQueue.draw(board: board, bag: &bag, using: &random), 0)
        XCTAssertFalse(bag.contains(4))
    }

    func testBankRewardsRequireARealClearAndDoNotMultiplyWithRepeatedBounces() {
        XCTAssertEqual(PuzzleRewards.bankBonus(bounces: 0, removed: 12), 0)
        XCTAssertEqual(PuzzleRewards.bankBonus(bounces: 3, removed: 0), 0)
        XCTAssertEqual(PuzzleRewards.bankBonus(bounces: 1, removed: 3), 50)
        XCTAssertEqual(PuzzleRewards.bankBonus(bounces: 4, removed: 3), 50)
    }

    func testResultsAccumulatePerPlayerWithoutOverwritingEarlierRuns() {
        let suite = "PuzzleResults-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite); defaults.removePersistentDomain(forName: suite + ".other") }
        let progress = GameProgress(defaults: defaults)
        progress.recordAttempt(60)
        progress.recordOutcome(index: 60, won: true, shotsRemaining: 7, shotsFired: 19, bankMatches: 2, boosterShots: 1)
        progress.recordOutcome(index: 60, won: false, shotsRemaining: 0, shotsFired: 26)
        let reloaded = GameProgress(defaults: defaults).levelResults(60)
        XCTAssertEqual(reloaded.wins, 1)
        XCTAssertEqual(reloaded.losses, 1)
        XCTAssertEqual(reloaded.winRate, 50)
        XCTAssertEqual(reloaded.averageSaved, 7)
        XCTAssertEqual(reloaded.shotsUsed, 45)
        XCTAssertEqual(reloaded.bankMatches, 2)
        XCTAssertEqual(reloaded.boosterShots, 1)
        XCTAssertEqual(GameProgress(defaults: UserDefaults(suiteName: suite + ".other")!).levelResults(60).completedRuns, 0)
    }
}
