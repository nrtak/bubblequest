import XCTest
import UIKit
import SpriteKit
@testable import BubbleQuest

final class GameContentTests: XCTestCase {
    @MainActor
    func testAllTwentyMapPagesOpenAndShowTheirLevels() {
        let scene = FestivalScene(size: CGSize(width: 390, height: 844))
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.handleMenu(["start-adventure"])
        for _ in 0..<20 { scene.handleMenu(["area-prev"]) }
        for area in 0..<20 {
            let overlay = scene.children.last!
            let headings = overlay.children.compactMap { ($0 as? SKLabelNode)?.text }
            XCTAssertTrue(headings.contains { $0.hasPrefix("Area \(area + 1)/20") })
            let markers = overlay.children.flatMap { $0.children.compactMap { ($0 as? SKLabelNode)?.text } }
            XCTAssertTrue(markers.contains("\(area * 10 + 1)"))
            XCTAssertTrue(markers.contains("\(area * 10 + 10)"))
            scene.handleMenu(["area-next"])
        }
    }

    func testAdditionalLevelsUseDistinctStartingBoards() {
        func signature(_ level: GameLevel) -> String {
            level.initialBubbles.map { "\($0.key.row):\($0.key.column):\($0.value)" }.sorted().joined(separator: ",")
        }
        let original = Set(LevelCatalog.levels.prefix(50).map(signature))
        let added = Set(LevelCatalog.levels.dropFirst(50).map(signature))
        XCTAssertEqual(added.count, 150)
        XCTAssertTrue(original.isDisjoint(with: added))
    }

    func testExpandedCampaignMigratesOldFinaleAndPersistsLateProgress() throws {
        XCTAssertEqual(LevelCatalog.areas.count, 20)
        XCTAssertEqual(LevelCatalog.levels.last?.number, 200)
        XCTAssertEqual(LevelCatalog.maximumStars, 600)
        let suite = "BubbleQuestCampaign-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(49, forKey: "unlockedLevel")
        defaults.set(3, forKey: "stars-49")
        defaults.set(750, forKey: "bestScore-49")
        let progress = GameProgress(defaults: defaults)
        XCTAssertEqual(progress.unlockedLevel, 50)
        XCTAssertEqual(progress.stars(49), 3)
        XCTAssertEqual(progress.bestScore(49), 750)
        progress.recordVictory(index: 198, score: 500, stars: 2)
        progress.recordChallenge(19)
        let last = LevelCatalog.level(199)
        progress.save(GameCheckpoint(level: 199, board: last.board, shots: last.shots,
                                     score: 0, current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay()))
        let reopened = GameProgress(defaults: defaults)
        XCTAssertEqual(reopened.unlockedLevel, 199)
        XCTAssertEqual(reopened.currentLevel, 199)
        XCTAssertNotNil(reopened.checkpoint?.board)
        XCTAssertTrue(reopened.challengeWon(19))
        XCTAssertEqual(LevelCatalog.level(999).index, 199)
    }

    func testBuddyPickerConsumesTouchesAboveUnderlyingMapActivities() {
        XCTAssertEqual(FestivalMenuTargets.buddies(["friend-shiba", "open-wheel", "continue-stop", "meet-host"]), ["friend-shiba"])
        XCTAssertEqual(FestivalMenuTargets.buddies(["friends-page", "continue-stop"]), ["friends-page"])
        XCTAssertEqual(FestivalMenuTargets.buddies(["accessories", "level-0"]), ["accessories"])
        XCTAssertTrue(FestivalMenuTargets.buddies(["level-0"]).isEmpty)
    }

    func testLaterLevelsHaveTighterShotAllowanceAndFasterPressure() {
        let early = LevelCatalog.level(4)
        let late = LevelCatalog.level(49)
        XCTAssertLessThan(late.ceilingInterval, early.ceilingInterval)
        XCTAssertGreaterThan(late.ceilingStep, early.ceilingStep)
        let firstArea = LevelCatalog.levels.prefix(10).map { Double($0.shots) / Double($0.initialBubbles.count) }.reduce(0, +) / 10
        let finalArea = LevelCatalog.levels.suffix(10).map { Double($0.shots) / Double($0.initialBubbles.count) }.reduce(0, +) / 10
        XCTAssertLessThan(finalArea, firstArea * 0.8)
    }

