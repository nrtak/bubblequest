import XCTest
import SpriteKit
@testable import BubbleQuest

final class LevelLivesTests: XCTestCase {
    private let start = Date(timeIntervalSince1970: 1_000_000)

    func testFiveAttemptsThenOneRefillEveryFiveMinutes() {
        var state = LevelLives()
        for remaining in stride(from: 4, through: 0, by: -1) {
            XCTAssertTrue(state.consume(at: start))
            XCTAssertEqual(state.available, remaining)
        }
        XCTAssertFalse(state.consume(at: start))
        state.refresh(at: start.addingTimeInterval(299))
        XCTAssertEqual(state.available, 0)
        XCTAssertEqual(state.countdown(at: start.addingTimeInterval(299)), "0:01")
        state.refresh(at: start.addingTimeInterval(300))
        XCTAssertEqual(state.available, 1)
        XCTAssertEqual(state.secondsUntilRefill(at: start.addingTimeInterval(300)), 300)
        state.refresh(at: start.addingTimeInterval(900))
        XCTAssertEqual(state.available, 3)
        state.refresh(at: start.addingTimeInterval(10_000))
        XCTAssertEqual(state.available, 5)
        XCTAssertNil(state.nextRefill)
    }

    func testUsingARefilledTryKeepsTheExistingNextRefillTime() {
        var state = LevelLives()
        for _ in 0..<5 { XCTAssertTrue(state.consume(at: start)) }
        XCTAssertTrue(state.consume(at: start.addingTimeInterval(301)))
        XCTAssertEqual(state.available, 0)
        XCTAssertEqual(state.secondsUntilRefill(at: start.addingTimeInterval(301)), 299)
        state.refresh(at: start.addingTimeInterval(600))
        XCTAssertEqual(state.available, 1)
    }

    func testClockMovingBackwardDoesNotCreateAnExcessiveWait() {
        var state = LevelLives()
        for _ in 0..<5 { XCTAssertTrue(state.consume(at: start)) }
        let earlier = start.addingTimeInterval(-3600)
        state.refresh(at: earlier)
        XCTAssertEqual(state.available, 0)
        XCTAssertEqual(state.secondsUntilRefill(at: earlier), 300)
        state.refresh(at: earlier.addingTimeInterval(300))
        XCTAssertEqual(state.available, 1)
    }

