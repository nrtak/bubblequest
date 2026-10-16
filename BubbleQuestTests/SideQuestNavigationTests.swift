import XCTest
import SpriteKit
@testable import BubbleQuest

final class SideQuestNavigationTests: XCTestCase {
    func testRequestsUnlockGraduallyAndStartAtTheCurrentLevel() throws {
        let suite = "SideQuestUnlock-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let adventure = AdventureProgress(defaults: defaults)
        let first = try XCTUnwrap(FestivalQuest.all.first { $0.id == "parcels" })
        let toy = try XCTUnwrap(FestivalQuest.all.first { $0.id == "toy" })
        for level in 0..<3 {
            XCTAssertFalse(adventure.available(first, unlockedLevel: level))
            adventure.accept(first, unlockedLevel: level)
            XCTAssertFalse(adventure.accepted(first))
            XCTAssertNil(adventure.nextLevel(first, unlockedLevel: level))
        }
        XCTAssertTrue(adventure.available(first, unlockedLevel: 3))
        adventure.accept(first, unlockedLevel: 3)
        XCTAssertEqual(adventure.nextLevel(first, unlockedLevel: 3), 3)
        XCTAssertFalse(adventure.available(toy, unlockedLevel: 5))
        XCTAssertTrue(adventure.available(toy, unlockedLevel: 6))
        let restored = AdventureProgress(defaults: defaults)
        XCTAssertTrue(restored.available(first, unlockedLevel: 0), "Previously accepted quests remain available")
    }

    func testQuestIntroductionIsDelayedAndOnlyShownOncePerPlayer() throws {
        let suite = "QuestIntroduction-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let adventure = AdventureProgress(defaults: defaults)
        XCTAssertNil(adventure.takeMapIntroduction(unlockedLevel: 2, area: 0))
        XCTAssertEqual(adventure.takeMapIntroduction(unlockedLevel: 3, area: 0)?.id, "parcels")
        XCTAssertNil(AdventureProgress(defaults: defaults).takeMapIntroduction(unlockedLevel: 6, area: 0))
        XCTAssertFalse(adventure.accepted(FestivalQuest.all[0]))
        for quest in FestivalQuest.all {
            XCTAssertFalse(quest.objectiveSummary.isEmpty)
            XCTAssertTrue(quest.rewardSummary.contains("spin"))
        }
    }

    @MainActor
    func testBackFromHostAndQuestNeverAcceptsTheRequest() throws {
        let suite = "SideQuestBack-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        for level in 0..<3 { progress.recordVictory(index: level, score: 100, stars: 1) }
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.handleMenu(["start-adventure"])
        let host = FestivalHost.all[0]
        scene.showHost(host)
        XCTAssertNotNil(scene.childNode(withName: "//dialogue-back"))
        scene.handleMenu(["dialogue-next"])
        scene.handleMenu(["dialogue-back"])
        XCTAssertNotNil(scene.childNode(withName: "//dialogue-back"), "Back from page two shows page one")
        scene.handleMenu(["dialogue-back"])
        XCTAssertNil(scene.childNode(withName: "//dialogue-back"))
        XCTAssertFalse(progress.hasMet(host), "Leaving early must not complete the introduction")
        let quest = FestivalQuest.all[0]
        scene.showQuest(quest)
        let back = try XCTUnwrap(scene.childNode(withName: "//quest-dialogue-back"))
        XCTAssertNotNil(back.parent?.children.compactMap { $0 as? SKLabelNode }.first { $0.text == "Optional Side Quest" })
        scene.handleMenu(["quest-dialogue-back"])
        XCTAssertFalse(profiles.makeProgress().adventure.accepted(quest))
        XCTAssertEqual(progress.unlockedLevel, 3)
    }
    @MainActor
    func testMapBranchesOpenRequestsDirectlyAndKeepDeclinedQuestsAvailable() throws {
        let suite = "SideQuestMap-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        for level in 0..<6 { progress.recordVictory(index: level, score: 100, stars: 1) }
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.handleMenu(["start-adventure"])
        let map = try XCTUnwrap(scene.childNode(withName: "//quest-parcels")?.parent)
        let cards = map.children.compactMap { $0 as? SKShapeNode }.filter { $0.name?.hasPrefix("quest-") == true }
        for (index, card) in cards.enumerated() {
            for other in cards.dropFirst(index + 1) {
                XCTAssertFalse(card.frame.intersects(other.frame), "Quest signs and the introduction must not overlap")
            }
        }
        for id in ["parcels", "toy"] {
            let stop = try XCTUnwrap(scene.childNode(withName: "//quest-" + id))
            XCTAssertTrue(stop.children.compactMap { $0 as? SKLabelNode }.contains { $0.text?.hasPrefix("Optional") == true })
            let location = stop.convert(CGPoint.zero, to: scene)
            XCTAssertTrue(scene.interactionNames(at: location).contains("quest-" + id))
            scene.handleMenu(["quest-" + id])
            let later = try XCTUnwrap(scene.childNode(withName: "//quest-dialogue-back"))
            XCTAssertTrue(later.children.compactMap { $0 as? SKLabelNode }.contains { $0.text == "Maybe later" })
            scene.handleMenu(["quest-dialogue-back"])
            XCTAssertNotNil(scene.childNode(withName: "//quest-" + id), "Leaving a quest keeps its map branch available")
        }
        XCTAssertFalse(profiles.makeProgress().adventure.accepted(FestivalQuest.all[0]))
        XCTAssertEqual(profiles.makeProgress().unlockedLevel, 6)
        XCTAssertNotNil(scene.childNode(withName: "//level-6"), "The numbered main route remains available independently")
    }

    @MainActor
    func testCompletedQuestDisplaysChosenRewardAndAcceptanceMeetsResident() throws {
        let suite = "QuestDisplay-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true
        for level in 0..<6 { progress.recordVictory(index: level, score: 100, stars: 1) }
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.handleMenu(["start-adventure"])
        scene.handleMenu(["quest-parcels"])
        scene.handleMenu(["quest-accept"])
        XCTAssertTrue(profiles.makeProgress().hasMet(FestivalHost.all[0]))
        let adventure = profiles.makeProgress().adventure
        let quest = FestivalQuest.all[0]
        for level in 0..<3 { adventure.recordWin(level: level, play: QuestPlay(collected: [quest.id]), completedLevels: 6) }
        adventure.chooseStyle(2, for: quest)
        // Reload progress as the game does when selecting a player.
        scene.handleMenu(["home"]); scene.handleMenu(["players"]); scene.handleMenu(["player-original"])
        scene.handleMenu(["start-adventure"])
        let reward = try XCTUnwrap(scene.childNode(withName: "//quest-display-parcels"))
        XCTAssertNotNil(reward.parent?.parent?.childNode(withName: "courtyard-greeting"))
    }

}