    func testChallengeContinuesBeyondTheFirstFiftyLevels() {
        func averageAllowance(_ range: Range<Int>) -> Double {
            range.map { Double(LevelCatalog.level($0).shots) / Double(LevelCatalog.level($0).initialBubbles.count) }
                .reduce(0, +) / Double(range.count)
        }
        func averageGroupSize(_ range: Range<Int>) -> Double {
            var sizes: [Int] = []
            for index in range {
                let board = LevelCatalog.level(index).board
                var visited = Set<Cell>()
                for cell in board.bubbles.keys where !visited.contains(cell) {
                    let group = board.connected(from: cell, matchingColor: true)
                    visited.formUnion(group)
                    sizes.append(group.count)
                }
            }
            return Double(sizes.reduce(0, +)) / Double(sizes.count)
        }
        // Prevent a return to recolored copies with the same late-game allowances.
        XCTAssertLessThan(averageAllowance(50..<100), averageAllowance(10..<30))
        XCTAssertLessThan(averageAllowance(150..<200), averageAllowance(50..<100))
        XCTAssertLessThan(averageGroupSize(50..<100), averageGroupSize(0..<10))
        XCTAssertTrue(LevelCatalog.levels[50..<100].allSatisfy { Set($0.initialBubbles.values).count == 5 })
        XCTAssertTrue(LevelCatalog.levels[150..<200].filter { !$0.isPrecision }.allSatisfy { $0.initialBubbles.keys.map(\.row).max() == 6 })
        // The same depth can have different routes, not just a new color permutation.
        let shapes = Set(LevelCatalog.levels[50..<100].map { Set($0.initialBubbles.keys) })
        XCTAssertGreaterThan(shapes.count, 5)
        XCTAssertGreaterThan(LevelCatalog.level(199).ceilingOffset(after: 20, seed: 42),
                             LevelCatalog.level(59).ceilingOffset(after: 20, seed: 42))
    }

    func testAreaMechanicsBuildFromSingleTypesToCombinations() {
        XCTAssertTrue(LevelCatalog.level(8).initialSpecials.isEmpty)
        XCTAssertEqual(Set(LevelCatalog.level(22).initialSpecials.values), [.lantern])
        XCTAssertTrue(Set(LevelCatalog.level(36).initialSpecials.values).isSuperset(of: [.lantern, .riverPearl]))
        XCTAssertEqual(Set(LevelCatalog.level(48).initialSpecials.values), [.lantern, .riverPearl, .blossomSpark])
    }

    func testEveryRuntimeImageAndAudioCueIsBundled() {
        let images = Set(LevelCatalog.levels.map(\.background)).union([
            "festival-title-cast", "festival-hosts", "festival-companion-atlas",
            "festival-companion-motion", "festival-companion-glance", "festival-new-human-motion", "festival-special-bubbles",
            "festival-neighbors", "festival-neighbors-extra", "festival-operator-rig",
            "festival-logo", "festival-bubbles", "festival-map", "festival-map-day",
            "festival-summer-map-atlas", "festival-hill-map", "festival-summer-neighbors", "festival-summer-buddy-motion"
        ])
        for name in images { XCTAssertNotNil(UIImage(named: name), "Missing image \(name)") }
        for name in ["pop", "launch", "load", "bomb", "victory", "music-day", "music-evening", "armor-crack", "rescue", "big-drop", "milestone", "stick"] {
            XCTAssertNotNil(Bundle.main.url(forResource: name, withExtension: "wav"), "Missing audio \(name)")
        }
    }

    func testAllLevelsHaveLegalAnchoredBoardsAndSafeStartingHeight() {
        XCTAssertEqual(LevelCatalog.levels.count, 200)
        XCTAssertEqual(Set(LevelCatalog.levels.map(\.area)), Set(LevelCatalog.areas.indices))
        for level in LevelCatalog.levels {
            let board = level.board
            XCTAssertFalse(board.bubbles.isEmpty, "Level \(level.number)")
            var anchored = Set<Cell>()
            for cell in board.bubbles.keys where cell.row == 0 {
                anchored.formUnion(board.connected(from: cell, matchingColor: false))
            }
            XCTAssertEqual(anchored, Set(board.bubbles.keys), "Level \(level.number)")
            for (cell, color) in board.bubbles {
                XCTAssertTrue(BubbleBoard.valid(cell))
                XCTAssertTrue((0..<5).contains(color))
                XCTAssertGreaterThan(BubbleGeometry.point(cell).y, BubbleGeometry.lossLine)
            }
            XCTAssertGreaterThanOrEqual(level.shots, level.isPrecision ? 12 : 18)
        }
    }