    func testLivesPersistPerLevelPerPlayerAndIntoNamedBackup() throws {
        let suite = "LivesProfiles-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        defer {
            for player in profiles.players where player.id != "original" {
                UserDefaults(suiteName: "\(suite).\(player.id)")?.removePersistentDomain(forName: "\(suite).\(player.id)")
            }
            defaults.removePersistentDomain(forName: suite)
            try? FileManager.default.removeItem(at: directory)
        }
        let progress = profiles.makeProgress()
        for _ in 0..<5 { XCTAssertTrue(progress.takeTry(for: 0, now: start)) }
        XCTAssertFalse(progress.takeTry(for: 0, now: start))
        XCTAssertFalse(progress.takeTry(for: -1, now: start))
        XCTAssertEqual(GameProgress(defaults: defaults).lives(for: 0, now: start).available, 0)
        XCTAssertEqual(progress.lives(for: 1, now: start).available, 5)
        XCTAssertEqual(progress.lives(for: 0, challenge: true, now: start).available, 5)
        XCTAssertTrue(profiles.persistActive())
        let file = directory.appendingPathComponent(profiles.active.fileName)
        let saved = try XCTUnwrap(PropertyListSerialization.propertyList(from: Data(contentsOf: file), format: nil) as? [String: Any])
        XCTAssertNotNil(saved["levelLives-0"])
        XCTAssertNotNil(profiles.create(name: "Guest"))
        XCTAssertEqual(profiles.makeProgress().lives(for: 0, now: start).available, 5)
    }

    @MainActor
    func testEmptyLevelShowsTimerAndStillAllowsReturningToMap() throws {
        let suite = "LivesGate-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        for _ in 0..<5 { XCTAssertTrue(profiles.makeProgress().takeTry(for: 0)) }
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["level-0"]); scene.handleMenu(["briefing-play"])
        XCTAssertNotNil(scene.childNode(withName: "//lives-countdown"))
        XCTAssertTrue(try XCTUnwrap(scene.childNode(withName: "//lives-play")).isHidden)
        XCTAssertEqual(profiles.makeProgress().attempts(0), 0)
        scene.handleMenu(["lives-map"])
        XCTAssertNotNil(scene.childNode(withName: "//map-route"))
    }

    @MainActor
    func testPaidCheckpointCanResumeWithNoTriesWithoutBeingChargedAgain() throws {
        let suite = "LivesResume-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true; progress.practiceDone = true
        for _ in 0..<5 { XCTAssertTrue(progress.takeTry(for: 0)) }
        let level = LevelCatalog.level(0)
        progress.save(GameCheckpoint(level: 0, board: level.board, shots: level.shots - 1, score: 0,
                                     current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay(), shotsFired: 1))
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
        XCTAssertNil(scene.childNode(withName: "//lives-countdown"))
        scene.launchShot(angle: 0); scene.setActive(false)
        XCTAssertEqual(profiles.makeProgress().lives(for: 0).available, 0)
        XCTAssertEqual(profiles.makeProgress().attempts(0), 0)
        XCTAssertNil(scene.childNode(withName: "//lives-countdown"))
    }
    @MainActor
    func testBlockedSelectionDoesNotOverwriteAnAlreadyPaidPuzzle() throws {
        let suite = "LivesSelection-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true; progress.practiceDone = true
        progress.recordVictory(index: 0, score: 100, stars: 1)
        let first = LevelCatalog.level(0)
        progress.save(GameCheckpoint(level: 0, board: first.board, shots: first.shots - 1, score: 0,
                                     current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay(), shotsFired: 1))
        for _ in 0..<5 {
            XCTAssertTrue(progress.takeTry(for: 1))
            XCTAssertTrue(progress.takeTry(for: 0, challenge: true))
        }
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
        scene.handleMenu(["level-1"]); scene.handleMenu(["briefing-play"])
        XCTAssertEqual(profiles.makeProgress().checkpoint?.level, 0)
        XCTAssertEqual(profiles.makeProgress().checkpoint?.shotsFired, 1)
        scene.handleMenu(["challenge-play"]); scene.handleMenu(["briefing-play"])
        XCTAssertEqual(profiles.makeProgress().checkpoint?.challenge, false)
        XCTAssertEqual(profiles.makeProgress().checkpoint?.level, 0)
    }

    func testTryStateSurvivesLegacyCheckpointConversionAndRejectsContradictions() throws {
        let level = LevelCatalog.level(0)
        let fresh = GameCheckpoint(level: 0, board: level.board, shots: level.shots, score: 0,
                                   current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay())
        XCTAssertFalse(fresh.hasStartedTry)
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(fresh)) as? [String: Any])
        old.removeValue(forKey: "tryStarted")
        old.removeValue(forKey: "shotsFired")
        let legacy = try JSONDecoder().decode(GameCheckpoint.self, from: JSONSerialization.data(withJSONObject: old))
        XCTAssertTrue(legacy.hasStartedTry)
        XCTAssertNotNil(legacy.board)
        let converted = GameCheckpoint(level: 0, board: level.board, shots: level.shots, score: 0,
                                       current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay(),
                                       shotsFired: 0, tryStarted: legacy.hasStartedTry)
        XCTAssertTrue(try JSONDecoder().decode(GameCheckpoint.self, from: JSONEncoder().encode(converted)).hasStartedTry)
        let contradictory = GameCheckpoint(level: 0, board: level.board, shots: level.shots - 1, score: 0,
                                           current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay(),
                                           shotsFired: 1, tryStarted: false)
        XCTAssertNil(contradictory.board)
    }

    @MainActor
    func testLegacyPuzzleCanBeSavedAndResumedTwiceWithoutUsingATry() throws {
        let suite = "LegacyTryResume-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true; progress.practiceDone = true
        for _ in 0..<5 { XCTAssertTrue(progress.takeTry(for: 0)) }
        let level = LevelCatalog.level(0)
        let checkpoint = GameCheckpoint(level: 0, board: level.board, shots: level.shots - 1, score: 0,
                                        current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay())
        var old = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(checkpoint)) as? [String: Any])
        old.removeValue(forKey: "tryStarted"); old.removeValue(forKey: "shotsFired")
        defaults.set(try JSONSerialization.data(withJSONObject: old), forKey: "unfinishedPuzzle")
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        for _ in 0..<2 {
            scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
            scene.setActive(false); scene.setActive(true)
            XCTAssertNil(scene.childNode(withName: "//lives-countdown"))
            XCTAssertEqual(profiles.makeProgress().checkpoint?.tryStarted, true)
            XCTAssertEqual(profiles.makeProgress().lives(for: 0).available, 0)
        }
    }

}
