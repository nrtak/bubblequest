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
    func testStartMenuHasOnePlayActionAndNextAreaIsMystery() throws {
        let suite = "CourtyardMenus-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        profiles.makeProgress().tutorialSeen = true
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        XCTAssertNotNil(scene.childNode(withName: "//start-continue"))
        XCTAssertNil(scene.childNode(withName: "//start-adventure"))
        scene.handleMenu(["start-continue"])
        XCTAssertNotNil(scene.childNode(withName: "//courtyard-resident"))
        XCTAssertNil(scene.childNode(withName: "//continue-stop"))
        scene.handleMenu(["area-next"])
        XCTAssertNil(scene.childNode(withName: "//courtyard-resident"))
        let labels = scene.children.last!.children.compactMap { ($0 as? SKLabelNode)?.text }
        XCTAssertTrue(labels.contains("Mystery Courtyard"))
        XCTAssertNotNil(scene.childNode(withName: "//area-prev"))
        XCTAssertNil(scene.childNode(withName: "//area-next"))
        scene.handleMenu(["area-prev"])
        scene.handleMenu(["level-0"])
        scene.setActive(false)
        scene.setActive(true)
        let before = try XCTUnwrap(profiles.makeProgress().checkpoint)
        XCTAssertNotNil(before.layoutSeed)
        scene.handleMenu(["home"])
        scene.handleMenu(["start-continue"])
        scene.setActive(false)
        scene.setActive(true)
        let after = try XCTUnwrap(profiles.makeProgress().checkpoint)
        XCTAssertEqual(after.layoutSeed, before.layoutSeed)
        XCTAssertEqual(after.board?.bubbles, before.board?.bubbles)
        XCTAssertEqual(after.shots, before.shots)
    }
    @MainActor
    func testMapSectionsAndToolbarIconsDoNotOverlap() throws {
        let suite = "MapSpacing-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.recordVictory(index: 19, score: 100, stars: 1)
        progress.markCourtyardWelcomed(1)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-adventure"])
        // On a compact screen a 44-point button needs padding beyond its artwork.
        // Its background panel must not swallow taps in that padding.
        view.frame = CGRect(x: 0, y: 0, width: 320, height: 568)
        XCTAssertTrue(scene.interactionNames(at: CGPoint(x: 99, y: 735)).contains("area-prev"))
        XCTAssertTrue(scene.interactionNames(at: CGPoint(x: 78, y: 194)).contains("friends"))
        let header = try XCTUnwrap(scene.childNode(withName: "//map-area-header") as? SKShapeNode)
        let resident = try XCTUnwrap(scene.childNode(withName: "//courtyard-resident") as? SKShapeNode)
        let activities = try XCTUnwrap(scene.childNode(withName: "//map-activities") as? SKShapeNode)
        XCTAssertGreaterThan(header.frame.minY, FestivalMapLayout.viewport.maxY + 10)
        XCTAssertLessThan(resident.frame.maxY + 30, FestivalMapLayout.viewport.minY)
        XCTAssertLessThan(activities.frame.maxY + 12, resident.frame.minY)
        for name in ["area-prev", "area-next"] {
            let button = try XCTUnwrap(scene.childNode(withName: "//" + name) as? SKShapeNode)
            XCTAssertTrue(header.frame.contains(button.frame))
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(button.path).boundingBox.height, 44)
        }
        for name in ["friends", "album-open", "open-wheel"] {
            let button = try XCTUnwrap(activities.childNode(withName: name) as? SKShapeNode)
            let icon = try XCTUnwrap(button.childNode(withName: "map-activity-icon"))
            XCTAssertTrue(try XCTUnwrap(button.path).boundingBox.contains(icon.frame))
            XCTAssertTrue(try XCTUnwrap(activities.path).boundingBox.contains(button.frame))
        }
        let route = try XCTUnwrap(scene.childNode(withName: "//map-route"))
        for stop in route.children where stop.name == "locked" || stop.name?.hasPrefix("level-") == true {
            if !stop.isHidden {
                let y = stop.position.y + route.position.y
                XCTAssertGreaterThanOrEqual(y - 32, FestivalMapLayout.viewport.minY)
                XCTAssertLessThanOrEqual(y + 32, FestivalMapLayout.viewport.maxY)
            }
        }
        let first = try XCTUnwrap(scene.childNode(withName: "//level-20") as? SKShapeNode)
        XCTAssertFalse(first.isHidden)
        XCTAssertGreaterThan(first.position.y + route.position.y - 28, FestivalMapLayout.viewport.minY)
        let home = try XCTUnwrap(scene.childNode(withName: "//home") as? SKShapeNode)
        XCTAssertLessThan(home.frame.maxY + 20, activities.frame.minY)
    }

}
