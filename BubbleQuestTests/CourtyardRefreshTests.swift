import XCTest
import SpriteKit
@testable import BubbleQuest

final class CourtyardRefreshTests: XCTestCase {
    func testAnimalsAreNotPresentedAsQuestGivers() {
        for quest in FestivalQuest.all {
            let words = [quest.title, quest.invitation, quest.thanks, quest.objectiveSummary] + quest.steps +
                (0..<quest.steps.count).map { quest.conversation(step: $0) }
            XCTAssertTrue(words.allSatisfy { !$0.lowercased().contains("shiba") })
        }
        XCTAssertTrue(FestivalNeighbor.all.allSatisfy { !$0.introduction.lowercased().contains("shiba") })
    }

    func testGeneratedAttemptsAreSeededAnchoredAndStayWithinDifficultyBand() {
        for base in LevelCatalog.levels {
            for seed in 1...8 {
                let generated = base.randomized(seed: UInt64(seed))
                XCTAssertEqual(generated.initialBubbles, base.randomized(seed: UInt64(seed)).initialBubbles)
                XCTAssertEqual(generated.shots, base.shots)
                XCTAssertEqual(generated.ceilingInterval, base.ceilingInterval)
                XCTAssertEqual(generated.initialBubbles.count, base.initialBubbles.count)
                XCTAssertEqual(Set(generated.initialBubbles.values), Set(base.initialBubbles.values))
                let board = generated.board
                let anchored = board.bubbles.keys.filter { $0.row == 0 }.reduce(into: Set<Cell>()) { $0.formUnion(board.connected(from: $1, matchingColor: false)) }
                XCTAssertEqual(anchored, Set(board.bubbles.keys), "Floating bubble in level \(base.number), seed \(seed)")
                XCTAssertTrue(generated.goal.isValid(on: board))
            }
        }
    }

    func testFreshAttemptsDoNotRepeatRecentBoardsAndOldUnlocksSurvive() throws {
        let suite = "FreshCourtyard-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        for level in 0..<35 { defaults.set(1, forKey: "stars-\(level)") }
        let progress = GameProgress(defaults: defaults)
        let emi = try XCTUnwrap(Companion.all.first { $0.id == "emi" })
        XCTAssertTrue(progress.unlocked(emi), "Previously earned characters stay unlocked")
        var recent: [[Cell: Int]] = []
        for _ in 0..<20 {
            let fresh = progress.freshLayout(for: 0)
            XCTAssertFalse(recent.contains { $0 == fresh.level.initialBubbles })
            recent.append(fresh.level.initialBubbles)
        }
        let freshDefaults = UserDefaults(suiteName: suite + "-new")!
        defer { freshDefaults.removePersistentDomain(forName: suite + "-new") }
        let newPlayer = GameProgress(defaults: freshDefaults)
        for level in 0..<19 { newPlayer.recordVictory(index: level, score: 100, stars: 1) }
        XCTAssertTrue(Companion.all.filter { $0.unlockAfter > 0 }.allSatisfy { !newPlayer.unlocked($0) })
        newPlayer.recordVictory(index: 19, score: 100, stars: 1)
        XCTAssertTrue(newPlayer.unlocked(Companion.all.first { $0.id == "haru" }!))
    }

    @MainActor
    func testStartMenuOpensOneContinuousJourneyAndPreservesAnAttempt() throws {
        let suite = "JourneyMenus-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        profiles.makeProgress().tutorialSeen = true
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        XCTAssertNotNil(scene.childNode(withName: "//start-continue"))
        scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
        XCTAssertNotNil(scene.childNode(withName: "//map-route"))
        XCTAssertNil(scene.childNode(withName: "//area-next"))
        XCTAssertNil(scene.childNode(withName: "//courtyard-resident"))
        scene.handleMenu(["level-0"]); scene.handleMenu(["briefing-play"])
        let before = try XCTUnwrap(profiles.makeProgress().checkpoint)
        scene.handleMenu(["home"]); scene.handleMenu(["start-continue"]); scene.handleMenu(["briefing-play"])
        let after = try XCTUnwrap(profiles.makeProgress().checkpoint)
        XCTAssertEqual(after.layoutSeed, before.layoutSeed)
        XCTAssertEqual(after.board?.bubbles, before.board?.bubbles)
        XCTAssertEqual(after.shots, before.shots)
    }
    @MainActor
    func testJourneyKeepsFixedControlsClearOfTheScrollableLevels() throws {
        let suite = "JourneySpacing-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        profiles.makeProgress().recordVictory(index: 19, score: 100, stars: 1)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 320, height: 568))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-adventure"])
        let header = try XCTUnwrap(scene.childNode(withName: "//map-journey-header"))
        XCTAssertGreaterThan(header.frame.minY, FestivalMapLayout.viewport.maxY + 8)
        for name in ["home", "map-extras", "continue-stop"] {
            let button = try XCTUnwrap(scene.childNode(withName: "//" + name))
            XCTAssertLessThan(button.frame.maxY, FestivalMapLayout.viewport.minY - 12)
            XCTAssertTrue(scene.interactionNames(at: button.position).contains(name))
        }
        let route = try XCTUnwrap(scene.childNode(withName: "//map-route"))
        let scenery = try XCTUnwrap(route.childNode(withName: "journey-scenery"))
        XCTAssertLessThanOrEqual(scenery.children.count, 5)
        let marker = try XCTUnwrap(route.childNode(withName: "level-20"))
        let before = marker.convert(CGPoint.zero, to: scene)
        let tile = try XCTUnwrap(scenery.children.first)
        let tileBefore = tile.convert(CGPoint.zero, to: scene)
        scene.scrollMap(to: route.position.y - 20)
        XCTAssertEqual(marker.convert(CGPoint.zero, to: scene).y - before.y, -20, accuracy: 0.01)
        XCTAssertEqual(tile.convert(CGPoint.zero, to: scene).y - tileBefore.y, -20, accuracy: 0.01)
        XCTAssertEqual(header.position.y, 754)
        scene.scrollMap(to: FestivalMapLayout.focusedOffset(local: 219))
        XCTAssertLessThanOrEqual(scenery.children.count, 5)
        scene.handleMenu(["map-extras"])
        for name in ["friends", "album-open", "open-wheel", "map-objective"] {
            XCTAssertNotNil(scene.childNode(withName: "//" + name))
        }
    }

}
