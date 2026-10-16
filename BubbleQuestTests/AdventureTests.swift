import XCTest
@testable import BubbleQuest

final class AdventureTests: XCTestCase {
    func testBuddyWelcomeSurvivesInterruptionAndSoundShortcutPersists() {
        let suite = "BubbleQuestWelcome-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = GameProgress(defaults: defaults)
        XCTAssertNil(progress.pendingBuddy)
        for index in 0..<20 { progress.recordVictory(index: index, score: 100, stars: 1) }
        XCTAssertEqual(GameProgress(defaults: defaults).pendingBuddy?.id, "white-shiba")
        while let buddy = progress.pendingBuddy { progress.welcome(buddy) }
        XCTAssertNil(GameProgress(defaults: defaults).pendingBuddy)
        progress.toggleSound()
        XCTAssertTrue(GameProgress(defaults: defaults).soundMuted)
        progress.toggleSound()
        XCTAssertTrue(progress.enabled(.music))
        XCTAssertTrue(progress.enabled(.effects))
    }

    func testQuestCompletionAndRewardChoicePersistWithoutDuplicateSpin() {
        let suite = "BubbleQuestStory-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let adventure = AdventureProgress(defaults: defaults)
        let quest = FestivalQuest.all.first { $0.id == "lanterns" }!
        adventure.accept(quest, unlockedLevel: 40)
        var play = QuestPlay(); play.collected.insert(quest.id)
        for index in 40..<43 { adventure.recordWin(level: index, play: play, completedLevels: 3) }
        adventure.chooseStyle(2, for: quest)
        let restored = AdventureProgress(defaults: defaults)
        XCTAssertTrue(restored.completed(quest))
        XCTAssertEqual(restored.style(quest), 2)
        XCTAssertEqual(restored.availableSpins, 1)
        XCTAssertTrue(restored.recordWin(level: 43, play: play, completedLevels: 3).isEmpty)
        XCTAssertEqual(restored.availableSpins, 1)
    }

    func testSavedPuzzleAndAttemptStatisticsSurviveReopening() throws {
        let suite = "BubbleQuestSave-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = GameProgress(defaults: defaults)
        let checkpoint = GameCheckpoint(level: 0, board: LevelCatalog.level(0).board, shots: 10, score: 120,
                                        current: 0, next: 1, bag: [1, 0], rainbow: 0, bomb: 1, play: QuestPlay(), freeRainbow: false)
        progress.recordVictory(index: 9, score: 100, stars: 1)
        progress.save(checkpoint)
        progress.recordAttempt(0)
        let reopened = GameProgress(defaults: defaults)
        let saved = try XCTUnwrap(reopened.checkpoint)
        XCTAssertEqual(saved.shots, 10)
        XCTAssertEqual(saved.score, 120)
        XCTAssertEqual(saved.freeRainbow, false)
        XCTAssertEqual(reopened.unlockedLevel, 10)
        XCTAssertEqual(reopened.currentLevel, 0, "A replay must stay current even after later levels unlock")
        XCTAssertEqual(saved.board?.bubbles, checkpoint.board?.bubbles)
        XCTAssertNotNil(reopened.lastSaved)
        XCTAssertEqual(reopened.attempts(0), 1)
        reopened.recordAttempt(-1)
        XCTAssertEqual(reopened.attempts(0), 1)
        reopened.clearCheckpoint()
        XCTAssertNil(GameProgress(defaults: defaults).checkpoint)
        XCTAssertEqual(GameProgress(defaults: defaults).currentLevel, 10)
    }

