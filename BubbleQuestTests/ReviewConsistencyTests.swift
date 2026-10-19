import XCTest
import SpriteKit
@testable import BubbleQuest

final class ReviewConsistencyTests: XCTestCase {
    func testPrizeWheelSectorsMatchTheBoosterOddsAndOwnedKeepsakeConversion() throws {
        let suite = "WheelSectors-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let adventure = AdventureProgress(defaults: defaults)
        let full = 2 * Double.pi
        XCTAssertEqual(adventure.wheelSector(for: .rainbow).countedWidth / full, 0.4, accuracy: 0.000001)
        XCTAssertEqual(adventure.wheelSector(for: .bomb).countedWidth / full, 0.4, accuracy: 0.000001)
        var previous = 0.0
        for prize in adventure.wheelPrizes {
            let sector = adventure.wheelSector(for: prize)
            XCTAssertEqual(sector.lowerBound, previous, accuracy: 0.000001)
            previous = sector.upperBound
        }
        XCTAssertEqual(previous, full, accuracy: 0.000001)
        struct Seeded: RandomNumberGenerator {
            var state: UInt64 = 42
            mutating func next() -> UInt64 {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                return state
            }
        }
        adventure.synchronize(completedLevels: 1000)
        var random = Seeded()
        for _ in 0..<200 where adventure.wheelPrizes.count > 2 { XCTAssertNotNil(adventure.draw(using: &random)) }
        XCTAssertEqual(adventure.wheelPrizes, [.rainbow, .bomb])
        XCTAssertEqual(adventure.wheelSector(for: .rainbow).countedWidth / full, 0.5, accuracy: 0.000001)
        XCTAssertEqual(adventure.wheelSector(for: .bomb).countedWidth / full, 0.5, accuracy: 0.000001)
        XCTAssertTrue(adventure.wheelSector(for: .starPin).isEmpty)
    }

    func testMedalReplayFilterRecognizesLegacyThreeStarAwards() throws {
        let suite = "LegacyMedalFilter-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set(3, forKey: "stars-0")
        var collection = FestivalCollection()
        collection.medals[0] = [.noBoosters, .bankArtist]
        defaults.set(try JSONEncoder().encode(collection), forKey: "festivalCollection")
        let progress = GameProgress(defaults: defaults)
        XCTAssertEqual(progress.medals(for: 0), Set(ChallengeMedal.allCases))
        XCTAssertFalse(progress.replayLevels(area: 0, filter: .medals).contains(0))
    }
    @MainActor
    func testFailedNamedBackupIsReportedInsteadOfClaimingSaveSucceeded() throws {
        let suite = "BackupFailure-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let folder = FileManager.default.temporaryDirectory.appendingPathComponent(suite)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { defaults.removePersistentDomain(forName: suite); try? FileManager.default.removeItem(at: folder) }
        let blocked = folder.appendingPathComponent("not-a-directory")
        try Data([0]).write(to: blocked)
        let profiles = GameProfiles(registry: defaults, directory: blocked, namespace: suite)
        let progress = profiles.makeProgress(); progress.tutorialSeen = true
        progress.save(GameCheckpoint(level: 0, board: LevelCatalog.level(0).board, shots: 10,
                                     score: 0, current: 0, next: 1, bag: [], rainbow: 1, bomb: 1, play: QuestPlay()))
        let scene = FestivalScene(size: CGSize(width: 390, height: 844), profiles: profiles)
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 390, height: 844))
        view.presentScene(scene); defer { view.presentScene(nil) }
        scene.handleMenu(["save-now"])
        let feedback = try XCTUnwrap(scene.childNode(withName: "//save-feedback") as? SKLabelNode)
        XCTAssertTrue(feedback.text?.contains("could not be confirmed") == true)
        XCTAssertFalse(profiles.persistActive())
        XCTAssertNotNil(profiles.makeProgress().checkpoint)
    }

}

private extension Range where Bound == Double {
    var countedWidth: Double { upperBound - lowerBound }
}
