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
        XCTAssertFalse(progress.adventure.accepted(quest))
        XCTAssertEqual(progress.unlockedLevel, 3)
    }
}
