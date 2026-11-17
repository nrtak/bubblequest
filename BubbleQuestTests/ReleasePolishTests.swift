import XCTest
import SpriteKit
import UIKit
@testable import BubbleQuest

final class ReleasePolishTests: XCTestCase {
    func testCoreLabelColorsHaveReadableContrast() {
        func luminance(_ color: UIColor) -> Double {
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            color.getRed(&r, green: &g, blue: &b, alpha: &a)
            func linear(_ value: CGFloat) -> Double {
                let v = Double(value)
                return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
            }
            return 0.2126 * linear(r) + 0.7152 * linear(g) + 0.0722 * linear(b)
        }
        for (text, background) in [(UIColor.white, FestivalStyle.actionCoral), (.white, FestivalStyle.teal), (FestivalStyle.ink, FestivalStyle.brass)] {
            let values = [luminance(text), luminance(background)].sorted()
            XCTAssertGreaterThanOrEqual((values[1] + 0.05) / (values[0] + 0.05), 4.5)
        }
    }

    func testRoamingCharactersKeepTheirFeetOnTheRoadAndBodiesClearOfLevelNumbers() {
        var checked = 0
        for segment in 0..<39 {
            for slot in 0..<3 {
                guard let foot = FestivalMapLayout.visitorFoot(segment: segment, slot: slot) else { continue }
                XCTAssertLessThanOrEqual(abs(foot.x - FestivalMapLayout.roadX(at: foot.y)) + 16, 70.001)
                let lower = FestivalMapLayout.level(at: foot.y - 24)
                for level in lower...min(LevelCatalog.levelCount - 1, lower + 1) {
                    XCTAssertGreaterThanOrEqual(FestivalMapLayout.visitorClearance(at: foot, from: FestivalMapLayout.position(level)), 29)
                }
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 70)
    }

    @MainActor
    func testPaintedProjectsHaveFiveStatesAndKeepTheirFootingAndAspectRatio() throws {
        let styles: [FestivalProject.DisplayStyle] = [.stall, .pinwheels, .lanternWalk, .picnic, .fireworks, .kites]
        XCTAssertEqual(FestivalProjectArtwork.imageNames.count, styles.count)
        for name in FestivalProjectArtwork.imageNames { XCTAssertNotNil(UIImage(named: name)) }
        for style in styles {
            for stage in 0...4 {
                let node = try XCTUnwrap(FestivalProjectArtwork.node(style: style, stage: stage, fitting: CGSize(width: 176, height: 132)))
                let texture = try XCTUnwrap(node.texture)
                XCTAssertLessThanOrEqual(node.size.width, 176.001)
                XCTAssertLessThanOrEqual(node.size.height, 132.001)
                XCTAssertEqual(node.frame.minY, 0, accuracy: 0.001, "Keep feet on the same surface")
                XCTAssertEqual(node.size.width / node.size.height, texture.size().width / texture.size().height, accuracy: 0.001)
            }
        }
    }

    func testOpeningCourseEndsInTheFestivalAndKeepsLaterLevelsAndOldAttemptsSeparate() throws {
        XCTAssertEqual(OpeningFestival.lessons.count, 20)
        XCTAssertEqual(Set(OpeningFestival.lessons.map(\.title)).count, 20)
        XCTAssertTrue(OpeningFestival.lessons.allSatisfy { $0.title.count <= 26 && $0.cue.count < 75 })
        XCTAssertNil(OpeningFestival.lesson(for: 20))
        XCTAssertEqual(LevelCatalog.level(19).shots, FestivalEvent.market.shotBudget)
        XCTAssertEqual(OpeningFestival.shots(for: 20, proposed: 25), 25)
        // A version-seven attempt continues with its own board, budget and remaining shots.
        let level = LevelCatalog.level(0)
        let old = GameCheckpoint(level: 0, board: level.board, shots: 21, score: 0, current: 0, next: 1,
                                 bag: [], rainbow: 1, bomb: 1, play: QuestPlay(), balanceVersion: 7, shotBudget: 25)
        let restored = try JSONDecoder().decode(GameCheckpoint.self, from: JSONEncoder().encode(old))
        XCTAssertNotNil(restored.board)
        XCTAssertEqual(restored.shots, 21)
        XCTAssertEqual(restored.shotBudget, 25)
        XCTAssertEqual(restored.balanceVersion, 7)
    }

    @MainActor
    func testMainMenuHasOnePlaySurfaceAndCenteredNavigationLabelsAcrossPhoneSizes() throws {
        for size in [CGSize(width: 375, height: 667), CGSize(width: 390, height: 844), CGSize(width: 430, height: 932)] {
            let suite = "ReleasePolish-\(UUID().uuidString)"
            let defaults = UserDefaults(suiteName: suite)!
            let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
            defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
            let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
            let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
            let view = SKView(frame: CGRect(origin: .zero, size: size)); view.presentScene(scene)
            defer { view.presentScene(nil) }
            let play = try XCTUnwrap(scene.childNode(withName: "//start-continue") as? SKShapeNode)
            XCTAssertEqual(play.fillColor.cgColor.alpha, 0, "The play target must not add a second visible box")
            XCTAssertTrue(scene.interactionNames(at: CGPoint(x: 195, y: 410)).contains("start-continue"))
            XCTAssertTrue(scene.isMenuControl(["start-continue"]))
            XCTAssertFalse(scene.isMenuControl(["title-illustration"]))
            let account = try XCTUnwrap(scene.childNode(withName: "//players"))
            let text = try XCTUnwrap(account.children.compactMap { $0 as? SKLabelNode }.first)
            XCTAssertEqual(text.verticalAlignmentMode, .center)
            XCTAssertEqual(text.position.y, 0)
            XCTAssertLessThan(account.calculateAccumulatedFrame().maxY, play.calculateAccumulatedFrame().minY - 20)
            XCTAssertNil(scene.childNode(withName: "//start-menu-heading"))
        }
    }
    @MainActor
    func testOpeningAndNewMechanicBriefingsKeepInstructionsBetweenHeadingAndBudget() throws {
        let suite = "ReleaseBriefings-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true; progress.practiceDone = true
        progress.recordVictory(index: 219, score: 100, stars: 1)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-adventure"])
        for index in Array(0..<20) + [29, 39, 43, 48, 59, 86, 88, 99, 159, 219] {
            scene.handleMenu(["level-\(index)"])
            let heading = try XCTUnwrap(scene.childNode(withName: "//briefing-mission-heading"))
            let summary = try XCTUnwrap(scene.childNode(withName: "//briefing-objective-summary"))
            let budget = try XCTUnwrap(scene.childNode(withName: "//briefing-shot-budget"))
            XCTAssertGreaterThanOrEqual((summary as? SKLabelNode)?.fontSize ?? 0, 14)
            XCTAssertFalse(scene.isMenuControl(["briefing-objective-summary", "level-briefing-card"]), "Instruction text is not a button")
            XCTAssertTrue(scene.isMenuControl(["briefing-play"]))
            if !LevelCatalog.level(index).board.armor.isEmpty && FestivalEvent.forLevel(index) == nil {
                XCTAssertTrue((summary as? SKLabelNode)?.text?.contains("Ice rings need two matches.") == true)
            }
            if !LevelCatalog.level(index).board.blockers.isEmpty && FestivalEvent.forLevel(index) == nil {
                XCTAssertTrue((summary as? SKLabelNode)?.text?.contains("Drop or bomb wooden blocks.") == true)
            }
            XCTAssertLessThan(summary.calculateAccumulatedFrame().maxY, heading.calculateAccumulatedFrame().minY - 8, "Level \(index + 1): keep instructions below the heading")
            XCTAssertGreaterThan(summary.calculateAccumulatedFrame().minY, budget.calculateAccumulatedFrame().maxY + 8, "Level \(index + 1): keep instructions above the budget")
            XCTAssertNil(scene.childNode(withName: "//flying-bubble"))
            scene.handleMenu(["briefing-back"])
        }
    }

    @MainActor
    func testMixedSpecialsAreAllExplainedBeforePlayAndBackDoesNotAcknowledgeThem() throws {
        let suite = "MixedSpecialBriefing-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.tutorialSeen = true; progress.practiceDone = true
        progress.recordVictory(index: 219, score: 100, stars: 1)
        let kinds: [SpecialBubble] = [.lantern, .riverPearl, .blossomSpark]
        let index = try XCTUnwrap((80..<99).first { Set(LevelCatalog.level($0).board.specials.values).count == 3 })
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-adventure"]); scene.handleMenu(["level-\(index)"])
        let summary = try XCTUnwrap(scene.childNode(withName: "//briefing-objective-summary") as? SKLabelNode)
        for kind in kinds {
            XCTAssertTrue(summary.text?.contains(kind.compactPreviewHint) == true)
            XCTAssertFalse(progress.hasLearned(kind))
        }
        XCTAssertTrue(summary.text?.contains("Ice rings need two matches.") == true)
        XCTAssertFalse(progress.hasLearnedObstacle("armor"))
        scene.handleMenu(["briefing-back"])
        XCTAssertFalse(progress.hasLearnedObstacle("armor"))
        XCTAssertTrue(kinds.allSatisfy { !progress.hasLearned($0) })
        scene.handleMenu(["level-\(index)"]); scene.handleMenu(["briefing-play"])
        XCTAssertTrue(kinds.allSatisfy { progress.hasLearned($0) })
        XCTAssertTrue(progress.hasLearnedObstacle("armor"))
        XCTAssertNil(scene.childNode(withName: "//special-ready"), "Play opens the puzzle, without a second lesson")
        XCTAssertNil(scene.childNode(withName: "//flying-bubble"))
        XCTAssertEqual(progress.checkpoint?.shotsFired, 0)
    }

}
