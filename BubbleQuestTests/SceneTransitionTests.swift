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
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene)
        defer { view.presentScene(nil) }
        scene.handleMenu(["continue-stop"]); scene.handleMenu(["briefing-play"])
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
            scene.handleMenu(["continue-stop"]); scene.handleMenu(["briefing-play"])
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
            XCTAssertNotNil(scene.childNode(withName: "//level-briefing-card"))
            XCTAssertNil(profiles.makeProgress().checkpoint, "Creating a name does not start an attempt before Play")
            scene.handleMenu(["briefing-play"])
            XCTAssertEqual(profiles.makeProgress().checkpoint?.shotsFired, 0)
            scene.handleMenu(["home"])
            scene.handleMenu(["players"])
            scene.handleMenu(["player-original"]); scene.handleMenu(["briefing-play"])
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
                XCTAssertNil(overlay.childNode(withName: "neighbors"))
                scene.handleMenu(["area-next"])
            }
        }
    }
    @MainActor
    func testChallengeVictoryDoesNotChangeCampaignOrSideQuestProgress() throws {
        try withScene { scene, profiles in
            let progress = profiles.makeProgress()
            for index in 0..<20 { progress.recordVictory(index: index, score: 100, stars: 1) }
            let quest = FestivalQuest.all[0]
            progress.adventure.accept(quest, unlockedLevel: progress.unlockedLevel)
            let board = BubbleBoard(bubbles: [Cell(row: 0, column: 3): 0, Cell(row: 0, column: 4): 0])
            // Go through the same restore route as reopening an unfinished challenge.
            scene.handleMenu(["home"])
            progress.save(GameCheckpoint(level: 0, board: board, shots: 20, score: 0, current: 0, next: 0,
                                         bag: [0], rainbow: 0, bomb: 0, play: QuestPlay(collected: [quest.id]), challenge: true))
            scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
            scene.launchShot(angle: 0)
            scene.setActive(false); scene.setActive(true)
            let restored = profiles.makeProgress()
            XCTAssertTrue(restored.challengeWon(0))
            XCTAssertEqual(restored.stars(0), 1)
            XCTAssertEqual(restored.bestScore(0), 100)
            XCTAssertEqual(restored.adventure.count(quest), 0)
            XCTAssertEqual(restored.completedCount, 20)
        }
    }

    @MainActor
    func testNestedMapControlsKeepCompactTouchTargets() throws {
        try withScene { scene, profiles in
            for index in 0..<6 { profiles.makeProgress().recordVictory(index: index, score: 100, stars: 1) }
            scene.handleMenu(["start-adventure"])
            // A 320pt display scales the 844pt scene to about 67 percent.
            let compact = try XCTUnwrap(scene.view)
            compact.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
            for name in ["quest-parcels", "map-extras"] {
                let control = try XCTUnwrap(scene.childNode(withName: "//" + name))
                let edge = control.convert(CGPoint(x: 0, y: 27), to: scene)
                XCTAssertTrue(scene.interactionNames(at: edge).contains(name), "Expanded nested target: \(name)")
            }
            scene.handleMenu(["map-extras"])
            for name in ["friends", "album-open"] {
                let control = try XCTUnwrap(scene.childNode(withName: "//" + name))
                let edge = control.convert(CGPoint(x: 0, y: -27), to: scene)
                XCTAssertTrue(scene.interactionNames(at: edge).contains(name))
            }
            scene.handleMenu(["friends"])
            let hiddenMapLevel = try XCTUnwrap(scene.childNode(withName: "//level-6"))
            let point = hiddenMapLevel.convert(CGPoint.zero, to: scene)
            XCTAssertFalse(FestivalMenuTargets.buddies(scene.interactionNames(at: point)).contains("level-6"))
        }
    }

    @MainActor
    func testPrizeWheelSupplyTextDoesNotOverlapSpinButton() throws {
        try withScene { scene, _ in
            scene.handleMenu(["start-adventure"])
            scene.handleMenu(["open-wheel"])
            let spin = try XCTUnwrap(scene.childNode(withName: "//wheel-spin"))
            let overlay = try XCTUnwrap(spin.parent)
            let supply = try XCTUnwrap(overlay.children.compactMap { $0 as? SKLabelNode }.first { $0.text?.hasPrefix("Saved boosters:") == true })
            XCTAssertGreaterThan(supply.frame.minY - spin.calculateAccumulatedFrame().maxY, 8)
        }
    }

    @MainActor
    func testForegroundingRefreshesMotionAfterSettingsChange() throws {
        try withScene { scene, _ in
            let human = try XCTUnwrap(scene.childNode(withName: "//companion-1"))
            scene.setActive(false)
            scene.updateCompanionMotion(quiet: true)
            XCTAssertNil(human.action(forKey: "expression"))
            scene.setActive(true)
            if UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled {
                XCTAssertNil(human.action(forKey: "expression"))
            } else {
                XCTAssertNotNil(human.action(forKey: "expression"))
            }
        }
    }

    @MainActor
    func testResumingAnInterruptedTutorialKeepsThePuzzleAndShowsInstructions() throws {
        let suite = "InterruptedTutorial-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let first = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        first.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        first.handleMenu(["continue-stop"]); first.handleMenu(["briefing-play"])
        XCTAssertNotNil(first.childNode(withName: "//tutorial-next"))
        first.setActive(false)
        let saved = try XCTUnwrap(profiles.makeProgress().checkpoint)
        let reopened = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        reopened.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        reopened.handleMenu(["start-continue"]); reopened.handleMenu(["briefing-play"])
        XCTAssertNotNil(reopened.childNode(withName: "//tutorial-next"))
        XCTAssertFalse(profiles.makeProgress().tutorialSeen)
        XCTAssertEqual(profiles.makeProgress().checkpoint?.layoutSeed, saved.layoutSeed)
        XCTAssertEqual(profiles.makeProgress().checkpoint?.board?.bubbles, saved.board?.bubbles)
        XCTAssertEqual(profiles.makeProgress().checkpoint?.shots, saved.shots)
    }

    @MainActor
    func testResumeExplainsAnUnlearnedSpecialAlongsideKnownBubbles() throws {
        let suite = "ResumeSpecial-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true; progress.markLearned(.lantern)
        progress.recordVictory(index: 66, score: 100, stars: 1)
        progress.markCourtyardWelcomed(66 / LevelCatalog.levelsPerArea)
        progress.save(GameCheckpoint(level: 66, board: LevelCatalog.level(66).board, shots: 20, score: 100,
                                     current: 0, next: 1, bag: [0, 1], rainbow: 1, bomb: 1, play: QuestPlay()))
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
        let ready = try XCTUnwrap(scene.childNode(withName: "//special-ready"))
        XCTAssertTrue(ready.parent!.children.compactMap { ($0 as? SKLabelNode)?.text }.contains(SpecialBubble.riverPearl.explanation))
        scene.handleMenu(["special-ready"])
        XCTAssertTrue(profiles.makeProgress().hasLearned(.riverPearl))
    }

    @MainActor
    func testQuestRewardTakesPriorityOverASimultaneousCharacterUnlock() throws {
        let suite = "QuestAndBuddy-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true
        for level in 0..<19 { progress.recordVictory(index: level, score: 100, stars: 1) }
        let quest = FestivalQuest.all[0]
        progress.adventure.accept(quest, unlockedLevel: 19)
        for level in 0..<2 { progress.adventure.recordWin(level: level, play: QuestPlay(collected: [quest.id]), completedLevels: 19) }
        let board = BubbleBoard(bubbles: [Cell(row: 0, column: 3): 0, Cell(row: 0, column: 4): 0])
        progress.save(GameCheckpoint(level: 19, board: board, shots: 20, score: 0, current: 0, next: 0,
                                     bag: [0], rainbow: 1, bomb: 1, play: QuestPlay(collected: [quest.id])))
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
        scene.launchShot(angle: 0)
        scene.setActive(false); scene.setActive(true)
        XCTAssertTrue(profiles.makeProgress().adventure.completed(quest))
        XCTAssertNotNil(profiles.makeProgress().pendingBuddy)
        scene.handleMenu(["result-next"]); scene.handleMenu(["briefing-play"])
        XCTAssertNotNil(scene.childNode(withName: "//quest-style-0"))
        XCTAssertNil(scene.childNode(withName: "//buddy-choose"))
        scene.handleMenu(["new-buddy"])
        XCTAssertNotNil(scene.childNode(withName: "//buddy-choose"))
        scene.handleMenu(["buddy-later"]); scene.handleMenu(["briefing-play"])
        XCTAssertNotNil(scene.childNode(withName: "//quest-style-0"))
        XCTAssertEqual(profiles.makeProgress().completedCount, 20)
    }

    @MainActor
    func testPuzzleMenuCanVisitMapAndResumeTheSameAttempt() throws {
        try withScene { scene, profiles in
            scene.launchShot(angle: 0)
            scene.showGameMenu()
            let saved = try XCTUnwrap(profiles.makeProgress().checkpoint)
            let mapButton = try XCTUnwrap(scene.childNode(withName: "//game-map"))
            let controls = try XCTUnwrap(mapButton.parent).children.filter { ["game-resume", "game-music", "game-map", "game-restart", "settings", "home"].contains($0.name ?? "") }
            for (index, control) in controls.enumerated() {
                for other in controls.dropFirst(index + 1) {
                    XCTAssertFalse(control.calculateAccumulatedFrame().intersects(other.calculateAccumulatedFrame()))
                }
            }
            scene.handleMenu(["game-map"])
            XCTAssertNotNil(scene.childNode(withName: "//level-0"))
            XCTAssertNil(scene.childNode(withName: "//game-resume"))
            scene.handleMenu(["level-0"]); scene.handleMenu(["briefing-play"])
            let resumed = try XCTUnwrap(profiles.makeProgress().checkpoint)
            XCTAssertEqual(resumed.layoutSeed, saved.layoutSeed)
            XCTAssertEqual(resumed.board?.bubbles, saved.board?.bubbles)
            XCTAssertEqual(resumed.shots, saved.shots)
            XCTAssertEqual(resumed.shotsFired, saved.shotsFired)
            XCTAssertEqual(resumed.pressureSeed, saved.pressureSeed)
        }
    }

    @MainActor
    func testLockedTeamChoicesExplainRequirementsWithoutChangingSelection() throws {
        try withScene { scene, profiles in
            let selected = profiles.makeProgress().selected(.human).id
            scene.handleMenu(["start-adventure"]); scene.handleMenu(["friends"])
            scene.handleMenu(["friends-page"])
            for id in ["haru", "mei"] {
                XCTAssertNotNil(scene.childNode(withName: "//friend-" + id))
                scene.handleMenu(["friend-" + id])
                XCTAssertNotNil(scene.childNode(withName: "//companion-preview-portrait"))
                XCTAssertEqual(profiles.makeProgress().selected(.human).id, selected)
                XCTAssertNotNil(scene.childNode(withName: "//preview-back"))
                scene.handleMenu(["friend-guide"])
                XCTAssertNotNil(scene.childNode(withName: "//preview-back"), "Background team taps must not dismiss a preview")
                scene.handleMenu(["preview-back"])
                XCTAssertNotNil(scene.childNode(withName: "//map-buddies-close"))
            }
        }
    }

    @MainActor
    func testChoosingUnlockedTeamMembersAcknowledgesTheirWelcome() throws {
        try withScene { scene, profiles in
            for level in 0..<20 { profiles.makeProgress().recordVictory(index: level, score: 100, stars: 1) }
            scene.handleMenu(["start-adventure"]); scene.handleMenu(["friends"])
            scene.handleMenu(["friend-white-shiba"])
            XCTAssertEqual(profiles.makeProgress().selected(.animal).id, "white-shiba")
            XCTAssertNotEqual(profiles.makeProgress().pendingBuddy?.id, "white-shiba")
            scene.handleMenu(["friends-page"])
            scene.handleMenu(["friend-haru"])
            XCTAssertEqual(profiles.makeProgress().selected(.human).id, "haru")
            XCTAssertNil(profiles.makeProgress().pendingBuddy)
        }
    }

    @MainActor
    func testCancellingBoosterHoldOrBackgroundingClearsDelayedHelp() throws {
        try withScene { scene, _ in
            let game = try XCTUnwrap(scene.childNode(withName: "//handwheel")?.parent)
            game.run(.wait(forDuration: 100), withKey: "control-help")
            scene.touchesCancelled([], with: nil)
            XCTAssertNil(game.action(forKey: "control-help"))
            game.run(.wait(forDuration: 100), withKey: "control-help")
            scene.setActive(false)
            XCTAssertNil(game.action(forKey: "control-help"))
            scene.setActive(true)
        }
    }

    @MainActor
    func testAnimalWelcomeUsesDescriptionInsteadOfHumanDialogue() throws {
        try withScene { scene, profiles in
            for level in 0..<20 { profiles.makeProgress().recordVictory(index: level, score: 100, stars: 1) }
            scene.handleMenu(["new-buddy"])
            let choose = try XCTUnwrap(scene.childNode(withName: "//buddy-choose"))
            let overlay = try XCTUnwrap(choose.parent)
            let words = overlay.children.compactMap { ($0 as? SKLabelNode)?.text }
            XCTAssertTrue(words.contains { $0.contains("buddy loads bubbles") })
            XCTAssertFalse(words.contains { $0.hasPrefix("Hi!") })
        }
    }

    @MainActor
    func testQuickMusicMuteKeepsEffectsAndTheSamePuzzle() throws {
        try withScene { scene, profiles in
            let progress = profiles.makeProgress()
            let before = try XCTUnwrap(progress.checkpoint)
            let effects = progress.enabled(.effects)
            let volume = progress.volumeStep(music: true)
            scene.showGameMenu()
            scene.handleMenu(["game-music"])
            XCTAssertFalse(progress.enabled(.music))
            XCTAssertEqual(progress.enabled(.effects), effects)
            XCTAssertEqual(progress.volumeStep(music: true), volume)
            XCTAssertEqual(progress.checkpoint?.board?.bubbles, before.board?.bubbles)
            scene.handleMenu(["game-music"])
            XCTAssertTrue(progress.enabled(.music))
            progress.changeVolume(music: true, by: -5)
            scene.showGameMenu()
            scene.handleMenu(["game-music"])
            XCTAssertGreaterThan(progress.musicVolume, 0)
            XCTAssertEqual(progress.enabled(.effects), effects)
        }
    }

}
