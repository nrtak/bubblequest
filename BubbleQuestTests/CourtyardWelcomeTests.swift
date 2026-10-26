import XCTest
import SpriteKit
@testable import BubbleQuest

final class CourtyardWelcomeTests: XCTestCase {
    @MainActor
    func testSceneryChangesWithoutAnAreaUnlockInterruptionOrAutomaticQuestAcceptance() throws {
        for area in [1, 10] {
            let suite = "JourneyBoundary-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
            defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
            let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
            let progress = profiles.makeProgress(); progress.tutorialSeen = true
            for index in 0..<(area * 20) { progress.recordVictory(index: index, score: 100, stars: 1) }
            let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
            let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
            view.presentScene(scene); defer { view.presentScene(nil) }
            scene.handleMenu(["start-adventure"])
            XCTAssertNil(scene.childNode(withName: "//courtyard-welcome-explore"))
            XCTAssertNotNil(scene.childNode(withName: "//map-route"))
            XCTAssertNotNil(scene.childNode(withName: "//journey-scenery"))
            XCTAssertNil(progress.checkpoint)
            scene.scrollMap(to: FestivalMapLayout.focusedOffset(local: area * 20 - 1))
            scene.scrollMap(to: FestivalMapLayout.focusedOffset(local: area * 20))
            XCTAssertTrue(FestivalQuest.all.allSatisfy { !progress.adventure.accepted($0) })
            scene.handleMenu(["level-\(area * 20)"]); scene.handleMenu(["briefing-play"])
            XCTAssertNil(scene.childNode(withName: "//courtyard-welcome-explore"))
            XCTAssertEqual(progress.checkpoint?.level, area * 20)
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
