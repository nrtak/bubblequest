import XCTest
import SpriteKit
import UIKit
@testable import BubbleQuest

final class FestivalRoadMomentTests: XCTestCase {
    func testMomentsAreSpacedAcrossTheJourneyAndRequireActualMilestoneClears() {
        let moments = FestivalRoadMoment.all
        XCTAssertEqual(moments.count, 44)
        XCTAssertEqual(Set(moments.map(\.level)).count, 44)
        XCTAssertEqual(Set(moments.map(\.activity)).count, FestivalRoadMoment.Activity.allCases.count)
        XCTAssertEqual(Set(moments.map(\.landmark)).count, FestivalRoadMoment.Landmark.allCases.count)
        for (index, moment) in moments.enumerated() {
            if index > 0 { XCTAssertEqual(moment.level - moments[index - 1].level, 5) }
            let threshold = FestivalProject.thresholds[moment.step]
            XCTAssertFalse(moment.isReady(cleared: threshold - 1))
            XCTAssertTrue(moment.isReady(cleared: threshold))
            XCTAssertEqual(moment.constructionStage(cleared: threshold - 1), 0)
            XCTAssertEqual(moment.constructionStage(cleared: threshold), moment.step + 1)
            XCTAssertEqual(moment.constructionStage(cleared: 20), 4, "Earlier stops finish decorating too")
            let road = FestivalMapLayout.roadX(at: moment.position.y)
            XCTAssertGreaterThan(abs(moment.position.x - road), 130, "Gatherings stay beside the road")
            XCTAssertTrue((60...330).contains(moment.position.x))
            if moment.step == 3 {
                XCTAssertNotNil(FestivalEvent.forLevel(moment.level))
                XCTAssertTrue(moment.caption(cleared: 0).contains("\(moment.level + 1)"))
                XCTAssertEqual(moment.caption(cleared: 20), "Festival open!")
            }
        }
    }

    @MainActor
    func testFeaturedScenesKeepLevelButtonsAndControlsClearAndPauseOffscreen() throws {
        let suite = "RoadMoments-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        for level in 0..<LevelCatalog.levelCount { progress.recordVictory(index: level, score: 100, stars: 1) }
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["start-adventure"])
        let route = try XCTUnwrap(scene.childNode(withName: "//map-route"))
        var seen = Set<Int>(), activities = Set<String>()
        var checked = 0
        let stops = Array(stride(from: 0, to: LevelCatalog.levelCount, by: 3))
        for level in stops + Array(stops.reversed()) {
            scene.scrollMap(to: FestivalMapLayout.focusedOffset(local: level) + 37)
            let markers = route.children.filter { !$0.isHidden && ($0.name == "locked" || $0.name?.hasPrefix("level-") == true) }
            let features = route.children.filter { $0.name?.hasPrefix("project-site-") == true || $0.name == "journey-landmark" }
            XCTAssertLessThanOrEqual(features.count, 6, "Only nearby scenes stay loaded")
            for feature in features {
                if let level = feature.userData?["momentLevel"] as? Int { seen.insert(level) }
                for child in feature.children where child.name?.hasPrefix("journey-activity-") == true {
                    activities.insert(child.name!)
                }
                if feature.name?.hasPrefix("project-site-") == true {
                    XCTAssertNotNil(feature.childNode(withName: "project-construction-stage-4"))
                }
                if let milestone = feature.userData?["momentLevel"] as? Int,
                   FestivalRoadMoment.all.first(where: { $0.level == milestone })?.landmark == .bridge,
                   feature.name == "journey-landmark" {
                    XCTAssertNotNil(feature.childNode(withName: "journey-bridge-water"))
                }
                if feature.isHidden { XCTAssertTrue(feature.isPaused); continue }
                let frame = feature.calculateAccumulatedFrame()
                XCTAssertTrue(FestivalMapLayout.viewport.contains(frame.offsetBy(dx: 0, dy: route.position.y)))
                for marker in markers {
                    XCTAssertFalse(frame.intersects(marker.calculateAccumulatedFrame()), "Keep the level number and life count clear")
                }
                checked += 1
            }
        }
        XCTAssertGreaterThan(checked, 100)
        XCTAssertEqual(seen.count, 44)
        XCTAssertEqual(activities, Set(["snacks", "drums", "kites", "greeting"].map { "journey-activity-" + $0 }))
    }
}
