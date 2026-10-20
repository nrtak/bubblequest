import XCTest
import SpriteKit
@testable import BubbleQuest

final class CourtyardWelcomeTests: XCTestCase {
    @MainActor
    func testNewAreaIntroducesItsResidentOnceWithoutAcceptingAQuest() throws {
        for area in [1, 10] {
            let suite = "CourtyardWelcome-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
            defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
            let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
            let progress = profiles.makeProgress()
            progress.tutorialSeen = true
            for index in 0..<(area * LevelCatalog.levelsPerArea) { progress.recordVictory(index: index, score: 100, stars: 1) }
            let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            view.presentScene(scene)
            defer { view.presentScene(nil) }
            scene.handleMenu(["start-adventure"])
            XCTAssertNotNil(scene.childNode(withName: "//courtyard-welcome-explore"))
            XCTAssertNotNil(scene.childNode(withName: "//courtyard-resident-portrait"))
            XCTAssertEqual((scene.childNode(withName: "//courtyard-resident-name") as? SKLabelNode)?.text, area == 1 ? "Meet Ren" : "Meet Rin")
            XCTAssertNotNil(scene.childNode(withName: "//courtyard-reward-preview"))
            let intro = try XCTUnwrap(scene.childNode(withName: "//courtyard-welcome-introduction") as? SKShapeNode)
            let frame = try XCTUnwrap(scene.childNode(withName: "//courtyard-portrait-frame") as? SKShapeNode)
            let portrait = try XCTUnwrap(scene.childNode(withName: "//courtyard-resident-portrait") as? SKSpriteNode)
            XCTAssertTrue(portrait.parent is SKCropNode, "The waist portrait needs a deliberate frame")
            XCTAssertLessThan(frame.frame.maxY + 12, intro.frame.minY)
            let introduction = try XCTUnwrap(scene.childNode(withName: "//courtyard-resident-role") as? SKLabelNode)
            XCTAssertGreaterThan(introduction.frame.minY, intro.frame.minY)
            XCTAssertGreaterThan(introduction.position.y, frame.frame.maxY)
            let areaName = try XCTUnwrap(scene.childNode(withName: "//courtyard-area-name") as? SKLabelNode)
            let residentName = try XCTUnwrap(scene.childNode(withName: "//courtyard-resident-name") as? SKLabelNode)
            let divider = try XCTUnwrap(scene.childNode(withName: "//courtyard-introduction-divider"))
            XCTAssertGreaterThan(areaName.frame.minY, divider.position.y + 16)
            XCTAssertLessThan(residentName.frame.maxY, divider.position.y - 10)
            XCTAssertLessThan(introduction.frame.maxY, residentName.frame.minY - 8)
            XCTAssertEqual(introduction.text, FestivalHost.all.first { $0.area == area }?.role ?? FestivalNeighbor.all.first { $0.area == area }?.role)

            let rewards = try XCTUnwrap(scene.childNode(withName: "//courtyard-reward-preview") as? SKShapeNode)
            XCTAssertLessThan(rewards.frame.maxY + 12, frame.frame.minY)

            XCTAssertFalse(progress.hasWelcomedCourtyard(area))
            scene.handleMenu(["result-next"])
            XCTAssertNotNil(scene.childNode(withName: "//courtyard-welcome-explore"), "A stale result tap must not skip the welcome or advance a level")
            XCTAssertNil(profiles.makeProgress().checkpoint)
            scene.handleMenu(["courtyard-welcome-explore"])
            XCTAssertTrue(profiles.makeProgress().hasWelcomedCourtyard(area))
            XCTAssertNotNil(scene.childNode(withName: "//map-reward-preview"))
            XCTAssertNotNil(scene.childNode(withName: "//map-route"))
            XCTAssertTrue(FestivalQuest.all.allSatisfy { !profiles.makeProgress().adventure.accepted($0) })
            scene.handleMenu(["home"])
            scene.handleMenu(["start-adventure"])
            XCTAssertNil(scene.childNode(withName: "//courtyard-welcome-explore"))
            XCTAssertNotNil(scene.childNode(withName: "//map-route"))
            scene.handleMenu(["area-next"])
            XCTAssertNil(scene.childNode(withName: "//courtyard-welcome-explore"))
        }
    }

    func testWelcomeUsesStoryMusicEvenAfterChallengeMode() {
        XCTAssertEqual(FestivalAudio.track(menu: "courtyard-welcome", area: 1, challenge: true), "music-story")
    }

    func testLockedAreasCannotBeAcknowledged() {
        let suite = "LockedWelcome-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = GameProgress(defaults: defaults)
        for area in [-1, 0, 1, LevelCatalog.areas.count] {
            progress.markCourtyardWelcomed(area)
            XCTAssertFalse(progress.hasWelcomedCourtyard(area))
        }
    }
}
