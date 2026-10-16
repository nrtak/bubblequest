import XCTest
@testable import BubbleQuest

final class FestivalCollectionTests: XCTestCase {
    func testMedalsRequireTheActualAchievementsAndReplaysNeverRemoveThem() throws {
        var collection = FestivalCollection()
        collection.recordWin(level: 60, stars: 1, boosters: 0, banks: 0)
        XCTAssertEqual(collection.medals[60], [.noBoosters])
        collection.recordWin(level: 60, stars: 3, boosters: 2, banks: 3)
        XCTAssertEqual(collection.medals[60], Set(ChallengeMedal.allCases))
        collection.recordWin(level: 60, stars: 1, boosters: 2, banks: 0)
        XCTAssertEqual(collection.medals[60]?.count, 3)
        let restored = try JSONDecoder().decode(FestivalCollection.self, from: JSONEncoder().encode(collection))
        XCTAssertEqual(restored.medals, collection.medals)
        XCTAssertFalse(ChallengeMedal.earned(stars: 2, boosters: 1, bankMatches: 2).contains(.bankArtist))
    }

    func testReplayFiltersRespectUnlocksAndSouvenirsRecognizeExistingSaves() {
        let suite = "FestivalAlbum-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let progress = GameProgress(defaults: defaults)
        defaults.set(22, forKey: "unlockedLevel")
        for level in 0..<20 { defaults.set(3, forKey: "stars-\(level)") }
        defaults.set(3, forKey: "stars-9")
        XCTAssertTrue(progress.hasSouvenir(area: 0))
        XCTAssertFalse(progress.hasSouvenir(area: 1))
        XCTAssertEqual(progress.medals(for: 9), [.threeStars])
        XCTAssertEqual(progress.replayLevels(area: 1, filter: .all), [20, 21, 22])
        XCTAssertEqual(progress.replayLevels(area: 1, filter: .stars), [20, 21, 22])
        _ = progress.recordCollection(level: 20, stars: 3, boosters: 0, banks: 3)
        XCTAssertFalse(progress.replayLevels(area: 1, filter: .medals).contains(20))
        XCTAssertEqual(progress.recordCollection(level: 20, stars: 3, boosters: 0, banks: 3), [])
        progress.dismissConversation(area: 0)
        let restored = GameProgress(defaults: defaults)
        XCTAssertTrue(restored.collection.readConversations.contains(0))
        XCTAssertEqual(restored.collection.medals[20]?.count, 3)
        XCTAssertTrue(restored.replayLevels(area: 99, filter: .all).isEmpty)
    }

    func testPrecisionPuzzlesStayCompactAndAreaPatternsVary() {
        let precision = LevelCatalog.levels.filter(\.isPrecision)
        XCTAssertEqual(precision.count, 19)
        for level in precision {
            XCTAssertLessThanOrEqual(level.initialBubbles.keys.map(\.row).max() ?? 0, level.index < 100 ? 3 : 4)
            XCTAssertTrue(level.initialArmor.isEmpty)
            XCTAssertGreaterThanOrEqual(level.shots, 12)
        }
        XCTAssertEqual(Set((0..<20).map(FestivalPattern.forArea)), Set(FestivalPattern.allCases))
        XCTAssertEqual(FestivalCelebration.forArea(2), .lanterns)
        XCTAssertEqual(FestivalCelebration.forArea(3), .water)
        for buddy in Companion.all where buddy.kind == .animal {
            XCTAssertTrue(BuddyPersonality.loadingFrames(id: buddy.id).allSatisfy { (0...3).contains($0) })
            XCTAssertFalse(BuddyPersonality.cheer(id: buddy.id, event: .bank).isEmpty)
        }
    }

    func testSouvenirTokensLeaveTheLevelMarkersAndLeftHandMapControlsClear() throws {
        for area in 5..<10 {
            let markers = try XCTUnwrap(SummerScenery.forArea(area)).markerPositions
            let token = try XCTUnwrap(FestivalMapLayout.souvenirPosition(markers: markers))
            XCTAssertGreaterThanOrEqual(token.x, 160)
            for marker in markers {
                XCTAssertGreaterThan(hypot(token.x - marker.x, token.y - marker.y), 29)
            }
        }
        XCTAssertNil(FestivalMapLayout.souvenirPosition(markers: []))
    }
}
