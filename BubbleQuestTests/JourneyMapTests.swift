import XCTest
import SpriteKit
@testable import BubbleQuest

final class JourneyMapTests: XCTestCase {
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
        let point = quest.convert(.zero, to: scene)
        let route = try XCTUnwrap(scene.childNode(withName: "//map-route"))
        scene.scrollMap(to: route.position.y - 30)
        XCTAssertEqual(quest.convert(.zero, to: scene), point)
        XCTAssertTrue(scene.interactionNames(at: point).contains("quest-parcels"))
        scene.handleMenu(["quest-parcels"])
        scene.handleMenu(["quest-dialogue-back"])
        XCTAssertFalse(progress.adventure.accepted(FestivalQuest.all[0]))
        XCTAssertNotNil(scene.childNode(withName: "//quest-parcels"))
        XCTAssertNil(progress.checkpoint)
    }
}
