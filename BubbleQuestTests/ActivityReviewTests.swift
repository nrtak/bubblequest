import XCTest
import SpriteKit
@testable import BubbleQuest

final class ActivityReviewTests: XCTestCase {
    func testDailyDifficultyDescribesTheActualMilestonePuzzle() {
        for index in [0, 9, 13, 19, 59, 99] {
            let daily = DailyFestivalPuzzle(day: "2026-11-02", level: index, seed: 42)
            XCTAssertEqual(daily.difficulty, daily.definition.difficultyTitle)
        }
        XCTAssertEqual(DailyFestivalPuzzle(day: "2026-11-02", level: 9, seed: 42).difficulty, "Milestone challenge")
    }

    func testGardenAndAdventureChangesUpdateTheSavedTimestamp() throws {
        let suite = "ActivityStamp-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = GameProgress(defaults: defaults)
        let oldDate = Date(timeIntervalSince1970: 1)
        defaults.set(oldDate, forKey: "lastSaved")
        progress.activities.place(.blossoms, at: 0, adventure: progress.adventure)
        XCTAssertGreaterThan(try XCTUnwrap(progress.lastSaved), oldDate)
        defaults.set(oldDate, forKey: "lastSaved")
        progress.adventure.awardDailyRainbow(day: "2026-11-02")
        XCTAssertGreaterThan(try XCTUnwrap(progress.lastSaved), oldDate)
    }

    func testOutOfRangeSavedDecorationStylesCannotCrashThePalette() throws {
        let suite = "ActivityStyle-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let quest = FestivalQuest.all[0]
        AdventureProgress(defaults: defaults).accept(quest, unlockedLevel: 3)
        let data = try XCTUnwrap(defaults.data(forKey: "festivalAdventure"))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        for (invalid, expected) in [(-10, 0), (99, 2)] {
            var patched = json; patched["styles"] = [quest.id: invalid]
            defaults.set(try JSONSerialization.data(withJSONObject: patched), forKey: "festivalAdventure")
            XCTAssertEqual(AdventureProgress(defaults: defaults).style(quest), expected)
        }
    }

    func testBuntingWonFromTheWheelIsUsableWithoutFinishingTheDeliveryQuest() throws {
        let suite = "WheelGarden-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let quest = FestivalQuest.all[0]
        AdventureProgress(defaults: defaults).accept(quest, unlockedLevel: 3)
        let data = try XCTUnwrap(defaults.data(forKey: "festivalAdventure"))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        json["pins"] = [FestivalPrize.lanternColors.rawValue]
        defaults.set(try JSONSerialization.data(withJSONObject: json), forKey: "festivalAdventure")
        let progress = GameProgress(defaults: defaults)
        XCTAssertFalse(progress.adventure.completed(quest))
        XCTAssertTrue(progress.activities.availableDecorations(adventure: progress.adventure).contains(.bunting))
        progress.activities.place(.bunting, at: 1, adventure: progress.adventure)
        XCTAssertEqual(GameProgress(defaults: defaults).activities.decoration(at: 1), .bunting)
    }

    func testResumedBriefingExplainsOnlyTheObjectsStillNeeded() {
        let a = Cell(row: 0, column: 0), b = Cell(row: 0, column: 1), c = Cell(row: 0, column: 2)
        var goal = PuzzleGoal(kind: .lanterns, targets: [a, b, c])
        XCTAssertEqual(goal.briefingSummary, goal.startSummary)
        goal.collect([a, b])
        XCTAssertTrue(goal.briefingSummary.contains("1 lantern left out of 3"))
        XCTAssertTrue(goal.briefingSummary.contains("Other bubbles can stay"))
        XCTAssertEqual(PuzzleGoal().briefingSummary, "Clear every bubble to win.")
    }

