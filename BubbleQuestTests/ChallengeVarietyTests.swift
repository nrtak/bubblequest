import XCTest
import SpriteKit
@testable import BubbleQuest

final class ChallengeVarietyTests: XCTestCase {
    func testLaterRescueGoalsRequireReachingSeveralUpperSupports() {
        for index in [24, 26, 44, 66, 104, 146, 204] {
            let level = LevelCatalog.level(index).randomized(seed: 382)
            let bottom = level.initialBubbles.keys.map(\.row).max()!
            XCTAssertTrue(level.goal.remaining.allSatisfy { $0.row > 0 && $0.row <= max(1, bottom / 2) })
            let columns = level.goal.remaining.map(\.column)
            XCTAssertGreaterThanOrEqual(columns.max()! - columns.min()!, 4)
            XCTAssertTrue(level.goal.isValid(on: level.board))
        }
        // The reported level previously allowed 23 shots and exposed its charms.
        XCTAssertLessThan(LevelCatalog.level(26).shots, 23)
    }

    func testCombinedStartingChainsStaySmallOnRegularLaterBoards() {
        for index in 20..<LevelCatalog.levelCount where !LevelCatalog.level(index).isMilestone {
            for seed in 1...6 {
                let level = LevelCatalog.level(index).randomized(seed: UInt64(seed))
                let board = BubbleBoard(bubbles: level.initialBubbles)
                var seen = Set<Cell>()
                for cell in board.bubbles.keys where !seen.contains(cell) {
                    let group = board.connected(from: cell, matchingColor: true)
                    seen.formUnion(group)
                    XCTAssertLessThanOrEqual(group.count, level.maximumStartingGroup, "Level \(index + 1), seed \(seed)")
                }
            }
        }
    }

    func testBankShotOpeningsSurviveRandomization() {
        for base in LevelCatalog.levels where base.isBankRoute {
            for seed in 1...6 {
                XCTAssertEqual(Set(base.randomized(seed: UInt64(seed)).initialBubbles.keys), Set(base.initialBubbles.keys))
            }
        }
        XCTAssertLessThan(LevelCatalog.level(4).shots, 24)
    }
    func testRandomizedBoardsRetainIncreasingColorSeparationAndPressure() {
        func averageGroup(_ range: Range<Int>) -> Double {
            var total = 0, groups = 0
            for index in range {
                for seed in 1...4 {
                    let board = LevelCatalog.level(index).randomized(seed: UInt64(seed)).board
                    var seen = Set<Cell>()
                    for cell in board.bubbles.keys where !seen.contains(cell) && !board.blockers.contains(cell) {
                        let group = board.connected(from: cell, matchingColor: true)
                        seen.formUnion(group); total += group.count; groups += 1
                    }
                }
            }
            return Double(total) / Double(groups)
        }
        XCTAssertLessThan(averageGroup(60..<80), averageGroup(0..<10))
        XCTAssertLessThanOrEqual(averageGroup(160..<180), averageGroup(60..<80))
        for index in [19, 59, 99, 159, 199, 219] {
            let level = LevelCatalog.level(index)
            XCTAssertGreaterThan(level.ceilingOffset(after: 12, seed: 42),
                                 level.ceilingOffset(after: 12, seed: 42, balanceVersion: 3))
        }
    }

