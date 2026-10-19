import XCTest
import SpriteKit
@testable import BubbleQuest

final class FeedbackPresentationTests: XCTestCase {
    @MainActor
    private func withTargetPuzzle(targets: Set<Cell>, level: Int = 17, cleared: Int = 17, challenge: Bool = false, shots: Int = 20, color: Int = 0, check: (FestivalScene, GameProfiles) throws -> Void) throws {
        let suite = "Feedback-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true; progress.practiceDone = true
        for index in 0..<cleared { progress.recordVictory(index: index, score: 100, stars: 1) }
        let board = BubbleBoard(bubbles: [Cell(row: 0, column: 3): 0, Cell(row: 0, column: 4): 0, Cell(row: 0, column: 7): 1])
        progress.save(GameCheckpoint(level: level, board: board, shots: shots, score: 0, current: color, next: 1,
                                     bag: [1], rainbow: 1, bomb: 1, play: QuestPlay(), challenge: challenge, goal: PuzzleGoal(kind: .ceiling, targets: targets)))
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-continue"])
        try check(scene, profiles)
    }

    @MainActor
    func testRescueFeedbackAndSavedCounterAgreeWithoutWinningEarly() throws {
        try withTargetPuzzle(targets: [Cell(row: 0, column: 3), Cell(row: 0, column: 7)]) { scene, profiles in
            scene.launchShot(angle: 0)
            scene.setActive(false)
            let saved = try XCTUnwrap(profiles.makeProgress().checkpoint)
            XCTAssertEqual(saved.goal?.remaining, [Cell(row: 0, column: 7)])
            XCTAssertEqual(saved.shots, 19)
            XCTAssertNil(scene.childNode(withName: "//result"))
            let banner = try XCTUnwrap(scene.childNode(withName: "//target-feedback"))
            XCTAssertTrue(banner.children.contains { ($0 as? SKLabelNode)?.text == "Target reached! 1/2" })
            scene.setActive(true)
            scene.showGameMenu()
            XCTAssertNil(scene.childNode(withName: "//target-feedback"))
        }
    }

    @MainActor
    func testCelebrationCreditsVictoryOnceAndClearlyAdvancesToTheNextLevel() throws {
        try withTargetPuzzle(targets: [Cell(row: 0, column: 3)]) { scene, profiles in
            scene.launchShot(angle: 0)
            scene.setActive(false)
            let progress = profiles.makeProgress()
            XCTAssertEqual(progress.levelResults(17).wins, 1)
            XCTAssertNil(progress.checkpoint)
            XCTAssertNotNil(scene.childNode(withName: "//result-earned"))
            let next = try XCTUnwrap(scene.childNode(withName: "//result-next"))
            XCTAssertTrue(next.children.contains { ($0 as? SKLabelNode)?.text == "Next • Level 19" })
            for index in 0..<5 { XCTAssertNotNil(scene.childNode(withName: "//result-star-\(index)")) }
            let rating = try XCTUnwrap(scene.childNode(withName: "//result-star-rating") as? SKLabelNode)
            XCTAssertEqual(rating.text, "5 out of 5 stars")
            let objective = try XCTUnwrap(scene.childNode(withName: "//result-objective-summary") as? SKLabelNode)
            XCTAssertTrue(objective.text?.contains("other bubble didn't need clearing") == true)
            scene.setActive(true)
            scene.handleMenu(["result-next"])
            scene.handleMenu(["result-next"])
            XCTAssertEqual(profiles.makeProgress().levelResults(17).wins, 1)
            XCTAssertEqual(profiles.makeProgress().checkpoint?.level, 18)
            XCTAssertNil(scene.childNode(withName: "//result"))
        }
    }
    @MainActor
    func testBuddyWelcomeAfterAChallengeReturnsToTheMap() throws {
        try withTargetPuzzle(targets: [Cell(row: 0, column: 3)], level: 0, cleared: 20, challenge: true) { scene, profiles in
            let buddy = try XCTUnwrap(profiles.makeProgress().pendingBuddy)
            scene.launchShot(angle: 0); scene.setActive(false); scene.setActive(true)
            let button = try XCTUnwrap(scene.childNode(withName: "//result-next"))
            XCTAssertTrue(button.children.contains { ($0 as? SKLabelNode)?.text == "Meet " + buddy.name })
            scene.continueAfterResult()
            XCTAssertNotNil(scene.childNode(withName: "//buddy-later"))
            scene.handleMenu(["buddy-later"])
            XCTAssertNotNil(scene.childNode(withName: "//map-route"))
            XCTAssertNotEqual(profiles.makeProgress().pendingBuddy?.id, buddy.id)
        }
    }

