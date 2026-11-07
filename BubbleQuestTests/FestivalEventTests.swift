import XCTest
import SpriteKit
@testable import BubbleQuest

final class FestivalEventTests: XCTestCase {
    @MainActor
    func testPauseGoalOpensMatchingEventHelpWithoutUsingShotsOrTries() throws {
        for index in [19, 39, 59, 79, 99] {
            try withSavedEvent(index: index) { scene, progress in
                let event = try XCTUnwrap(FestivalEvent.forLevel(index))
                let before = try XCTUnwrap(progress.checkpoint)
                scene.showGameMenu()
                let row = try XCTUnwrap(scene.childNode(withName: "//pause-objective"))
                let resume = try XCTUnwrap(scene.childNode(withName: "//game-resume"))
                XCTAssertFalse(row.calculateAccumulatedFrame().intersects(resume.calculateAccumulatedFrame()))
                let text = try XCTUnwrap(row.childNode(withName: "pause-objective-text") as? SKLabelNode)
                XCTAssertTrue(text.text?.contains(event.mission) == true)
                XCTAssertTrue(scene.interactionNames(at: row.convert(.zero, to: scene)).contains("pause-objective"))
                scene.handleMenu(["pause-objective"])
                XCTAssertEqual((scene.childNode(withName: "//objective-title") as? SKLabelNode)?.text, event.mission)
                let help = try XCTUnwrap(scene.childNode(withName: "//objective-instructions") as? SKLabelNode)
                XCTAssertTrue(help.text?.contains(event.instruction) == true)
                XCTAssertTrue(help.text?.contains("descends over time") == true)
                XCTAssertTrue(help.text?.contains("Menus pause it") == true)
                if event.objective != .clear {
                    XCTAssertTrue(help.text?.contains("4 of 4 " + event.targetNoun(count: 4)) == true)
                }
                XCTAssertEqual(progress.checkpoint?.shots, before.shots)
                XCTAssertEqual(progress.checkpoint?.goal, before.goal)
                XCTAssertEqual(progress.lives(for: index).available, 5)
                scene.handleMenu(["objective-close"])
                XCTAssertNil(scene.childNode(withName: "//objective-instructions"))
                XCTAssertNil(scene.childNode(withName: "//flying-bubble"))
            }
        }
    }

    @MainActor
    func testLegacyFinalePauseKeepsItsSavedClearBoardInstructions() throws {
        try withSavedEvent(index: 79, legacy: true) { scene, progress in
            scene.showGameMenu(); scene.handleMenu(["pause-objective"])
            XCTAssertEqual((scene.childNode(withName: "//objective-title") as? SKLabelNode)?.text, PuzzleObjective.clear.title)
            let help = try XCTUnwrap(scene.childNode(withName: "//objective-instructions") as? SKLabelNode)
            XCTAssertFalse(help.text?.contains("baskets") == true)
            XCTAssertEqual(progress.checkpoint?.balanceVersion, 6)
            XCTAssertEqual(progress.checkpoint?.goal, PuzzleGoal())
        }
    }

    func testAllElevenFinalesHaveValidDistinctEventBoards() throws {
        for index in stride(from: 19, to: LevelCatalog.levelCount, by: 20) {
            let event = try XCTUnwrap(FestivalEvent.forLevel(index))
            let base = LevelCatalog.level(index)
            XCTAssertEqual(base.initialBubbles, event.bubbles)
            XCTAssertEqual(base.goal, event.goal)
            XCTAssertTrue(base.goal.isValid(on: base.board))
            XCTAssertTrue(base.initialArmor.isDisjoint(with: base.goal.remaining))
            XCTAssertTrue(base.initialBlockers.isDisjoint(with: base.goal.remaining))
            for seed in 1...6 {
                let level = base.randomized(seed: UInt64(seed))
                let anchored = level.initialBubbles.keys.filter { $0.row == 0 }.reduce(into: Set<Cell>()) {
                    $0.formUnion(level.board.connected(from: $1, matchingColor: false))
                }
                XCTAssertEqual(anchored, Set(level.initialBubbles.keys))
                XCTAssertEqual(Set(level.initialBubbles.keys), Set(event.bubbles.keys))
                XCTAssertEqual(level.initialSpecials, event.specials)
                let checkpoint = GameCheckpoint(level: index, board: level.board, shots: level.shots, score: 0,
                                                current: 0, next: 1, bag: [], rainbow: 1, bomb: 1,
                                                play: QuestPlay(), layoutSeed: UInt64(seed), goal: level.goal)
                XCTAssertNotNil(checkpoint.board)
            }
        }
        XCTAssertEqual(Set(FestivalEvent.allCases.map { Set($0.bubbles.keys) }).count, 5)
    }

