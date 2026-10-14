import XCTest
import SpriteKit
@testable import BubbleQuest

final class OperatorArmTests: XCTestCase {
    @MainActor
    func testEveryOperatorUsesCompletePoseBehindTheWheel() throws {
        let suite = "OperatorArms-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        for level in 0..<200 { progress.recordVictory(index: level, score: 200, stars: 1) }
        for quest in FestivalQuest.all {
            progress.adventure.accept(quest, unlockedLevel: 199)
            var play = QuestPlay()
            play.collected.insert(quest.id); play.bounces = 1; play.dropped = 1
            play.colors = Set(0..<6)
            for level in quest.area * 10..<quest.area * 10 + quest.steps.count {
                progress.adventure.recordWin(level: level, play: play, completedLevels: 200)
            }
        }
        for friend in Companion.all where friend.kind == .human {
            progress.select(friend)
            XCTAssertEqual(progress.selected(.human).id, friend.id)
            let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
            scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
            let wheel = try XCTUnwrap(scene.childNode(withName: "//handwheel"))
            let buddy = try XCTUnwrap(scene.childNode(withName: "//companion-1") as? SKSpriteNode)
            XCTAssertNil(buddy.childNode(withName: "operator-arm"))
            XCTAssertNil(scene.childNode(withName: "//operator-grip"))
            XCTAssertGreaterThan(wheel.zPosition, buddy.zPosition)
            XCTAssertNotNil(buddy.texture)

        }
    }

    @MainActor
    func testPuzzleMenuPausesWithoutRestartingAndBubbleIsSwapTarget() throws {
        let scene = FestivalScene(size: CGSize(width: 390, height: 844))
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.closeMenu()
        let wheel = try XCTUnwrap(scene.childNode(withName: "//handwheel"))
        let game = try XCTUnwrap(wheel.parent)
        XCTAssertNil(game.childNode(withName: "home"))
        XCTAssertNil(game.childNode(withName: "retry"))
        XCTAssertNil(game.childNode(withName: "swap"))
        XCTAssertNil(game.childNode(withName: "next-caption"))
        let bubble = try XCTUnwrap(game.childNode(withName: "swap-bubble"))
        XCTAssertTrue(scene.interactionNames(at: bubble.convert(CGPoint.zero, to: scene)).contains("swap-bubble"))
        scene.showGameMenu()
        XCTAssertTrue(game.isPaused)
        scene.handleMenu(["game-resume"])
        XCTAssertFalse(game.isPaused)
        XCTAssertTrue(game.childNode(withName: "swap-bubble") === bubble)
    }
}
