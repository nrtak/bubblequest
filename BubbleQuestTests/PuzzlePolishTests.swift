import XCTest
import SpriteKit
@testable import BubbleQuest

final class PuzzlePolishTests: XCTestCase {
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
