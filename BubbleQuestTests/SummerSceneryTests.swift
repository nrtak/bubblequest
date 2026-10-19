import XCTest
import UIKit
import SpriteKit
@testable import BubbleQuest

final class SummerSceneryTests: XCTestCase {
    func testLaterAreasUseNewSceneryAndMarkersStayInsideMap() {
        XCTAssertNil(SummerScenery.forArea(4))
        XCTAssertNil(SummerScenery.forArea(LevelCatalog.areas.count))
        for area in 5..<LevelCatalog.areas.count {
            let scenery = SummerScenery.forArea(area)!
            XCTAssertEqual(LevelCatalog.areas[area].background, scenery.background)
            XCTAssertTrue((area * LevelCatalog.levelsPerArea..<(area + 1) * LevelCatalog.levelsPerArea).allSatisfy { LevelCatalog.level($0).background == scenery.background })
            XCTAssertEqual(scenery.markerPositions.count, 10)
            XCTAssertTrue(scenery.markerPositions.allSatisfy { (130...280).contains($0.x) && (235...600).contains($0.y) })
            XCTAssertGreaterThan(scenery.mapRegion.width, 0)
            XCTAssertGreaterThan(scenery.mapRegion.height, 0)
            XCTAssertTrue(CGRect(x: 0, y: 0, width: 1, height: 1).contains(scenery.mapRegion))
        }
    }

    func testNewBuddyUnlocksAndSelectionsSurviveReopening() throws {
        let suite = "SummerBuddies-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = GameProgress(defaults: defaults)
        let added = Companion.all.filter { $0.atlasIndex >= 12 }
        XCTAssertEqual(added.count, 3)
        for buddy in added {
            XCTAssertFalse(progress.unlocked(buddy))
            for level in 0..<buddy.unlockAfter { progress.recordVictory(index: level, score: 200, stars: 1) }
            XCTAssertTrue(progress.unlocked(buddy))
            progress.select(buddy)
            XCTAssertEqual(GameProgress(defaults: defaults).selected(.animal).id, buddy.id)
        }
    }

    @MainActor
    func testNewNeighborsAndEveryBuddyPickerPageAreReachable() throws {
        let suite = "SummerMaps-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: defaults, directory: directory, namespace: suite)
        let progress = profiles.makeProgress()
        progress.recordVictory(index: LevelCatalog.levelCount - 1, score: 200, stars: 1)
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        scene.didMove(to: SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844)))
        scene.handleMenu(["start-adventure"])
        for _ in 0..<20 { scene.handleMenu(["area-prev"]) }
        for area in LevelCatalog.areas.indices {
            let overlay = try XCTUnwrap(scene.children.last)
            XCTAssertNil(overlay.childNode(withName: "neighbors"))
            XCTAssertNotNil(overlay.childNode(withName: "courtyard-resident"))
            if area >= 5 {
                XCTAssertNotNil(overlay.childNode(withName: "courtyard-resident"))
            }
            scene.handleMenu(["area-next"])
        }
        scene.handleMenu(["friends"])
        var visible = Set<String>()
        for _ in 0..<((Companion.all.count + 5) / 6) {
            let overlay = try XCTUnwrap(scene.children.last)
            visible.formUnion(overlay.children.compactMap(\.name).filter { $0.hasPrefix("friend-") })
            scene.handleMenu(["friends-page"])
        }
        XCTAssertEqual(visible, Set(Companion.all.map { "friend-\($0.id)" }))
        for neighbor in FestivalNeighbor.all where neighbor.portraitIndex >= 8 {
            XCTAssertNotNil(UIImage(named: "festival-summer-neighbors"))
            XCTAssertTrue((5...10).contains(neighbor.area))
        }
    }
}
