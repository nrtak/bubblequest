import XCTest
import SpriteKit
@testable import BubbleQuest

final class FestivalActivitiesTests: XCTestCase {
    private func withProgress(_ body: (GameProgress, UserDefaults) throws -> Void) rethrows {
        let suite = "FestivalActivities-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        try body(GameProgress(defaults: defaults), defaults)
    }

    func testDailySelectionIsStableAcrossProgressChangesAndRelaunches() {
        withProgress { progress, defaults in
            let now = Date(timeIntervalSince1970: 1_794_000_000)
            let puzzle = progress.activities.daily(now: now, unlocked: 26)
            XCTAssertTrue((7...26).contains(puzzle.level))
            XCTAssertEqual(progress.activities.daily(now: now, unlocked: 80), puzzle)
            let restored = GameProgress(defaults: defaults)
            XCTAssertEqual(restored.activities.daily(now: now, unlocked: 100), puzzle)
            XCTAssertEqual(restored.activities.daily(now: now, unlocked: 100).definition.initialBubbles, puzzle.definition.initialBubbles)
            let tomorrow = restored.activities.daily(now: now.addingTimeInterval(86400), unlocked: 80)
            XCTAssertNotEqual(tomorrow.day, puzzle.day)
            XCTAssertNotEqual(tomorrow.seed, puzzle.seed)
            XCTAssertNil(restored.activities.checkpoint(for: puzzle))
        }
    }

    func testDailyRewardIsIdempotentAndCannotAdvanceCampaignOrSideQuests() {
        withProgress { progress, defaults in
            let puzzle = progress.activities.daily(unlocked: 0)
            XCTAssertTrue(progress.activities.complete(puzzle, adventure: progress.adventure))
            XCTAssertFalse(progress.activities.complete(puzzle, adventure: progress.adventure))
            progress.adventure.awardDailyRainbow(day: puzzle.day)
            let restored = GameProgress(defaults: defaults)
            XCTAssertEqual(restored.adventure.rainbowGifts, 1)
            XCTAssertEqual(restored.unlockedLevel, 0)
            XCTAssertEqual(restored.completedCount, 0)
            XCTAssertEqual(restored.adventure.availableSpins, 0)
            XCTAssertTrue(restored.activities.completed(puzzle))
        }
    }

    func testDailyCheckpointsDoNotReplaceCampaignAndExpireOnDayChange() {
        withProgress { progress, defaults in
            let base = LevelCatalog.level(0)
            let campaign = GameCheckpoint(level: 0, board: base.board, shots: base.shots, score: 50, current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay())
            progress.save(campaign)
            let now = Date(timeIntervalSince1970: 1_794_000_000)
            let daily = progress.activities.daily(now: now, unlocked: 0)
            let checkpoint = GameCheckpoint(level: daily.level, board: daily.definition.board, shots: 12, score: 0, current: 0, next: 1, bag: [], rainbow: 0, bomb: 0, play: QuestPlay(), challenge: true, layoutSeed: daily.seed, goal: daily.definition.goal, shotBudget: 12)
            progress.activities.save(checkpoint, for: daily)
            let restored = GameProgress(defaults: defaults)
            XCTAssertNotNil(restored.activities.checkpoint(for: daily))
            XCTAssertEqual(restored.checkpoint?.score, 50)
            let tomorrow = restored.activities.daily(now: now.addingTimeInterval(86400), unlocked: 0)
            XCTAssertNil(restored.activities.checkpoint(for: tomorrow))
            XCTAssertNil(restored.activities.checkpoint(for: daily))
            // An old in-flight attempt must not overwrite today's selection.
            restored.activities.save(checkpoint, for: daily)
            XCTAssertNil(restored.activities.checkpoint(for: tomorrow))
            XCTAssertEqual(restored.checkpoint?.score, 50)
        }
    }

    func testGardenRequiresEarnedDecorationsAndPersistsPlacementAndRemoval() throws {
        try withProgress { progress, defaults in
            XCTAssertEqual(progress.activities.availableDecorations(adventure: progress.adventure), [.blossoms])
            progress.activities.place(.lantern, at: 0, adventure: progress.adventure)
            progress.activities.place(.blossoms, at: -1, adventure: progress.adventure)
            XCTAssertNil(progress.activities.decoration(at: 0))
            let quest = try XCTUnwrap(FestivalQuest.all.first { $0.id == "parcels" })
            progress.adventure.accept(quest, unlockedLevel: 3)
            for level in 0..<3 {
                progress.adventure.recordWin(level: level, play: QuestPlay(collected: [quest.id]), completedLevels: 3)
            }
            XCTAssertTrue(progress.activities.availableDecorations(adventure: progress.adventure).contains(.bunting))
            progress.activities.place(.bunting, at: 5, adventure: progress.adventure)
            let restored = GameProgress(defaults: defaults)
            XCTAssertEqual(restored.activities.decoration(at: 5), .bunting)
            restored.activities.place(nil, at: 5, adventure: restored.adventure)
            XCTAssertNil(GameProgress(defaults: defaults).activities.decoration(at: 5))
            XCTAssertTrue(restored.adventure.completed(quest))
        }
    }