    @MainActor
    func testFailureRetriesWithoutInterruptingForAnOlderBuddyUnlock() throws {
        try withTargetPuzzle(targets: [Cell(row: 0, column: 3)], level: 0, cleared: 20, shots: 1, color: 1) { scene, profiles in
            let pending = profiles.makeProgress().pendingBuddy?.id
            scene.launchShot(angle: 0); scene.setActive(false); scene.setActive(true)
            scene.continueAfterResult()
            XCTAssertNil(scene.childNode(withName: "//buddy-choose"))
            XCTAssertEqual(profiles.makeProgress().checkpoint?.level, 0)
            XCTAssertEqual(profiles.makeProgress().pendingBuddy?.id, pending)
        }
    }

    @MainActor
    func testOnlyTheFirstBubbleOfAnAttemptUsesATry() throws {
        try withTargetPuzzle(targets: [Cell(row: 0, column: 7)]) { scene, profiles in
            XCTAssertEqual(profiles.makeProgress().lives(for: 17).available, 5)
            scene.launchShot(angle: 0); scene.setActive(false)
            XCTAssertEqual(profiles.makeProgress().lives(for: 17).available, 4)
            XCTAssertEqual(profiles.makeProgress().attempts(17), 1)
            scene.setActive(true)
            scene.handleMenu(["start-continue"])
            scene.launchShot(angle: 0); scene.setActive(false)
            XCTAssertEqual(profiles.makeProgress().checkpoint?.shotsFired, 2)
            XCTAssertEqual(profiles.makeProgress().lives(for: 17).available, 4)
            XCTAssertEqual(profiles.makeProgress().attempts(17), 1)
        }
    }

    @MainActor
    func testObjectiveAndTriesCoachIsNonBlockingAndOnlyShownUntilLearned() throws {
        try withTargetPuzzle(targets: [Cell(row: 0, column: 7)]) { scene, profiles in
            XCTAssertNotNil(scene.childNode(withName: "//puzzle-coach"))
            scene.launchShot(angle: 0); scene.setActive(false)
            XCTAssertTrue(profiles.makeProgress().hasSeenObjective(.ceiling))
            XCTAssertTrue(profiles.makeProgress().hasSeenTriesHelp)
            XCTAssertEqual(profiles.makeProgress().checkpoint?.shotsFired, 1)
            scene.setActive(true); scene.handleMenu(["start-continue"])
            XCTAssertNil(scene.childNode(withName: "//puzzle-coach"))
        }
    }

    @MainActor
    func testMapPreviewsOnlyUnlockedObjectiveLevels() throws {
        try withTargetPuzzle(targets: [Cell(row: 0, column: 7)]) { scene, _ in
            scene.handleMenu(["start-adventure"])
            XCTAssertNotNil(scene.childNode(withName: "//map-objective-6"))
            XCTAssertNil(scene.childNode(withName: "//map-objective-0"))
            XCTAssertNil(scene.childNode(withName: "//map-objective-19"))
        }
    }

    @MainActor
    func testCourtyardVictoryHighlightsNewKeepsakeAndAreaWithoutReawardingReplays() throws {
        for cleared in [19, 20] {
            try withTargetPuzzle(targets: [Cell(row: 0, column: 3)], level: 19, cleared: cleared) { scene, profiles in
                scene.launchShot(angle: 0); scene.setActive(false)
                XCTAssertTrue(profiles.makeProgress().hasSouvenir(area: 0))
                var words: [String] = []
                scene.enumerateChildNodes(withName: "//*") { node, _ in
                    if let text = (node as? SKLabelNode)?.text { words.append(text) }
                }
                XCTAssertEqual(words.contains("Courtyard keepsake earned!"), cleared == 19)
                XCTAssertEqual(words.contains("Discovered: " + LevelCatalog.areas[1].name), cleared == 19)
            }
        }
    }

    @MainActor
    func testAnObstacleLessonHiddenByTheCoachIsNotPrematurelyLearned() throws {
        try withTargetPuzzle(targets: [Cell(row: 0, column: 7)], level: 15) { scene, profiles in
            XCTAssertNotNil(scene.childNode(withName: "//puzzle-coach"))
            XCTAssertFalse(profiles.makeProgress().hasLearnedObstacle("precision"))
            scene.launchShot(angle: 0); scene.setActive(false)
            XCTAssertNotNil(scene.childNode(withName: "//control-tip"))
            XCTAssertFalse(profiles.makeProgress().hasLearnedObstacle("precision"))
            scene.setActive(true); scene.handleMenu(["start-continue"])
            scene.launchShot(angle: 0); scene.setActive(false)
            XCTAssertTrue(profiles.makeProgress().hasLearnedObstacle("precision"))
        }
    }

}