    func testLanternMatchLightsAChainAndDropsItsLowerBranches() {
        let event = FestivalEvent.lanternWalk
        var board = BubbleBoard(bubbles: event.bubbles, specials: event.specials, armor: event.armor)
        let result = board.place(.color(0), at: Cell(row: 3, column: 2))
        XCTAssertGreaterThanOrEqual(result.matched.intersection(Set(event.specials.keys)).count, 2)
        XCTAssertFalse(result.dropped.isEmpty)
    }

    func testFireworksMatchDetonatesAtLeastThreeConnectedSparks() {
        let event = FestivalEvent.fireworks
        var board = BubbleBoard(bubbles: event.bubbles, specials: event.specials, armor: event.armor)
        let result = board.place(.color(1), at: Cell(row: 7, column: 1))
        XCTAssertGreaterThanOrEqual(result.matched.intersection(Set(event.specials.keys)).count, 3)
    }

    func testPicnicSupportMatchDropsABasketBranchAndOneBombCannotWin() {
        let event = FestivalEvent.picnic
        let original = BubbleBoard(bubbles: event.bubbles, armor: event.armor)
        var board = original
        let result = board.place(.color(0), at: Cell(row: 1, column: 2))
        XCTAssertGreaterThanOrEqual(result.dropped.count, 4)
        XCTAssertFalse(result.dropped.isDisjoint(with: event.goal.remaining))
        for cell in (0..<BubbleBoard.rows).flatMap({ row in (-1..<8).map { Cell(row: row, column: $0) } })
            where BubbleBoard.valid(cell) && original.bubbles[cell] == nil {
            var candidate = original
            var goal = event.goal
            let bomb = candidate.place(.bomb, at: cell)
            goal.collect(bomb.matched.union(bomb.dropped))
            XCTAssertFalse(goal.completed(on: candidate), "One bomb should not finish the entire picnic at \(cell)")
        }
    }

    func testParadeLeavesBankRoutesAroundItsWoodenGates() {
        let level = LevelCatalog.level(39)
        XCTAssertFalse(level.initialBlockers.isEmpty)
        let bankRoutes = stride(from: -1.2, through: 1.2, by: 0.05).map { BubbleGeometry.flight(angle: $0, board: level.board) }
            .filter { !$0.bounces.isEmpty && $0.landing != nil }
        XCTAssertFalse(bankRoutes.isEmpty)
        XCTAssertEqual(level.goal.remaining.count, 4)
    }

    func testLegacyAttemptKeepsItsSavedBoardGoalBudgetAndVersion() throws {
        let oldBoard = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0, Cell(row: 0, column: 7): 1])
        let oldGoal = PuzzleGoal(kind: .ceiling, targets: Set(oldBoard.bubbles.keys))
        let saved = GameCheckpoint(level: 59, board: oldBoard, shots: 13, score: 100,
                                   current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay(),
                                   shotsFired: 2, goal: oldGoal, balanceVersion: 6, shotBudget: 21)
        let restored = try JSONDecoder().decode(GameCheckpoint.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(restored.board?.bubbles, oldBoard.bubbles)
        XCTAssertEqual(restored.goal, oldGoal)
        XCTAssertEqual(restored.shotBudget, 21)
        XCTAssertEqual(restored.balanceVersion, 6)
        XCTAssertNotEqual(restored.goal, LevelCatalog.level(59).goal)
    }

    @MainActor
    private func withSavedEvent(index: Int, legacy: Bool = false,
                                check: (FestivalScene, GameProgress) throws -> Void) throws {
        let suite = "EventHelp-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true; progress.practiceDone = true
        progress.recordVictory(index: index - 1, score: 100, stars: 1)
        progress.markCourtyardWelcomed(index / LevelCatalog.levelsPerArea)
        for special in [SpecialBubble.lantern, .riverPearl, .blossomSpark] { progress.markLearned(special) }
        progress.learnObstacle("armor"); progress.learnObstacle("wood")
        let level = LevelCatalog.level(index)
        progress.save(GameCheckpoint(level: index, board: level.board, shots: level.shots, score: 0,
                                     current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay(),
                                     goal: legacy ? PuzzleGoal() : level.goal, balanceVersion: legacy ? 6 : GameLevel.balanceVersion))
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
        try check(scene, progress)
    }
}