    @MainActor
    func testCompletedQuestLeadsToTheGardenAndKeepsItsChosenColor() throws {
        let quest = FestivalQuest.all[0]
        try withScene(configure: { progress in
            progress.adventure.accept(quest, unlockedLevel: 3)
            for level in 0..<3 {
                progress.adventure.recordWin(level: level, play: QuestPlay(collected: [quest.id]), completedLevels: 3)
            }
            progress.adventure.chooseStyle(2, for: quest)
        }) { scene, profiles in
            scene.showQuest(quest)
            XCTAssertNotNil(scene.childNode(withName: "//quest-garden"))
            scene.handleMenu(["quest-garden"])
            XCTAssertNotNil(scene.childNode(withName: "//garden-plots"))
            scene.handleMenu(["garden-next"]); scene.handleMenu(["garden-slot-0"])
            let restored = profiles.makeProgress()
            XCTAssertEqual(restored.activities.decoration(at: 0), .bunting)
            XCTAssertEqual(restored.adventure.style(quest), 2)
            scene.handleMenu(["activity-back"])
            XCTAssertNotNil(scene.childNode(withName: "//map-route"))
        }
    }

    @MainActor
    func testDailyLossExplainsTheSamePuzzleAndDoesNotChargeForRetry() throws {
        try withScene(configure: { progress in
            let daily = progress.activities.daily(unlocked: 0)
            let board = BubbleBoard(bubbles: [Cell(row: 0, column: 0): 0, Cell(row: 0, column: 7): 1])
            progress.activities.save(GameCheckpoint(level: 0, board: board, shots: 1, score: 0, current: 2, next: 1, bag: [], rainbow: 0, bomb: 0, play: QuestPlay(), challenge: true, shotsFired: 11, layoutSeed: daily.seed, goal: PuzzleGoal(), shotBudget: 12), for: daily)
        }) { scene, profiles in
            openDaily(scene)
            scene.launchShot(angle: 0); scene.setActive(false)
            let detail = try XCTUnwrap(scene.childNode(withName: "//result-detail") as? SKLabelNode)
            XCTAssertTrue(detail.text?.contains("same puzzle") == true)
            XCTAssertNil(scene.childNode(withName: "//result-tries"))
            scene.continueAfterResult()
            XCTAssertNotNil(scene.childNode(withName: "//level-briefing-card"))
            let progress = profiles.makeProgress()
            XCTAssertEqual(progress.lives(for: 0).available, 5)
            XCTAssertEqual(progress.lives(for: 0, challenge: true).available, 5)
        }
    }

    @MainActor
    func testDailyWinAndReplayUseDifferentRewardCaptionsWithoutDuplicateGifts() throws {
        for alreadyCompleted in [false, true] {
            try withScene(configure: { progress in
                let daily = progress.activities.daily(unlocked: 0)
                if alreadyCompleted { progress.activities.complete(daily, adventure: progress.adventure) }
                let board = BubbleBoard(bubbles: [Cell(row: 0, column: 3): 0, Cell(row: 0, column: 4): 0])
                progress.activities.save(GameCheckpoint(level: 0, board: board, shots: 12, score: 0, current: 0, next: 1, bag: [], rainbow: 0, bomb: 0, play: QuestPlay(), challenge: true, layoutSeed: daily.seed, goal: PuzzleGoal(), shotBudget: 12), for: daily)
            }) { scene, profiles in
                openDaily(scene)
                scene.launchShot(angle: 0); scene.setActive(false)
                let caption = try XCTUnwrap(scene.childNode(withName: "//result-reward-caption") as? SKLabelNode)
                XCTAssertEqual(caption.text, alreadyCompleted ? "Today's reward is already collected" : "Rainbow added to your saved boosters")
                XCTAssertEqual(profiles.makeProgress().adventure.rainbowGifts, 1)
                XCTAssertEqual(profiles.makeProgress().completedCount, 0)
            }
        }
    }

    @MainActor
    private func openDaily(_ scene: FestivalScene) {
        scene.handleMenu(["start-adventure"]); scene.handleMenu(["map-extras"])
        scene.handleMenu(["daily-open"]); scene.handleMenu(["daily-play"])
        scene.handleMenu(["briefing-play"])
    }

    @MainActor
    private func withScene(configure: (GameProgress) throws -> Void,
                           body: (FestivalScene, GameProfiles) throws -> Void) throws {
        let suite = "ActivityReview-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress(); progress.tutorialSeen = true
        try configure(progress)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        try body(scene, profiles)
    }
}