    func testAimPathReflectsInsideWallsAndLandsInFreeCell() {
        for level in LevelCatalog.levels {
            for angle in stride(from: -1.2, through: 1.2, by: 0.15) {
                let flight = BubbleGeometry.flight(angle: angle, board: level.board)
                XCTAssertTrue(flight.points.allSatisfy { $0.x >= BubbleGeometry.left && $0.x <= BubbleGeometry.right })
                guard let cell = flight.landing else { XCTFail("No landing in level \(level.number)"); continue }
                XCTAssertTrue(BubbleBoard.valid(cell))
                XCTAssertNil(level.initialBubbles[cell])
                XCTAssertEqual(flight.points.last, BubbleGeometry.point(cell))
            }
        }
    }

    func testRainbowChoosesLargestAdjacentColorGroup() {
        var board = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0,
                                         Cell(row: 0, column: 1): 1,
                                         Cell(row: 0, column: 2): 1])
        let result = board.place(.rainbow, at: Cell(row: 1, column: 0))
        XCTAssertEqual(result.matched.count, 3)
        XCTAssertEqual(board.bubbles, [Cell(row: 0, column: 0): 0])
    }

    func testBombClearsNearbyBubblesAndDropsDisconnectedTail() {
        var board = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0,
                                         Cell(row: 1, column: 0): 1,
                                         Cell(row: 2, column: 0): 2,
                                         Cell(row: 3, column: 0): 3,
                                         Cell(row: 4, column: 0): 4])
        let result = board.place(.bomb, at: Cell(row: 0, column: 1))
        XCTAssertFalse(result.matched.isEmpty)
        XCTAssertFalse(result.dropped.isEmpty)
        XCTAssertTrue(board.bubbles.isEmpty)
    }

    func testProgressKeepsBestResultsAndUnlocksFriendsAndHosts() {
        let suite = "BubbleQuestTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = GameProgress(defaults: defaults)
        XCTAssertEqual(progress.unlockedLevel, 0)
        XCTAssertFalse(progress.hostIsAvailable(FestivalHost.all[1]))
        for index in 0..<10 { progress.recordVictory(index: index, score: 200, stars: 3) }
        progress.recordVictory(index: 0, score: 100, stars: 1)
        XCTAssertEqual(progress.totalStars, 30)
        XCTAssertEqual(progress.bestScore(0), 200)
        XCTAssertEqual(progress.unlockedLevel, 10)
        XCTAssertTrue(progress.unlocked(Companion.all[1]))
        XCTAssertTrue(progress.hostIsAvailable(FestivalHost.all[1]))
        progress.markMet(FestivalHost.all[1])
        XCTAssertTrue(GameProgress(defaults: defaults).hasMet(FestivalHost.all[1]))
        progress.select(Companion.all[1])
        XCTAssertEqual(progress.selected(.animal).id, "white-shiba")
        progress.select(Companion.all[3])
        XCTAssertEqual(progress.selected(.animal).id, "white-shiba")
        progress.recordVictory(index: 49, score: 100, stars: 2)
        XCTAssertEqual(progress.unlockedLevel, 50)
    }

    func testSettingsMigrationAndPersistence() {
        let suite = "BubbleQuestSettings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(true, forKey: "muted")
        let progress = GameProgress(defaults: defaults)
        XCTAssertFalse(progress.enabled(.music))
        XCTAssertFalse(progress.enabled(.effects))
        XCTAssertTrue(progress.enabled(.guide))
        progress.toggle(.music)
        XCTAssertTrue(GameProgress(defaults: defaults).enabled(.music))
    }

    func testStarThresholdsAndInvalidShots() {
        let level = LevelCatalog.level(0)
        XCTAssertEqual(level.stars(shotsRemaining: level.shots), 3)
        XCTAssertEqual(level.stars(shotsRemaining: level.shots / 4), 2)
        XCTAssertEqual(level.stars(shotsRemaining: 0), 1)
        var board = level.board
        let original = board.bubbles
        _ = board.place(.color(7), at: Cell(row: 9, column: 0))
        _ = board.place(.bomb, at: Cell(row: -1, column: 0))
        XCTAssertEqual(board.bubbles, original)
    }
}
