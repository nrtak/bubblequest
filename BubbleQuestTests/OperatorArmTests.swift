import XCTest
import SpriteKit
import UIKit
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
        for level in 0..<LevelCatalog.levelCount { progress.recordVictory(index: level, score: 200, stars: 1) }
        for quest in FestivalQuest.all {
            progress.adventure.accept(quest, unlockedLevel: LevelCatalog.levelCount - 1)
            var play = QuestPlay()
            play.collected.insert(quest.id); play.bounces = 1; play.dropped = 1
            play.colors = Set(0..<6)
            for level in quest.area * LevelCatalog.levelsPerArea..<quest.area * LevelCatalog.levelsPerArea + quest.steps.count {
                progress.adventure.recordWin(level: level, play: play, completedLevels: LevelCatalog.levelCount)
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
            scene.animateCompanion(.human, frames: [1, 2])
            if !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled {
                XCTAssertNotNil(buddy.action(forKey: "operating"), friend.id)
                XCTAssertNotNil(buddy.action(forKey: "expression"), friend.id)
            }

        }
    }

    @MainActor
    func testObjectiveInstructionsStayBelowTheHeadingAndAboveTheReturnButton() throws {
        let scene = FestivalScene(size: CGSize(width: 390, height: 844))
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.showObjectives()
        let body = try XCTUnwrap(scene.childNode(withName: "//objective-instructions") as? SKLabelNode)
        let overlay = try XCTUnwrap(body.parent)
        let title = try XCTUnwrap(overlay.children.compactMap { $0 as? SKLabelNode }.first { $0.fontSize == 25 })
        let button = try XCTUnwrap(overlay.childNode(withName: "objective-close"))
        XCTAssertLessThan(body.frame.maxY, title.frame.minY)
        XCTAssertGreaterThan(body.frame.minY, button.calculateAccumulatedFrame().maxY)
    }

    @MainActor
    func testNewerHumansHaveADistinctIdlePose() {
        let scene = FestivalScene(size: CGSize(width: 390, height: 844))
        for friend in Companion.all where friend.kind == .human && friend.atlasIndex >= 6 {
            XCTAssertEqual(scene.idleExpressionTexture(friend).textureRect().origin.x, 0.25, accuracy: 0.001, friend.id)
        }
    }

    @MainActor
    func testQuietModeStopsHumanActionsAndNormalModeRestartsIdleExpression() throws {
        let scene = FestivalScene(size: CGSize(width: 390, height: 844))
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        let human = try XCTUnwrap(scene.childNode(withName: "//companion-1") as? SKSpriteNode)
        human.run(.repeatForever(.wait(forDuration: 1)), withKey: "operating")
        human.run(.repeatForever(.wait(forDuration: 1)), withKey: "expression")
        scene.updateCompanionMotion(quiet: true)
        XCTAssertNil(human.action(forKey: "operating"))
        XCTAssertNil(human.action(forKey: "expression"))
        XCTAssertEqual(human.xScale, -1)
        XCTAssertEqual(human.yScale, 1)
        scene.updateCompanionMotion(quiet: false)
        XCTAssertNotNil(human.action(forKey: "expression"))
        XCTAssertNil(human.action(forKey: "operating"))
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
