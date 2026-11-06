import XCTest
import SpriteKit
@testable import BubbleQuest

final class ReleaseReadinessTests: XCTestCase {
    func testActivityMenusKeepMapMusicBeforeGameplayStarts() {
        for menu in ["daily-puzzle", "festival-garden"] {
            for area in [0, 4, 7, 10] {
                for challenge in [false, true] {
                    XCTAssertEqual(FestivalAudio.track(menu: menu, area: area, challenge: challenge), "music-map")
                }
            }
        }
        XCTAssertEqual(FestivalAudio.track(menu: "game", area: 0, challenge: true), "music-challenge")
    }

    func testSoundPreferencesRemainSeparateAfterSwitchingProfilesAndReopening() throws {
        let suite = "SoundProfiles-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        defer {
            for player in profiles.players where player.id != "original" {
                defaults.removePersistentDomain(forName: "\(suite).\(player.id)")
            }
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let original = profiles.makeProgress()
        original.toggle(.music)
        original.changeVolume(music: false, by: -1)
        let effectsVolume = original.effectsVolume
        let guest = try XCTUnwrap(profiles.create(name: "Guest"))
        XCTAssertTrue(profiles.makeProgress().enabled(.music))
        profiles.makeProgress().changeVolume(music: true, by: -1)
        let guestVolume = profiles.makeProgress().musicVolume
        XCTAssertTrue(profiles.persistActive())

        let reopened = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        XCTAssertEqual(reopened.active.id, guest.id)
        XCTAssertEqual(reopened.makeProgress().musicVolume, guestVolume)
        XCTAssertTrue(reopened.select("original"))
        XCTAssertFalse(reopened.makeProgress().enabled(.music))
        XCTAssertTrue(reopened.makeProgress().enabled(.effects))
        XCTAssertEqual(reopened.makeProgress().effectsVolume, effectsVolume)
    }

    @MainActor
    func testReopeningTheSceneRestoresTheAttemptWithoutUsingAnotherTry() throws {
        try withSavedAttempt { scene, view, profiles in
            let before = try XCTUnwrap(profiles.makeProgress().checkpoint)
            scene.setActive(false)
            view.presentScene(nil)
            let reopened = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
            view.presentScene(reopened)
            reopened.handleMenu(["start-continue"])
            reopened.handleMenu(["briefing-play"])
            let after = try XCTUnwrap(profiles.makeProgress().checkpoint)
            XCTAssertEqual(after.shots, before.shots)
            XCTAssertEqual(after.shotsFired, before.shotsFired)
            XCTAssertEqual(after.timedCeilingElapsed, before.timedCeilingElapsed)
            XCTAssertEqual(after.board?.bubbles, before.board?.bubbles)
            XCTAssertEqual(profiles.makeProgress().lives(for: 0).available, 4)
        }
    }

    @MainActor
    func testLongInterruptionDoesNotAdvanceCeilingOrUseAnotherTry() throws {
        try withSavedAttempt { scene, _, profiles in
            scene.handleMenu(["start-continue"])
            scene.handleMenu(["briefing-play"])
            scene.update(100)
            scene.update(100.5)
            scene.setActive(false)
            let before = try XCTUnwrap(profiles.makeProgress().checkpoint)
            scene.update(10_000)
            scene.setActive(true)
            scene.update(20_000)
            scene.setActive(false)
            let after = try XCTUnwrap(profiles.makeProgress().checkpoint)
            XCTAssertEqual(after.timedCeilingElapsed, before.timedCeilingElapsed)
            XCTAssertEqual(after.timedCeilingDrops, before.timedCeilingDrops)
            XCTAssertEqual(after.ceilingOffset, before.ceilingOffset)
            XCTAssertEqual(after.shots, before.shots)
            XCTAssertEqual(after.board?.bubbles, before.board?.bubbles)
            XCTAssertEqual(profiles.makeProgress().lives(for: 0).available, 4)
        }
    }

    @MainActor
    private func withSavedAttempt(_ check: (FestivalScene, SKView, GameProfiles) throws -> Void) throws {
        let suite = "Readiness-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer {
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true
        progress.practiceDone = true
        XCTAssertTrue(progress.takeTry(for: 0))
        let level = LevelCatalog.level(0)
        progress.save(GameCheckpoint(level: 0, board: level.board, shots: level.shots - 1, score: 0,
                                     current: 0, next: 1, bag: [], rainbow: 1, bomb: 1,
                                     play: QuestPlay(), shotsFired: 1, pressureSeed: 7,
                                     shotBudget: level.shots, tryStarted: true,
                                     timedCeilingElapsed: 7.25, timedCeilingDrops: 0))
        XCTAssertNotNil(progress.checkpoint)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        try check(scene, view, profiles)
    }
}
