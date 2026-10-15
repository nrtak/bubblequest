import Foundation

struct GamePlayer: Codable, Equatable, Identifiable {
    let id: String
    var name: String
    var fileName: String { "\(name)-\(id.prefix(8)).bubblequest" }
}

/// Local player slots. The original slot keeps the existing defaults intact.
final class GameProfiles {
    private struct Index: Codable { var players: [GamePlayer]; var active: String }
    private let registry: UserDefaults
    private let directory: URL
    private let namespace: String
    private var index: Index
    private let key = "localPlayerIndex"
    var players: [GamePlayer] { index.players }
    var active: GamePlayer { index.players.first { $0.id == index.active } ?? index.players[0] }

    init(registry: UserDefaults = .standard, directory: URL? = nil, namespace: String = "BubbleQuest.Player") {
        self.registry = registry
        self.namespace = namespace
        self.directory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent("Players", isDirectory: true)
        if let data = registry.data(forKey: key), let saved = try? JSONDecoder().decode(Index.self, from: data), !saved.players.isEmpty {
            index = saved
        } else {
            index = Index(players: [GamePlayer(id: "original", name: "Player 1")], active: "original")
        }
        saveIndex()
    }

    func defaults(for player: GamePlayer) -> UserDefaults {
        player.id == "original" ? registry : UserDefaults(suiteName: "\(namespace).\(player.id)")!
    }
    func makeProgress() -> GameProgress { GameProgress(defaults: defaults(for: active)) }

    static func cleanName(_ value: String) -> String? {
        let name = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: " _-"))
        guard !name.isEmpty, name.count <= 24, name.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return name
    }

    @discardableResult
    func create(name: String) -> GamePlayer? {
        guard let name = Self.cleanName(name), !players.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else { return nil }
        persistActive()
        let player = GamePlayer(id: UUID().uuidString, name: name)
        index.players.append(player)
        index.active = player.id
        saveIndex()
        persistActive()
        return player
    }

    @discardableResult
    func select(_ id: String) -> Bool {
        guard players.contains(where: { $0.id == id }) else { return false }
        persistActive()
        index.active = id
        saveIndex()
        return true
    }

    @discardableResult
    func renameActive(_ name: String) -> Bool {
        guard let name = Self.cleanName(name), !players.contains(where: { $0.id != active.id && $0.name.caseInsensitiveCompare(name) == .orderedSame }),
              let position = index.players.firstIndex(where: { $0.id == active.id }) else { return false }
        index.players[position].name = name
        saveIndex()
        persistActive()
        return true
    }

    /// Named, atomic on-device snapshot alongside the normal autosave store.
    @discardableResult
    func persistActive() -> Bool {
        let keys = Set(["festivalCollection", "unlockedLevel", "unfinishedPuzzle", "lastSaved", "tutorialSeen", "firstMatchLearned", "selectedAnimal", "selectedHuman", "festivalAdventure", "muted", "musicVolume", "effectsVolume"])
            .union(GameSetting.allCases.map(\.rawValue))
        let prefixes = ["levelResults-", "stars-", "bestScore-", "attempts-", "lastWon-", "lastRemaining-", "buddyWelcomed-", "learned-", "challenge-", "neighborMet-", "hostMet-"]
        let values = defaults(for: active).dictionaryRepresentation().filter { keys.contains($0.key) || prefixes.contains(where: $0.key.hasPrefix) }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try PropertyListSerialization.data(fromPropertyList: values, format: .binary, options: 0)
            try data.write(to: directory.appendingPathComponent(active.fileName), options: .atomic)
            return true
        } catch { return false }
    }

    private func saveIndex() {
        if let data = try? JSONEncoder().encode(index) { registry.set(data, forKey: key) }
    }
}