    func testTenLevelMilestonesUseTargetsOrAuthoredEventsAndMilestoneDialogueVaries() {
        for level in LevelCatalog.levels where level.number.isMultiple(of: 10) {
            if let event = FestivalEvent.forLevel(level.index) {
                XCTAssertEqual(level.goal, event.goal)
                XCTAssertTrue(level.goal.isValid(on: level.board))
                continue
            }
            XCTAssertEqual(level.objective, .ceiling)
            XCTAssertTrue(level.goal.isValid(on: level.board))
            XCTAssertFalse(level.goal.remaining.isEmpty)
            XCTAssertTrue(level.goal.remaining.allSatisfy { $0.row == 0 })
        }
        XCTAssertEqual(Set((0..<5).map { FestivalMoments.message(area: $0, stop: 10) }).count, 5)
        XCTAssertTrue(LevelCatalog.levels.prefix(5).allSatisfy { $0.objective == .clear })
    }

    func testActivitiesAreIncludedInBackupsAndSeparateForEachPlayer() throws {
        let suite = "ActivitiesBackup-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let original = profiles.active
        let progress = profiles.makeProgress()
        progress.activities.place(.blossoms, at: 2, adventure: progress.adventure)
        let daily = progress.activities.daily(unlocked: 0)
        progress.activities.complete(daily, adventure: progress.adventure)
        XCTAssertTrue(profiles.persistActive())
        let data = try Data(contentsOf: directory.appendingPathComponent(original.fileName))
        let backup = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertNotNil(backup["festivalActivities"])
        let second = try XCTUnwrap(profiles.create(name: "Second save"))
        defer { UserDefaults(suiteName: "\(suite).\(second.id)")?.removePersistentDomain(forName: "\(suite).\(second.id)") }
        XCTAssertNil(profiles.makeProgress().activities.decoration(at: 2))
        XCTAssertEqual(profiles.makeProgress().adventure.rainbowGifts, 0)
        XCTAssertTrue(profiles.select(original.id))
        XCTAssertEqual(profiles.makeProgress().activities.decoration(at: 2), .blossoms)
        XCTAssertEqual(profiles.makeProgress().adventure.rainbowGifts, 1)
    }

    @MainActor
    func testDailyPlayRequiresConfirmationPreservesCampaignAndDoesNotSpendTries() throws {
        let suite = "DailyScene-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress(); progress.tutorialSeen = true
        let base = LevelCatalog.level(0)
        progress.save(GameCheckpoint(level: 0, board: base.board, shots: base.shots, score: 123, current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay()))
        let dailyFixture = progress.activities.daily(unlocked: 0)
        let separated = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0, Cell(row: 0, column: 7): 1])
        progress.activities.save(GameCheckpoint(level: 0, board: separated, shots: 12, score: 0, current: 2, next: 1, bag: [], rainbow: 0, bomb: 0, play: QuestPlay(), challenge: true, layoutSeed: dailyFixture.seed, goal: PuzzleGoal(), shotBudget: 12), for: dailyFixture)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-adventure"])
        scene.handleMenu(["map-extras"]); scene.handleMenu(["daily-open"])
        scene.handleMenu(["daily-play"])
        XCTAssertNotNil(scene.childNode(withName: "//level-briefing-card"))
        scene.launchShot(angle: 0)
        XCTAssertNil(scene.childNode(withName: "//flying-bubble"))
        scene.handleMenu(["briefing-play"])
        scene.launchShot(angle: 0.2); scene.setActive(false)
        let restored = profiles.makeProgress()
        let daily = restored.activities.daily(unlocked: 0)
        let saved = try XCTUnwrap(restored.activities.checkpoint(for: daily))
        XCTAssertTrue(saved.hasStartedTry)
        XCTAssertEqual(saved.shotsFired, 1)
        XCTAssertEqual(saved.rainbow, 0); XCTAssertEqual(saved.bomb, 0)
        XCTAssertEqual(restored.checkpoint?.score, 123)
        XCTAssertEqual(restored.lives(for: 0).available, 5)
        XCTAssertEqual(restored.lives(for: 0, challenge: true).available, 5)
        XCTAssertEqual(restored.attempts(0), 0)
    }
}