    func testNeighborsFollowAreaUnlocksAndRememberIntroductions() {
        let suite = "BubbleQuestNeighbors-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = GameProgress(defaults: defaults)
        XCTAssertEqual(FestivalNeighbor.all.count, 14)
        XCTAssertEqual(Set(FestivalNeighbor.all.map(\.id)).count, 14)
        XCTAssertEqual(Set(FestivalNeighbor.all.map(\.area)), Set(0..<11))
        let aya = FestivalNeighbor.all.first { $0.id == "aya" }!
        let shin = FestivalNeighbor.all.first { $0.id == "shin" }!
        progress.markMet(aya)
        XCTAssertFalse(progress.hasMet(aya), "Locked neighbors cannot be marked as met")
        for index in 0..<20 { progress.recordVictory(index: index, score: 100, stars: 1) }
        XCTAssertTrue(progress.neighborIsAvailable(aya))
        XCTAssertFalse(progress.neighborIsAvailable(shin))
        progress.markMet(aya)
        XCTAssertTrue(GameProgress(defaults: defaults).hasMet(aya))
    }

    func testNewHumansUnlockThroughDistinctLevelWinsAndCompletedQuests() {
        let suite = "BubbleQuestCast-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = GameProgress(defaults: defaults)
        let newFriends = Companion.all.filter { $0.kind == .human && $0.atlasIndex >= 6 }
        XCTAssertEqual(newFriends.count, 6)
        XCTAssertEqual(Set(newFriends.map(\.id)).count, 6)
        XCTAssertTrue(newFriends.allSatisfy { !progress.unlocked($0) })
        let haru = newFriends.first { $0.id == "haru" }!
        for _ in 0..<5 { progress.recordVictory(index: 0, score: 100, stars: 3) }
        XCTAssertFalse(progress.unlocked(haru), "Replays must not count as new level clears")
        for index in 1..<20 { progress.recordVictory(index: index, score: 100, stars: 3) }
        XCTAssertTrue(progress.unlocked(haru))
        let mei = newFriends.first { $0.id == "mei" }!
        progress.select(mei)
        XCTAssertNotEqual(progress.selected(.human).id, "mei")
        let quest = FestivalQuest.all.first { $0.id == "parcels" }!
        progress.adventure.accept(quest, unlockedLevel: progress.unlockedLevel)
        var play = QuestPlay()
        play.collected.insert(quest.id)
        for index in 0..<2 { progress.adventure.recordWin(level: index, play: play, completedLevels: 5) }
        progress.adventure.recordWin(level: 0, play: play, completedLevels: 5)
        XCTAssertFalse(progress.unlocked(mei), "Repeated quest puzzles must not advance the story")
        progress.adventure.recordWin(level: 2, play: play, completedLevels: 5)
        XCTAssertFalse(progress.unlocked(mei), "Quest rewards wait for the area's character milestone")
        for index in 20..<40 { progress.recordVictory(index: index, score: 100, stars: 1) }
        XCTAssertTrue(progress.unlocked(mei))
        progress.select(mei)
        XCTAssertEqual(GameProgress(defaults: defaults).selected(.human).id, "mei")
        XCTAssertFalse(progress.unlocked(newFriends.first { $0.id == "kaito" }!))
    }

    func testWheelRetainsRewardsAndFavorsBoosters() {
        let suite = "BubbleQuestWheel-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        struct Seeded: RandomNumberGenerator {
            var value: UInt64 = 42
            mutating func next() -> UInt64 {
                value = value &* 6364136223846793005 &+ 1442695040888963407
                return value
            }
        }
        var random = Seeded()
        var helpful = 0
        // Fresh progress each time measures the intended odds before duplicate conversion.
        for _ in 0..<1000 {
            defaults.removeObject(forKey: "festivalAdventure")
            let adventure = AdventureProgress(defaults: defaults)
            adventure.synchronize(completedLevels: 5)
            let prize = adventure.draw(using: &random)!
            if prize == .rainbow || prize == .bomb { helpful += 1 }
            let restored = AdventureProgress(defaults: defaults)
            XCTAssertEqual(restored.lastPrize, prize)
            XCTAssertEqual(restored.availableSpins, 0)
            XCTAssertNil(restored.draw(using: &random))
        }
        XCTAssertGreaterThan(helpful, 740)
        XCTAssertLessThan(helpful, 860)
    }
}
