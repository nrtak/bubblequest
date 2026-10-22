import XCTest
import SpriteKit
import UIKit
@testable import BubbleQuest

final class VisualPolishTests: XCTestCase {
    @MainActor
    private func withScene(size: CGSize = CGSize(width: 390, height: 844), check: (FestivalScene, SKView, GameProfiles) throws -> Void) throws {
        let suite = "VisualPolish-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress(); progress.tutorialSeen = true; progress.practiceDone = true
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        scene.scaleMode = .aspectFit
        let view = SKView(frame: CGRect(origin: .zero, size: size))
        view.presentScene(scene); defer { view.presentScene(nil) }
        try check(scene, view, profiles)
    }

    @MainActor
    private func sceneFrame(_ node: SKNode, in scene: SKScene) -> CGRect {
        guard let parent = node.parent else { return .zero }
        let box = node.calculateAccumulatedFrame()
        let a = parent.convert(CGPoint(x: box.minX, y: box.minY), to: scene)
        let b = parent.convert(CGPoint(x: box.maxX, y: box.maxY), to: scene)
        return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
    }

    @MainActor
    func testTitleAndGameplayClearStatusAreasAcrossIPhoneSizes() throws {
        let phones: [(CGSize, CGFloat)] = [
            (CGSize(width: 375, height: 667), 20),
            (CGSize(width: 390, height: 844), 59),
            (CGSize(width: 393, height: 852), 59),
            (CGSize(width: 402, height: 874), 62),
            (CGSize(width: 430, height: 932), 62)
        ]
        for (size, topInset) in phones {
            try withScene(size: size) { scene, _, _ in
                let mark = try XCTUnwrap(scene.childNode(withName: "//title-illustration"))
                let title = try XCTUnwrap(scene.childNode(withName: "//start-menu-heading"))
                XCTAssertGreaterThan(sceneFrame(mark, in: scene).minY, sceneFrame(title, in: scene).maxY + 8)
                let top = scene.convertPoint(toView: CGPoint(x: 195, y: sceneFrame(mark, in: scene).maxY)).y
                XCTAssertGreaterThanOrEqual(top, topInset + 6)
                scene.closeMenu()
                let header = try XCTUnwrap(scene.childNode(withName: "//quest-objective"))
                let box = sceneFrame(header, in: scene)
                XCTAssertGreaterThanOrEqual(scene.convertPoint(toView: CGPoint(x: box.midX, y: box.maxY)).y, topInset + 6)
                let gear = try XCTUnwrap(scene.childNode(withName: "//game-menu"))
                XCTAssertTrue(scene.interactionNames(at: gear.position).contains("game-menu"))
                let widthScale = min(size.width / 390, size.height / 844)
                let touch = CGPoint(x: gear.position.x, y: gear.position.y - min(24, 21 / widthScale))
                XCTAssertTrue(scene.interactionNames(at: touch).contains("game-menu"))
            }
        }
    }

    @MainActor
    func testWoodAndHousingShareCachedFinishesWithoutObscuringGlass() throws {
        try withScene { scene, _, _ in
            let deck = try XCTUnwrap(scene.childNode(withName: "//light-wood-platform") as? SKShapeNode)
            let base = try XCTUnwrap(scene.childNode(withName: "//character-platform") as? SKShapeNode)
            XCTAssertNotNil(deck.fillTexture)
            XCTAssertTrue(deck.fillTexture === base.fillTexture)
            let housing = try XCTUnwrap(scene.childNode(withName: "//shots-counter") as? SKShapeNode)
            XCTAssertNotNil(housing.fillTexture)
            let glass = try XCTUnwrap(scene.childNode(withName: "//cannon-glass") as? SKShapeNode)
            XCTAssertNil(glass.fillTexture)
            XCTAssertLessThan(glass.fillColor.cgColor.alpha, 0.2)
        }
    }

    @MainActor
    func testQuietMotionCancelsPresentationFadeAndKeepsWholeCharacterPoses() throws {
        let node = SKNode(); FestivalStyle.reveal(node, quiet: false)
        XCTAssertNotNil(node.action(forKey: "interface-reveal"))
        FestivalStyle.reveal(node, quiet: true)
        XCTAssertNil(node.action(forKey: "interface-reveal")); XCTAssertEqual(node.alpha, 1)
        try withScene { scene, _, _ in
            scene.updateCompanionMotion(quiet: true)
            for index in 0..<2 {
                let buddy = try XCTUnwrap(scene.childNode(withName: "//companion-\(index)"))
                XCTAssertNil(buddy.action(forKey: "breathing"))
                XCTAssertNil(buddy.action(forKey: "idle-expression"))
                XCTAssertEqual(buddy.yScale, 1)
            }
        }
    }

