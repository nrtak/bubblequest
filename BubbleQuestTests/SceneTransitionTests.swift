import XCTest
import SpriteKit
import UIKit
@testable import BubbleQuest

final class SceneTransitionTests: XCTestCase {
    @MainActor
    private func withScene(_ check: (FestivalScene, GameProfiles) throws -> Void) throws {
        let suite = "SceneTransitions-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        profiles.makeProgress().tutorialSeen = true
        defer {
            for player in profiles.players where player.id != "original" {
                profiles.defaults(for: player).removePersistentDomain(forName: "\(suite).\(player.id)")
            }
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.handleMenu(["continue-stop"])
        try check(scene, profiles)
    }

    @MainActor
    func testOpeningMenuCommitsFlightOnceAndResumeKeepsIt() throws {
        try withScene { scene, profiles in
            let before = try XCTUnwrap(profiles.makeProgress().checkpoint)
            scene.launchShot(angle: 0)
            XCTAssertNotNil(scene.childNode(withName: "//flying-bubble"))
            scene.showGameMenu()
            let saved = try XCTUnwrap(profiles.makeProgress().checkpoint)
            XCTAssertEqual(saved.shots, before.shots - 1)
            XCTAssertEqual(saved.shotsFired, 1)
            XCTAssertNil(scene.childNode(withName: "//flying-bubble"))
            scene.handleMenu(["home"])
            scene.handleMenu(["continue-stop"])
            let resumed = try XCTUnwrap(profiles.makeProgress().checkpoint)
            XCTAssertEqual(resumed.shots, saved.shots)
            XCTAssertEqual(resumed.shotsFired, saved.shotsFired)
            XCTAssertEqual(resumed.board?.bubbles, saved.board?.bubbles)
        }
    }

    @MainActor
    func testBackgroundingCommitsFlightWithoutChargingTwice() throws {
        try withScene { scene, profiles in
            let before = try XCTUnwrap(profiles.makeProgress().checkpoint)
            scene.launchShot(angle: 0)
            scene.setActive(false)
            scene.setActive(true)
            scene.setActive(false)
            scene.setActive(true)
            let saved = try XCTUnwrap(profiles.makeProgress().checkpoint)
            XCTAssertEqual(saved.shots, before.shots - 1)
            XCTAssertEqual(saved.shotsFired, 1)
            XCTAssertNil(scene.childNode(withName: "//flying-bubble"))
        }
    }

    @MainActor
    func testCreatingAnotherPlayerKeepsTheOutgoingPuzzleInItsOwnSave() throws {
        try withScene { scene, profiles in
            scene.launchShot(angle: 0)
            scene.showGameMenu()
            let original = try XCTUnwrap(profiles.makeProgress().checkpoint)
            scene.handleMenu(["home"])
            scene.handleMenu(["players"])
            scene.requestPlayerName = { _, completion in completion("Guest") }
            scene.handleMenu(["player-create"])
            XCTAssertEqual(profiles.active.name, "Guest")
            XCTAssertEqual(profiles.makeProgress().checkpoint?.shotsFired, 0)
            scene.handleMenu(["home"])
            scene.handleMenu(["players"])
            scene.handleMenu(["player-original"])
            XCTAssertEqual(profiles.active.id, "original")
            XCTAssertEqual(profiles.makeProgress().checkpoint?.shotsFired, 1)
            XCTAssertEqual(profiles.makeProgress().checkpoint?.board?.bubbles, original.board?.bubbles)
        }
    }

    @MainActor
    func testLongNamesWrapAndPlayerCardsShowSavedPuzzle() throws {
        try withScene { scene, profiles in
            XCTAssertTrue(profiles.renameActive(String(repeating: "W", count: 24)))
            profiles.makeProgress().recordVictory(index: 49, score: 100, stars: 1)
            scene.handleMenu(["home"])
            let welcome = try XCTUnwrap(scene.childNode(withName: "//welcome-player") as? SKLabelNode)
            XCTAssertEqual(welcome.numberOfLines, 2)
            XCTAssertEqual(welcome.preferredMaxLayoutWidth, 300)
            XCTAssertEqual(welcome.lineBreakMode, .byCharWrapping)
            scene.handleMenu(["players"])
            let overlay = try XCTUnwrap(scene.children.last)
            let labels = overlay.children.compactMap { ($0 as? SKLabelNode)?.text }
            XCTAssertTrue(labels.contains("1 • Saved on this iPhone"))
            let card = try XCTUnwrap(overlay.childNode(withName: "player-original"))
            let title = try XCTUnwrap(card.children.first as? SKLabelNode)
            let font = UIFont(name: title.fontName!, size: title.fontSize)!
            XCTAssertLessThanOrEqual((title.text! as NSString).size(withAttributes: [.font: font]).width, 272.01)
        }
    }

    @MainActor
    func testAreasWithoutNeighborsDoNotOfferEmptyScreens() throws {
        try withScene { scene, _ in
            scene.handleMenu(["start-adventure"])
            for _ in 0..<20 { scene.handleMenu(["area-prev"]) }
            for area in LevelCatalog.areas.indices {
                let overlay = try XCTUnwrap(scene.children.last)
                XCTAssertEqual(overlay.childNode(withName: "neighbors") != nil,
                               area == 0 && FestivalNeighbor.all.contains { $0.area == area })
                scene.handleMenu(["area-next"])
            }
        }
    }
}
