import XCTest
import SpriteKit
@testable import BubbleQuest

final class PuzzlePolishTests: XCTestCase {
    func testNewPressureIsFasterButSavedAttemptsKeepTheirOriginalClock() throws {
        let level = LevelCatalog.level(26)
        XCTAssertLessThan(level.timedCeilingInterval, level.timedCeilingInterval(balanceVersion: 4))
        for version in [4, GameLevel.balanceVersion] {
            var timer = TimedCeilingPressure()
            for _ in 0..<24 { _ = timer.advance(by: 1, level: level, canDescend: true, balanceVersion: version) }
            XCTAssertEqual(timer.drops, version == 4 ? 0 : 1)
        }
        let old = GameCheckpoint(level: 26, board: level.board, shots: 20, score: 0,
                                 current: 0, next: 1, bag: [], rainbow: 1, bomb: 1,
                                 play: QuestPlay(), shotsFired: 1, balanceVersion: 4,
                                 shotBudget: 23, timedCeilingElapsed: 30)
        let restored = try JSONDecoder().decode(GameCheckpoint.self, from: JSONEncoder().encode(old))
        XCTAssertNotNil(restored.board)
        XCTAssertEqual(restored.shotBudget, 23)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(old)) as? [String: Any])
        json["balanceVersion"] = GameLevel.balanceVersion
        let invalidNewClock = try JSONDecoder().decode(GameCheckpoint.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertNil(invalidNewClock.board)
    }

    func testTimedCeilingWaitsForSafeMovementAndNeverCatchesUpBackgroundTime() {
        let level = LevelCatalog.level(0)
        var timer = TimedCeilingPressure()
        for _ in 0..<44 { XCTAssertFalse(timer.advance(by: 1, level: level, canDescend: true)) }
        XCTAssertFalse(timer.advance(by: 1, level: level, canDescend: false))
        XCTAssertEqual(timer.drops, 0)
        XCTAssertTrue(timer.advance(by: 0, level: level, canDescend: true))
        XCTAssertEqual(timer.drops, 1)
        XCTAssertEqual(timer.elapsed, 0)
        XCTAssertFalse(timer.advance(by: 300, level: level, canDescend: true))
        XCTAssertEqual(timer.elapsed, 0)
        XCTAssertLessThan(LevelCatalog.level(100).timedCeilingInterval, level.timedCeilingInterval)
    }

    func testCorruptTimedPressureAndAlreadyCompletedObjectivesCannotResume() throws {
        let level = LevelCatalog.level(0)
        let save = GameCheckpoint(level: 0, board: level.board, shots: level.shots, score: 0, current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay(), shotsFired: 1)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(save)) as? [String: Any])
        let patches: [[String: Any]] = [["timedCeilingElapsed": 46], ["timedCeilingDrops": 1], ["timedCeilingElapsed": 1, "tryStarted": false, "shotsFired": 0]]
        for patch in patches {
            let damaged = json.merging(patch) { _, new in new }
            let checkpoint = try JSONDecoder().decode(GameCheckpoint.self, from: JSONSerialization.data(withJSONObject: damaged))
            XCTAssertNil(checkpoint.board)
        }
        var finished = PuzzleGoal(kind: .lanterns, targets: [Cell(row: 0, column: 0)])
        finished.collect(finished.remaining)
        let completed = GameCheckpoint(level: 0, board: level.board, shots: 10, score: 100, current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay(), goal: finished)
        XCTAssertNil(completed.board)
    }

    func testTimedPressureSurvivesSavingAndLegacySavesRemainReadable() throws {
        let level = LevelCatalog.level(0)
        let save = GameCheckpoint(level: 0, board: level.board, shots: level.shots, score: 0, current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay(), ceilingOffset: 12, shotsFired: 1, timedCeilingElapsed: 12, timedCeilingDrops: 1)
        let data = try JSONEncoder().encode(save)
        let restored = try JSONDecoder().decode(GameCheckpoint.self, from: data)
        XCTAssertEqual(restored.timedCeilingElapsed, 12)
        XCTAssertEqual(restored.timedCeilingDrops, 1)
        XCTAssertNotNil(restored.board)
        var legacy = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        legacy.removeValue(forKey: "timedCeilingElapsed"); legacy.removeValue(forKey: "timedCeilingDrops")
        let oldSave = try JSONDecoder().decode(GameCheckpoint.self, from: JSONSerialization.data(withJSONObject: legacy))
        XCTAssertNil(oldSave.timedCeilingElapsed)
        XCTAssertNotNil(oldSave.board)
    }

    func testResidentMilestonesRepeatAtFiveTenAndTwentyInEachArea() {
        for index in 0..<LevelCatalog.levelCount {
            let stop = index % LevelCatalog.levelsPerArea + 1
            XCTAssertEqual(LevelCatalog.level(index).residentMilestone, [5, 10, 20].contains(stop) ? stop : nil)
        }
    }

    func testRetryHintsWaitForRepeatedLossesAndDescribeTheActualBoard() {
        let level = LevelCatalog.level(13)
        let plain = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0])
        XCTAssertNil(level.retryHint(board: plain, goal: PuzzleGoal(), consecutiveLosses: 1))
        XCTAssertTrue(level.retryHint(board: plain, goal: PuzzleGoal(), consecutiveLosses: 2)!.contains("Bounce"))
        let rescue = PuzzleGoal(kind: .lanterns, targets: [Cell(row: 0, column: 0)])
        XCTAssertTrue(level.retryHint(board: plain, goal: rescue, consecutiveLosses: 2)!.contains("Only the glowing objects"))
        let help = level.objectiveHelp(board: plain, goal: rescue)
        XCTAssertFalse(help.contains("Silver rings"))
        XCTAssertFalse(help.contains("Wooden blocks"))
        XCTAssertTrue(help.contains("1 of 1"))
        var protected = plain
        protected.armor = [Cell(row: 0, column: 0)]
        XCTAssertTrue(level.objectiveHelp(board: protected, goal: rescue).contains("Silver rings"))
        XCTAssertTrue(level.retryHint(board: protected, goal: rescue, consecutiveLosses: 3)!.contains("two matches"))
    }

    func testOldStatisticsDecodeAndLossStreakPersistsWithoutLosingHistory() throws {
        var legacy = LevelPlayResults()
        legacy.record(won: true, fired: 8, remaining: 12, banks: 1, boosters: 0)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(legacy)) as? [String: Any])
        json.removeValue(forKey: "recentLosses")
        let restored = try JSONDecoder().decode(LevelPlayResults.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(restored.wins, 1)
        XCTAssertEqual(restored.consecutiveLosses, 0)
        let suite = "PolishStats-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(try JSONEncoder().encode(restored), forKey: "levelResults-13")
        let progress = GameProgress(defaults: defaults)
        for _ in 0..<2 { progress.recordOutcome(index: 13, won: false, shotsRemaining: 0) }
        XCTAssertEqual(GameProgress(defaults: defaults).levelResults(13).consecutiveLosses, 2)
        XCTAssertEqual(progress.levelResults(13).wins, 1)
        XCTAssertEqual(progress.levelResults(12).consecutiveLosses, 0)
        progress.recordOutcome(index: 13, won: true, shotsRemaining: 5)
        XCTAssertEqual(progress.levelResults(13).consecutiveLosses, 0)
    }

    func testCourtyardSummaryWeightsRunsRatherThanAveragingPercentages() {
        var first = LevelPlayResults(), second = LevelPlayResults()
        first.record(won: true, fired: 5, remaining: 10, banks: 1, boosters: 0)
        for _ in 0..<3 { second.record(won: false, fired: 20, remaining: 0, banks: 0, boosters: 2) }
        let summary = CourtyardPlaySummary(results: [first, second, LevelPlayResults()])
        XCTAssertEqual(summary.runs, 4)
        XCTAssertEqual(summary.playedLevels, 2)
        XCTAssertEqual(summary.winPercent, 25)
        XCTAssertEqual(summary.averageSaved, 10)
        XCTAssertEqual(summary.boostersPerRun, 1.5)
        XCTAssertEqual(CourtyardPlaySummary(results: []).boostersPerRun, 0)
    }

    func testRandomizationPreservesTheDifficultyEnvelopeAndFinaleOpenings() {
        for base in LevelCatalog.levels {
            for seed in 1...4 {
                let level = base.randomized(seed: UInt64(seed))
                XCTAssertEqual(level.shots, base.shots)
                XCTAssertEqual(Set(level.initialBubbles.values), Set(base.initialBubbles.values))
                XCTAssertEqual(level.initialBubbles.count, base.initialBubbles.count)
                XCTAssertEqual(level.goal.total, base.goal.total)
                XCTAssertTrue(level.goal.isValid(on: level.board))
                for row in Set(base.initialBubbles.keys.map(\.row)) {
                    XCTAssertEqual(level.initialBubbles.keys.filter { $0.row == row }.count,
                                   base.initialBubbles.keys.filter { $0.row == row }.count)
                    let original = Set(base.initialBubbles.keys.filter { $0.row == row })
                    if row >= 3 && original.count < BubbleBoard.columns - row % 2 {
                        XCTAssertEqual(Set(level.initialBubbles.keys.filter { $0.row == row }), original)
                    }
                }
                let anchored = level.initialBubbles.keys.filter { $0.row == 0 }.reduce(into: Set<Cell>()) {
                    $0.formUnion(level.board.connected(from: $1, matchingColor: false))
                }
                XCTAssertEqual(anchored, Set(level.initialBubbles.keys))
                if base.isMilestone || base.isBankRoute {
                    XCTAssertEqual(Set(level.initialBubbles.keys), Set(base.initialBubbles.keys))
                }
                XCTAssertTrue(level.initialArmor.isDisjoint(with: level.goal.remaining))
                XCTAssertTrue(level.initialBlockers.isDisjoint(with: level.goal.remaining))
            }
        }
    }

    func testSoundMixHonorsMuteAndLimitsMalformedVolumes() {
        XCTAssertEqual(FestivalSoundMix.effectVolume(name: "pop", requested: 0), 0)
        XCTAssertEqual(FestivalSoundMix.effectVolume(name: "pop", requested: -1), 0)
        XCTAssertEqual(FestivalSoundMix.effectVolume(name: "pop", requested: .nan), 0)
        XCTAssertLessThanOrEqual(FestivalSoundMix.effectVolume(name: "victory", requested: 10), 1)
        XCTAssertLessThan(FestivalSoundMix.effectVolume(name: "pop", requested: 1),
                          FestivalSoundMix.effectVolume(name: "victory", requested: 1))
    }

    @MainActor
    func testAlbumShowsKeepsakeProgressAndKeepsUnreachedAreaAMystery() throws {
        let suite = "KeepsakePreview-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["album-open"])
        scene.handleMenu(["album-souvenir-10"])
        XCTAssertNotNil(scene.childNode(withName: "//album-keepsake-preview"))
        var words: [String] = []
        scene.enumerateChildNodes(withName: "//*") { node, _ in
            if let text = (node as? SKLabelNode)?.text { words.append(text) }
        }
        XCTAssertTrue(words.contains("Mystery courtyard"))
        XCTAssertTrue(words.contains("0/20 levels cleared"))
        XCTAssertFalse(words.contains("Riverside Fan Fair"))
    }
}
