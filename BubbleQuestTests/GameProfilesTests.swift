import XCTest
@testable import BubbleQuest

final class GameProfilesTests: XCTestCase {
    func testExistingSaveAndNewPlayerRemainIndependentAfterReopening() throws {
        let namespace = "ProfileTests.\(UUID().uuidString)"
        let registry = try XCTUnwrap(UserDefaults(suiteName: namespace))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(namespace)
        defer { registry.removePersistentDomain(forName: namespace); try? FileManager.default.removeItem(at: directory) }
        let original = GameProgress(defaults: registry)
        original.recordVictory(index: 4, score: 900, stars: 3)
        original.adventure.synchronize(completedLevels: 5)
        original.tutorialSeen = true
        original.save(GameCheckpoint(level: 4, board: LevelCatalog.level(4).board, shots: 12, score: 200, current: 0, next: 1, bag: [0, 1], rainbow: 1, bomb: 1, play: QuestPlay()))
        let profiles = GameProfiles(registry: registry, directory: directory, namespace: namespace)
        XCTAssertEqual(profiles.makeProgress().unlockedLevel, 5)
        let guest = try XCTUnwrap(profiles.create(name: "Mika"))
        defer { registry.removePersistentDomain(forName: "\(namespace).\(guest.id)") }
        XCTAssertEqual(profiles.makeProgress().totalStars, 0)
        XCTAssertNil(profiles.makeProgress().checkpoint)
        XCTAssertFalse(profiles.makeProgress().tutorialSeen)
        XCTAssertEqual(profiles.makeProgress().adventure.availableSpins, 0)
        profiles.makeProgress().recordVictory(index: 0, score: 100, stars: 1)
        XCTAssertTrue(profiles.persistActive())
        let reopened = GameProfiles(registry: registry, directory: directory, namespace: namespace)
        XCTAssertEqual(reopened.active.id, guest.id)
        XCTAssertEqual(reopened.makeProgress().totalStars, 1)
        XCTAssertTrue(reopened.select("original"))
        XCTAssertEqual(reopened.makeProgress().totalStars, 3)
        XCTAssertEqual(reopened.makeProgress().bestScore(4), 900)
        XCTAssertEqual(reopened.makeProgress().checkpoint?.score, 200)
        XCTAssertTrue(reopened.makeProgress().tutorialSeen)
        let data = try Data(contentsOf: directory.appendingPathComponent(guest.fileName))
        let saved = try XCTUnwrap(PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any])
        XCTAssertEqual(saved["stars-0"] as? Int, 1)
        XCTAssertNil(saved["localPlayerIndex"])
    }

    func testSaveNamesCannotCollideOrEscapeTheSaveFolder() throws {
        let namespace = "ProfileNames.\(UUID().uuidString)"
        let registry = try XCTUnwrap(UserDefaults(suiteName: namespace))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(namespace)
        defer { registry.removePersistentDomain(forName: namespace); try? FileManager.default.removeItem(at: directory) }
        let profiles = GameProfiles(registry: registry, directory: directory, namespace: namespace)
        XCTAssertNil(profiles.create(name: "../Other"))
        XCTAssertNil(profiles.create(name: "  "))
        let guest = try XCTUnwrap(profiles.create(name: "  Guest  "))
        defer { registry.removePersistentDomain(forName: "\(namespace).\(guest.id)") }
        XCTAssertEqual(guest.name, "Guest")
        XCTAssertNil(profiles.create(name: "guest"))
        XCTAssertFalse(profiles.renameActive("Player 1"))
        XCTAssertTrue(profiles.renameActive("Summer Save"))
        XCTAssertTrue(profiles.select("original"))
        XCTAssertEqual(profiles.makeProgress().totalStars, 0)
        XCTAssertFalse(profiles.select("missing"))
    }
}