    @MainActor
    func testRewardPresentationAndSkippingNeverGrantThePrizeTwice() throws {
        try withScene { scene, _, profiles in
            let adventure = profiles.makeProgress().adventure
            adventure.synchronize(completedLevels: 100)
            var random = LayoutRandom(state: 42)
            let prize = try XCTUnwrap(adventure.draw(using: &random))
            let spins = adventure.availableSpins, rainbows = adventure.rainbowGifts, bombs = adventure.bombGifts
            scene.showWheelReward(prize)
            let label = try XCTUnwrap(scene.childNode(withName: "//wheel-reward-quantity") as? SKLabelNode)
            XCTAssertEqual(label.text, prize.title + " ×1")
            scene.dismissCelebrationEffects()
            XCTAssertNil(scene.childNode(withName: "//reward-delivery"))
            XCTAssertTrue(scene.interactionNames(at: CGPoint(x: 195, y: 185)).contains("wheel-return"))
            scene.handleMenu(["wheel-return"])
            let after = profiles.makeProgress().adventure
            XCTAssertEqual(after.availableSpins, spins)
            XCTAssertEqual(after.rainbowGifts, rainbows); XCTAssertEqual(after.bombGifts, bombs)
        }
    }

    @MainActor
    func testGroupedSettingsKeepPreferencesAndReturnToPausedPuzzle() throws {
        try withScene { scene, _, profiles in
            scene.closeMenu(); scene.showGameMenu(); scene.handleMenu(["settings"])
            let categories = ["sound-levels", "control-settings", "tutorial", "play-results"]
            for name in categories { XCTAssertNotNil(scene.childNode(withName: "//" + name)) }
            XCTAssertNil(scene.childNode(withName: "//setting-musicEnabled"))
            scene.handleMenu(["sound-levels"])
            let saved = profiles.makeProgress()
            let effects = saved.volumeStep(music: false)
            saved.changeVolume(music: true, by: -5)
            scene.handleMenu(["setting-musicEnabled"])
            XCTAssertTrue(saved.enabled(.music)); XCTAssertGreaterThan(saved.volumeStep(music: true), 0)
            XCTAssertEqual(saved.volumeStep(music: false), effects)
            XCTAssertNotNil(scene.childNode(withName: "//sound-back"))
            scene.handleMenu(["sound-back"]); scene.handleMenu(["control-settings"])
            let contrast = saved.enabled(.contrast)
            scene.handleMenu(["setting-highContrastEnabled"])
            XCTAssertEqual(saved.enabled(.contrast), !contrast)
            XCTAssertNotNil(scene.childNode(withName: "//setting-leftHandedEnabled"))
            scene.handleMenu(["sound-back"]); scene.handleMenu(["back"])
            XCTAssertNotNil(scene.childNode(withName: "//game-resume"))
            scene.handleMenu(["game-resume"])
            XCTAssertNil(scene.childNode(withName: "//game-resume"))
        }
    }

    @MainActor
    func testNativeLaunchScreenHasBrandArtworkAndFitsCompactPhones() throws {
        XCTAssertNotNil(UIImage(named: "festival-logo"))
        let controller = try XCTUnwrap(UIStoryboard(name: "LaunchScreen", bundle: .main).instantiateInitialViewController())
        for size in [CGSize(width: 375, height: 667), CGSize(width: 430, height: 932)] {
            controller.view.frame = CGRect(origin: .zero, size: size); controller.view.layoutIfNeeded()
            let image = try XCTUnwrap(controller.view.subviews.compactMap { $0 as? UIImageView }.first)
            XCTAssertNotNil(image.image)
            for label in controller.view.subviews.compactMap({ $0 as? UILabel }) {
                XCTAssertGreaterThan(label.frame.minY, image.frame.maxY)
                XCTAssertLessThan(label.frame.maxY, size.height - 20)
                XCTAssertGreaterThanOrEqual(label.frame.width, label.intrinsicContentSize.width)
            }
        }
    }
}
