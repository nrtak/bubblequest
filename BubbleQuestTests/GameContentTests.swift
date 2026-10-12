import XCTest
@testable import BubbleQuest

final class GameContentTests: XCTestCase {
    func testAllLevelsHaveLegalAnchoredBoardsAndSafeStartingHeight() {
        XCTAssertEqual(LevelCatalog.levels.count, 50)
        XCTAssertEqual(Set(LevelCatalog.levels.map(\.area)), Set(0..<5))
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
            XCTAssertGreaterThanOrEqual(level.shots, 24)
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
        XCTAssertEqual(progress.unlockedLevel, 49)
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
