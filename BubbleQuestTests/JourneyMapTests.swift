import XCTest
import SpriteKit
import UIKit
@testable import BubbleQuest

final class JourneyMapTests: XCTestCase {
    func testCompiledWorldWindowsCoverEveryScrollableLevel() throws {
        for level in 0..<LevelCatalog.levelCount {
            let offset = FestivalMapLayout.focusedOffset(local: level)
            for segment in FestivalMapLayout.visibleSegments(offset: offset) {
                let name = try XCTUnwrap(FestivalArtwork.journeyName(for: segment))
                let image = try XCTUnwrap(UIImage(named: name))
                let pixels = try XCTUnwrap(image.cgImage)
                XCTAssertEqual(pixels.width, 780)
                XCTAssertEqual(pixels.height, segment == 0 ? 1792 : 1408)
            }
        }
    }

    func testRoadHasNoKinksOrJumpsAtPaintingBoundaries() {
        for height in stride(from: CGFloat(-256), through: 22528, by: 1) {
            let a = FestivalMapLayout.roadX(at: height - 1)
            let b = FestivalMapLayout.roadX(at: height)
            let c = FestivalMapLayout.roadX(at: height + 1)
            XCTAssertLessThan(abs(c - b), 0.27)
            XCTAssertLessThan(abs(c - 2 * b + a), 0.0015)
        }
    }

    func testBriefingKeepsTheWalkingMapMusicUntilPlayBegins() {
        XCTAssertEqual(FestivalAudio.track(menu: "level-briefing", area: 0, challenge: false), "music-map")
        XCTAssertEqual(FestivalAudio.track(menu: "level-briefing", area: 10, challenge: true), "music-map")
    }

    func testMarkersFollowPaintedStreetsInsteadOfAnIndependentRoute() {
        for level in 0..<LevelCatalog.levelCount {
            let marker = FestivalMapLayout.position(level)
            XCTAssertEqual(marker.x, FestivalMapLayout.roadX(at: marker.y), accuracy: 0.001)
        }
        XCTAssertNil(FestivalMapLayout.mapScenery(area: 0))
        XCTAssertEqual(FestivalMapLayout.mapScenery(area: 3), .river)
    }

    func testEveryLevelCanBeCenteredWithoutBreakingTheRouteAtSceneryBoundaries() {
        for level in 0..<LevelCatalog.levelCount {
            let point = FestivalMapLayout.position(level)
            let offset = FestivalMapLayout.focusedOffset(local: level)
            XCTAssertEqual(point.y + offset, 428, accuracy: 0.001)
            XCTAssertTrue((116...322).contains(point.x))
            XCTAssertLessThanOrEqual(FestivalMapLayout.visibleSegments(offset: offset).count, 5)
            if level > 0 {
                let previous = FestivalMapLayout.position(level - 1)
                XCTAssertEqual(point.y - previous.y, 96, accuracy: 0.001)
                XCTAssertLessThan(hypot(point.x - previous.x, point.y - previous.y), 125)
            }
        }
    }

    func testVisitorsKeepTheirFootingBetweenLevelsAndDoNotOverlapLevelBubbles() throws {
        var seen = Set<String>()
        for segment in 0..<39 {
            for slot in 0..<3 {
                guard let foot = FestivalMapLayout.visitorFoot(segment: segment, slot: slot) else { continue }
                XCTAssertEqual(foot, FestivalMapLayout.visitorFoot(segment: segment, slot: slot))
                let key = "\(foot.x):\(foot.y)"
                XCTAssertTrue(seen.insert(key).inserted)
                let below = FestivalMapLayout.level(at: foot.y - 48)
                for level in below...min(LevelCatalog.levelCount - 1, below + 1) {
                    let marker = FestivalMapLayout.position(level)
                    XCTAssertGreaterThan(hypot(foot.x - marker.x, foot.y + 24 - marker.y), 49.99)
                }
            }
        }
        XCTAssertGreaterThan(seen.count, 70)
    }

    @MainActor
    func testMapControlsStayClearOfVisibleMarkersVisitorsAndProjectSitesWhileScrolling() throws {
        let suite = "JourneyClearance-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.recordVictory(index: LevelCatalog.levelCount - 1, score: 100, stars: 1)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-adventure"])
        func frame(_ node: SKNode) -> CGRect {
            guard let parent = node.parent else { return .zero }
            let box = node.calculateAccumulatedFrame()
            let a = parent.convert(CGPoint(x: box.minX, y: box.minY), to: scene)
            let b = parent.convert(CGPoint(x: box.maxX, y: box.maxY), to: scene)
            return CGRect(x: a.x, y: a.y, width: b.x - a.x, height: b.y - a.y)
        }
        var checked = 0
        for level in stride(from: 0, to: LevelCatalog.levelCount, by: 3) {
            scene.scrollMap(to: FestivalMapLayout.focusedOffset(local: level) + 37)
            let reserved = ["map-current-level", "map-side-quests"].compactMap { scene.childNode(withName: "//" + $0) }.map(frame)
            scene.enumerateChildNodes(withName: "//*") { node, _ in
                guard !node.isHidden, let name = node.name,
                      name == "journey-visitor" || name == "journey-landmark" || name == "locked" || name.hasPrefix("level-") || name.hasPrefix("project-site-") else { return }
                // Menu controls use separate names; level-* here identifies route markers.
                guard name == "journey-visitor" || node.parent?.name == "map-route" else { return }
                checked += 1
                for control in reserved {
                    XCTAssertFalse(frame(node).intersects(control), "Keep \(name) clear at viewed level \(level + 1).")
                }
            }
        }
        XCTAssertGreaterThan(checked, 100)
        scene.scrollMap(to: FestivalMapLayout.focusedOffset(local: 0))
        let untouched = try XCTUnwrap(scene.childNode(withName: "//level-0"))
        XCTAssertNil(untouched.childNode(withName: "map-complete-mark"), "An unlocked but uncleared level is not completed.")
    }

    @MainActor
    func testSideQuestsStayFixedWhileSceneryScrollsAndNeverAcceptThemselves() throws {
        let suite = "JourneyInteraction-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        for index in 0..<6 { progress.recordVictory(index: index, score: 100, stars: 1) }
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-adventure"])
        let quest = try XCTUnwrap(scene.childNode(withName: "//quest-parcels"))
        let point = quest.convert(CGPoint.zero, to: scene)
        let route = try XCTUnwrap(scene.childNode(withName: "//map-route"))
        scene.scrollMap(to: route.position.y - 30)
        XCTAssertEqual(quest.convert(CGPoint.zero, to: scene), point)
        XCTAssertTrue(scene.interactionNames(at: point).contains("quest-parcels"))
        scene.handleMenu(["quest-parcels"])
        scene.handleMenu(["quest-dialogue-back"])
        XCTAssertFalse(progress.adventure.accepted(FestivalQuest.all[0]))
        XCTAssertNotNil(scene.childNode(withName: "//quest-parcels"))
        XCTAssertNil(progress.checkpoint)
    }
}
