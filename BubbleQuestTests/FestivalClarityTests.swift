import XCTest
import SpriteKit
@testable import BubbleQuest

final class FestivalClarityTests: XCTestCase {
    @MainActor
    private func withScene(_ body: (FestivalScene, GameProgress) throws -> Void) rethrows {
        let suite = "FestivalClarity-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        try body(scene, profiles.makeProgress())
    }

    @MainActor
    func testUnlockPreviewShowsProgressAndReturnsWithoutAcceptingQuest() throws {
        try withScene { scene, progress in
            let mei = try XCTUnwrap(Companion.all.first { $0.id == "mei" })
            for index in 0..<25 { progress.recordVictory(index: index, score: 100, stars: 1) }
            XCTAssertEqual(progress.unlockLevelProgress(mei), "5/20 area levels")
            XCTAssertEqual(progress.unlockQuestProgress(mei), "Hana's delivery 0/3")
            scene.handleMenu(["start-adventure"])
            XCTAssertNil(scene.childNode(withName: "//courtyard-welcome-explore"))
            scene.handleMenu(["friends"])
            scene.handleMenu(["friend-mei"])
            XCTAssertNotNil(scene.childNode(withName: "//companion-preview-portrait"))
            XCTAssertFalse(progress.unlocked(mei))
            scene.handleMenu(["preview-back"])
            XCTAssertNotNil(scene.childNode(withName: "//map-buddies-close"))
            XCTAssertFalse(progress.hasWelcomedCourtyard(1))
            XCTAssertTrue(FestivalQuest.all.allSatisfy { !progress.adventure.accepted($0) })
        }
    }

    @MainActor
    func testCurrentLevelControlRecentersWithoutStartingPuzzle() throws {
        try withScene { scene, progress in
            progress.tutorialSeen = true
            scene.handleMenu(["start-adventure"])
            XCTAssertNil(scene.childNode(withName: "//map-current-level"))
            scene.scrollMap(to: -10000)
            XCTAssertNotNil(scene.childNode(withName: "//map-current-level"))
            scene.handleMenu(["map-current-level"])
            XCTAssertNil(scene.childNode(withName: "//map-current-level"))
            XCTAssertFalse(try XCTUnwrap(scene.childNode(withName: "//level-0")).isHidden)
            XCTAssertNil(progress.checkpoint)
        }
    }

    @MainActor
    func testCelebrationSkipDoesNotChooseOrAdvanceAndDisplayedUnlockIsChosen() throws {
        try withScene { scene, progress in
            for index in 0..<20 { progress.recordVictory(index: index, score: 100, stars: 1) }
            let haru = try XCTUnwrap(Companion.all.first { $0.id == "haru" })
            let previousAnimal = progress.selected(.animal).id
            let firstBuddy = try XCTUnwrap(Companion.all.first { $0.id == "white-shiba" })
            progress.welcome(firstBuddy)
            XCTAssertEqual(progress.pendingBuddy?.id, haru.id)
            scene.handleMenu(["new-buddy"])
            scene.handleMenu([])
            XCTAssertNotNil(scene.childNode(withName: "//buddy-choose"))
            XCTAssertEqual(progress.selected(.animal).id, previousAnimal)
            XCTAssertNil(progress.checkpoint)
            scene.handleMenu(["buddy-choose"]); scene.handleMenu(["briefing-play"])
            XCTAssertEqual(progress.selected(.human).id, "haru")
            XCTAssertEqual(progress.selected(.animal).id, previousAnimal)
            XCTAssertNotEqual(progress.pendingBuddy?.id, "haru")
        }
    }

    @MainActor
    func testNewPlayerCanFindMapTutorialAndControlsWithoutSideQuest() throws {
        try withScene { scene, progress in
            XCTAssertNotNil(scene.childNode(withName: "//start-continue"))
            scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
            XCTAssertNotNil(scene.childNode(withName: "//level-0"))
            XCTAssertTrue(FestivalQuest.all.allSatisfy { !progress.adventure.available($0, unlockedLevel: 0) })
            scene.handleMenu(["level-0"]); scene.handleMenu(["briefing-play"])
            XCTAssertNotNil(scene.childNode(withName: "//tutorial-next"))
            XCTAssertNotNil(scene.childNode(withName: "//game-menu"))
            XCTAssertNotNil(scene.childNode(withName: "//shots-counter"))
            XCTAssertNil(scene.childNode(withName: "//quest-objective"))
            XCTAssertFalse(progress.tutorialSeen)
        }
    }
}
