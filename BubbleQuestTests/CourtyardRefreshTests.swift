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
}