    func testRescueObjectsAreBuriedAndCanBeReleasedByDroppingTheirSupports() {
        for index in [14, 26, 44, 86, 144, 186] {
            let level = LevelCatalog.level(index).randomized(seed: 382)
            let bottom = level.initialBubbles.keys.map(\.row).max()!
            XCTAssertFalse(level.goal.remaining.isEmpty)
            XCTAssertTrue(level.goal.remaining.allSatisfy { $0.row > 0 && $0.row < bottom })
            XCTAssertTrue(level.goal.isValid(on: level.board))
        }
        let target = Cell(row: 1, column: 0)
        var board = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0, Cell(row: 0, column: 1): 0,
                                          target: 1, Cell(row: 0, column: 7): 2])
        var goal = PuzzleGoal(kind: .lanterns, targets: [target])
        let result = board.place(0, at: Cell(row: 1, column: 1))
        XCTAssertTrue(result.dropped.contains(target))
        goal.collect(result.matched.union(result.dropped))
        XCTAssertTrue(goal.completed(on: board))
        XCTAssertFalse(board.bubbles.isEmpty)
    }

    func testOldPressureScheduleAndNewScheduleSurviveSaving() throws {
        let level = LevelCatalog.level(99)
        for version in [3, LevelPlayResults.balanceVersion] {
            let checkpoint = GameCheckpoint(level: 99, board: level.board, shots: 20, score: 0,
                                            current: 0, next: 1, bag: [], rainbow: 1, bomb: 1,
                                            play: QuestPlay(), balanceVersion: version)
            let restored = try JSONDecoder().decode(GameCheckpoint.self, from: JSONEncoder().encode(checkpoint))
            XCTAssertEqual(restored.balanceVersion, version)
            XCTAssertEqual(level.ceilingOffset(after: 12, seed: 42, balanceVersion: restored.balanceVersion!),
                           level.ceilingOffset(after: 12, seed: 42, balanceVersion: version))
        }
    }

    @MainActor
    func testResumingAnOlderLargerBudgetDoesNotLoseShotsOnAMatch() throws {
        let suite = "RescueBudget-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress(); progress.tutorialSeen = true
        progress.recordVictory(index: 66, score: 100, stars: 1)
        progress.markLearned(.riverPearl)
        let pearl = Cell(row: 0, column: 3)
        let board = BubbleBoard(bubbles: [pearl: 2, Cell(row: 0, column: 4): 2, Cell(row: 0, column: 7): 1], specials: [pearl: .riverPearl])
        progress.save(GameCheckpoint(level: 66, board: board, shots: 40, score: 0, current: 2, next: 1,
                                     bag: [1, 2], rainbow: 1, bomb: 1, play: QuestPlay(), goal: PuzzleGoal(), balanceVersion: 3))
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
        scene.launchShot(angle: 0)
        scene.setActive(false)
        let saved = try XCTUnwrap(profiles.makeProgress().checkpoint)
        XCTAssertEqual(saved.shots, 40, "One shot spent and one pearl shot refunded")
        XCTAssertEqual(saved.shotBudget, 40)
        XCTAssertEqual(saved.balanceVersion, 3)
    }

    @MainActor
    func testMapFocusesNextLevelAndClipsScrollingControls() throws {
        let suite = "ChallengeMap-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true
        for index in 0..<17 { progress.recordVictory(index: index, score: 100, stars: 1) }
        progress.save(GameCheckpoint(level: 4, board: LevelCatalog.level(4).board, shots: 20, score: 0,
                                     current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay()))
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-adventure"])
        let route = try XCTUnwrap(scene.childNode(withName: "//map-route"))
        let next = try XCTUnwrap(scene.childNode(withName: "//level-17"))
        let nextPoint = next.convert(CGPoint.zero, to: scene)
        XCTAssertTrue(FestivalMapLayout.viewport.contains(nextPoint))
        XCTAssertNotNil(next.childNode(withName: "map-tries"))
        XCTAssertNotNil(scene.childNode(withName: "//map-resume"))
        let visible = route.children.filter { $0.name?.hasPrefix("level-") == true && FestivalMapLayout.viewport.contains($0.convert(CGPoint.zero, to: scene)) }
        XCTAssertLessThanOrEqual(visible.count, 7)
        scene.scrollMap(to: -10000)
        XCTAssertEqual(route.position.y, FestivalMapLayout.scrollOffset(-10000))
        let hidden = try XCTUnwrap(scene.childNode(withName: "//level-0"))
        XCTAssertFalse(scene.interactionNames(at: hidden.convert(CGPoint.zero, to: scene)).contains("level-0"))
        scene.scrollMap(to: 10000)
        XCTAssertEqual(route.position.y, FestivalMapLayout.scrollOffset(10000))
    }
}
