import Foundation

enum FestivalMenuTargets {
    static func buddies(_ names: [String]) -> [String] {
        let controls: Set<String> = ["home", "map-buddies-close", "friends-page", "accessories"]
        return names.filter { controls.contains($0) || $0.hasPrefix("friend-") }
    }
}

enum BubbleShot: Equatable {
    case color(Int)
    case rainbow
    case bomb
}

struct FestivalArea {
    let name: String
    let subtitle: String
    let background: String
    let nightTint: Bool
}

struct GameLevel {
    let index: Int
    let area: Int
    let shots: Int
    let initialBubbles: [Cell: Int]
    var number: Int { index + 1 }
    var ceilingInterval: Int { max(4, 12 - index / 5) }
    var ceilingStep: Double { 4 + Double(index) * 0.55 }
    func ceilingOffset(after shotsFired: Int, seed: UInt64 = 0) -> Double {
        var state = seed
        var threshold = 0
        var drops = 0
        while threshold <= shotsFired {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            threshold += ceilingInterval - 1 + Int((state >> 32) % 4)
            if threshold <= shotsFired { drops += 1 }
        }
        return min(240, Double(drops) * ceilingStep)
    }
    var board: BubbleBoard { BubbleBoard(bubbles: initialBubbles, specials: initialSpecials) }
    var initialSpecials: [Cell: SpecialBubble] {
        guard index % 10 >= 2, area >= 2 else { return [:] }
        let kind: SpecialBubble = area == 2 ? .lantern : area == 3 ? .riverPearl : .blossomSpark
        let color = area == 2 ? 1 : area == 3 ? 2 : 0
        let cell = initialBubbles.keys.filter { $0.row > 0 && initialBubbles[$0] == color }
            .sorted { $0.row == $1.row ? $0.column < $1.column : $0.row > $1.row }.first
        var specials = cell.map { [$0: kind] } ?? [:]
        if area >= 3 && index % 10 >= 6 {
            let earlier: [SpecialBubble] = area == 3 ? [.lantern] : [.lantern, .riverPearl]
            let layout = BubbleBoard(bubbles: initialBubbles)
            let candidates = initialBubbles.keys.filter { $0.row > 0 && specials[$0] == nil && layout.connected(from: $0, matchingColor: true).count >= 2 }
                .sorted { $0.row == $1.row ? $0.column < $1.column : $0.row > $1.row }
            for (cell, special) in zip(candidates, earlier) { specials[cell] = special }
        }
        return specials
    }
    var background: String {
        if area == 0 && index % 10 >= 5 { return "festival-summer-water" }
        if area == 1 && index % 10 >= 4 { return "festival-tea-fields" }
        return LevelCatalog.areas[area].background
    }
    var hint: String {
        if let special = initialSpecials.values.first { return special.explanation }
        if index < 5 {
            return ["Match three bubbles of the same color and symbol.",
                    "Swap freely to choose your next shot.",
                    "Pop a support to drop the bubbles below it.",
                    "The wall can help you reach another angle.",
                    "Try a booster, or save shots for three stars."][index]
        }
        return ["Look for a group you can pop in one shot.",
                "Clear the edges to open a new angle.",
                "Use the gap to reach a supporting group.",
                "Look for a wall bounce around the arch.",
                "Plan your next color before you shoot."][index % 5]
    }

    func stars(shotsRemaining: Int) -> Int {
        shotsRemaining >= shots / 2 ? 3 : shotsRemaining >= shots / 4 ? 2 : 1
    }
}

enum BubbleColorQueue {
    static func draw<R: RandomNumberGenerator>(board: BubbleBoard, bag: inout [Int], using random: inout R) -> Int {
        let colors = Set(board.bubbles.values)
        bag.removeAll { !colors.contains($0) }
        if bag.isEmpty { bag = colors.sorted().shuffled(using: &random) }
        let useful = Set(board.bubbles.keys.filter { board.connected(from: $0, matchingColor: true).count >= 2 }
            .compactMap { board.bubbles[$0] })
        if let index = bag.lastIndex(where: useful.contains) { return bag.remove(at: index) }
        return bag.popLast() ?? 0
    }
}

enum LevelCatalog {
    static let areas = [
        FestivalArea(name: "Sunlit Market", subtitle: "A bright beginning", background: "festival-day", nightTint: false),
        FestivalArea(name: "Summer Courtyard", subtitle: "A playful afternoon", background: "festival-courtyard", nightTint: false),
        FestivalArea(name: "Lantern Street", subtitle: "The evening lights up", background: "festival-lantern", nightTint: false),
        FestivalArea(name: "Riverside Festival", subtitle: "Bubbles by the water", background: "festival-riverside", nightTint: false),
        FestivalArea(name: "Firework Night", subtitle: "One last festival cheer", background: "festival-dusk", nightTint: true)
    ]
    static let levels: [GameLevel] = (0..<50).map { index in
        let area = index / 10
        let local = index % 10
        let height = index < 5 ? [2, 2, 3, 3, 3][index] : min(8, 3 + index / 8)
        let colors = index < 5 ? [2, 2, 3, 3, 3][index] : min(5, 3 + (area + local / 8) / 2)
        var cells: [Cell: Int] = [:]
        for row in 0..<height {
            let width = BubbleBoard.columns - row % 2
            for column in 0..<width {
                var include = true
                if row > 1 {
                    switch local % 5 {
                    case 1:
                        include = row < height / 2 || (column > 0 && column < width - 1)
                    case 2:
                        include = column != width / 2
                    case 3:
                        include = abs(column - width / 2) >= min(2, (row - 1) / 2)
                    case 4:
                        include = row % 2 == 0 ? column > 0 : column < width - 1
                    default: break
                    }
                }
                if include {
                    cells[Cell(row: row, column: column)] =
                        (column / 2 + (row + local % 3) / 2 + area + local) % colors
                }
            }
        }
        if let authored = AuthoredLayouts.bubbles(for: index) { cells = authored }
        let budgetColors = max(colors, Set(cells.values).count)
        // Later areas no longer reset the challenge with welcome/recovery allowances.
        let shots = max(18, cells.count / 2 + budgetColors * 2 + 8 - index / 4)
        return GameLevel(index: index, area: area, shots: shots, initialBubbles: cells)
    }

    static func level(_ index: Int) -> GameLevel {
        levels[min(levels.count - 1, max(0, index))]
    }
}

struct Companion {
    enum Kind: Equatable { case animal, human }
    let id: String
    let name: String
    let kind: Kind
    let atlasIndex: Int
    let unlockAfter: Int
    var unlockQuest: String? = nil
    var unlockDescription: String {
        if let id = unlockQuest, let quest = FestivalQuest.all.first(where: { $0.id == id }) { return "Finish \(quest.title)" }
        return "Clear \(unlockAfter) stops"
    }

    static let all = [
        Companion(id: "shiba", name: "Shiba", kind: .animal, atlasIndex: 0, unlockAfter: 0),
        Companion(id: "white-shiba", name: "White Shiba", kind: .animal, atlasIndex: 1, unlockAfter: 10),
        Companion(id: "calico", name: "Calico Cat", kind: .animal, atlasIndex: 2, unlockAfter: 20),
        Companion(id: "rabbit", name: "Rabbit", kind: .animal, atlasIndex: 3, unlockAfter: 30),
        Companion(id: "guide", name: "Festival Guide", kind: .human, atlasIndex: 4, unlockAfter: 0),
        Companion(id: "host", name: "Festival Host", kind: .human, atlasIndex: 5, unlockAfter: 40),
        Companion(id: "haru", name: "Haru", kind: .human, atlasIndex: 6, unlockAfter: 5),
        Companion(id: "mei", name: "Mei", kind: .human, atlasIndex: 7, unlockAfter: 0, unlockQuest: "parcels"),
        Companion(id: "daichi", name: "Daichi", kind: .human, atlasIndex: 8, unlockAfter: 15),
        Companion(id: "nao", name: "Nao", kind: .human, atlasIndex: 9, unlockAfter: 0, unlockQuest: "pinwheels"),
        Companion(id: "kaito", name: "Kaito", kind: .human, atlasIndex: 10, unlockAfter: 0, unlockQuest: "picnic"),
        Companion(id: "emi", name: "Emi", kind: .human, atlasIndex: 11, unlockAfter: 35)
    ]
}

enum GameSetting: String, CaseIterable {
    case music = "musicEnabled"
    case effects = "effectsEnabled"
    case vibration = "vibrationEnabled"
    case guide = "aimGuideEnabled"
    case contrast = "highContrastEnabled"
    case leftHand = "leftHandedEnabled"

    var title: String {
        switch self {
        case .music: return "Music"
        case .effects: return "Sounds"
        case .vibration: return "Vibration"
        case .guide: return "Aim guide"
        case .contrast: return "High contrast"
        case .leftHand: return "Left-hand controls"
        }
    }
}

final class GameProgress {
    private let defaults: UserDefaults
    let adventure: AdventureProgress

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        adventure = AdventureProgress(defaults: defaults)
        if defaults.bool(forKey: "muted") {
            for setting in [GameSetting.music, .effects] where defaults.object(forKey: setting.rawValue) == nil {
                defaults.set(false, forKey: setting.rawValue)
            }
        }
    }

    var unlockedLevel: Int {
        min(LevelCatalog.levels.count - 1, max(0, defaults.integer(forKey: "unlockedLevel")))
    }
    var completedCount: Int { LevelCatalog.levels.filter { stars($0.index) > 0 }.count }
    var checkpoint: GameCheckpoint? {
        guard let data = defaults.data(forKey: "unfinishedPuzzle"),
              let value = try? JSONDecoder().decode(GameCheckpoint.self, from: data),
              value.board != nil, value.level <= unlockedLevel else { return nil }
        return value
    }
    func save(_ checkpoint: GameCheckpoint) {
        guard checkpoint.board != nil, let data = try? JSONEncoder().encode(checkpoint) else { return }
        defaults.set(data, forKey: "unfinishedPuzzle")
        markSaved()
    }
    func clearCheckpoint() { defaults.removeObject(forKey: "unfinishedPuzzle") }
    var currentLevel: Int { checkpoint?.level ?? unlockedLevel }
    var lastSaved: Date? { defaults.object(forKey: "lastSaved") as? Date }
    func markSaved() { defaults.set(Date(), forKey: "lastSaved") }
    var pendingBuddy: Companion? {
        Companion.all.first { ($0.unlockAfter > 0 || $0.unlockQuest != nil) && unlocked($0) && !defaults.bool(forKey: "buddyWelcomed-\($0.id)") }
    }
    func welcome(_ buddy: Companion) {
        guard unlocked(buddy) else { return }
        defaults.set(true, forKey: "buddyWelcomed-\(buddy.id)")
        markSaved()
    }
    var soundMuted: Bool { !enabled(.music) && !enabled(.effects) }
    func toggleSound() {
        let mute = !soundMuted
        defaults.set(!mute, forKey: GameSetting.music.rawValue)
        defaults.set(!mute, forKey: GameSetting.effects.rawValue)
    }
    func attempts(_ index: Int) -> Int { max(0, defaults.integer(forKey: "attempts-\(index)")) }
    func recordAttempt(_ index: Int) {
        guard LevelCatalog.levels.indices.contains(index) else { return }
        defaults.set(attempts(index) + 1, forKey: "attempts-\(index)")
    }
    func recordOutcome(index: Int, won: Bool, shotsRemaining: Int) {
        guard LevelCatalog.levels.indices.contains(index) else { return }
        defaults.set(won, forKey: "lastWon-\(index)")
        defaults.set(max(0, shotsRemaining), forKey: "lastRemaining-\(index)")
        markSaved()
    }
    var totalStars: Int { LevelCatalog.levels.reduce(0) { $0 + stars($1.index) } }
    var tutorialSeen: Bool {
        get { defaults.bool(forKey: "tutorialSeen") }
        set { defaults.set(newValue, forKey: "tutorialSeen") }
    }
    var practiceDone: Bool {
        get { defaults.bool(forKey: "firstMatchLearned") }
        set { defaults.set(newValue, forKey: "firstMatchLearned") }
    }
    func hasLearned(_ kind: SpecialBubble) -> Bool { defaults.bool(forKey: "learned-\(kind.rawValue)") }
    func markLearned(_ kind: SpecialBubble) { defaults.set(true, forKey: "learned-\(kind.rawValue)") }
    func challengeWon(_ area: Int) -> Bool { defaults.bool(forKey: "challenge-\(area)") }
    func recordChallenge(_ area: Int) { if (0..<5).contains(area) { defaults.set(true, forKey: "challenge-\(area)") } }

    func stars(_ index: Int) -> Int {
        let saved = min(3, max(0, defaults.integer(forKey: "stars-\(index)")))
        return saved > 0 ? saved : bestScore(index) > 0 ? 1 : 0
    }

    func bestScore(_ index: Int) -> Int {
        max(0, defaults.integer(forKey: "bestScore-\(index)"))
    }

    func enabled(_ setting: GameSetting) -> Bool {
        (defaults.object(forKey: setting.rawValue) as? Bool) ?? (setting != .contrast && setting != .leftHand)
    }
    func volumeStep(music: Bool) -> Int { min(5, max(0, defaults.object(forKey: music ? "musicVolume" : "effectsVolume") as? Int ?? (music ? 2 : 3))) }
    func changeVolume(music: Bool, by delta: Int) { defaults.set(min(5, max(0, volumeStep(music: music) + delta)), forKey: music ? "musicVolume" : "effectsVolume") }
    var musicVolume: Float { Float(volumeStep(music: true)) / 5 * 0.55 }
    var effectsVolume: Float { Float(volumeStep(music: false)) / 5 }

    func toggle(_ setting: GameSetting) {
        defaults.set(!enabled(setting), forKey: setting.rawValue)
    }

    @discardableResult
    func recordVictory(index: Int, score: Int, stars earned: Int) -> [Companion] {
        guard LevelCatalog.levels.indices.contains(index) else { return [] }
        let before = completedCount
        defaults.set(max(bestScore(index), score), forKey: "bestScore-\(index)")
        defaults.set(max(stars(index), min(3, max(1, earned))), forKey: "stars-\(index)")
        defaults.set(max(unlockedLevel, min(LevelCatalog.levels.count - 1, index + 1)), forKey: "unlockedLevel")
        let after = completedCount
        return Companion.all.filter { $0.unlockQuest == nil && $0.unlockAfter > before && $0.unlockAfter <= after }
    }

    func unlocked(_ companion: Companion) -> Bool {
        if let id = companion.unlockQuest {
            return FestivalQuest.all.first(where: { $0.id == id }).map { adventure.completed($0) } ?? false
        }
        return completedCount >= companion.unlockAfter
    }

    func selected(_ kind: Companion.Kind) -> Companion {
        let key = kind == .animal ? "selectedAnimal" : "selectedHuman"
        let saved = defaults.string(forKey: key)
        return Companion.all.first { $0.id == saved && $0.kind == kind && unlocked($0) }
            ?? Companion.all.first { $0.kind == kind && $0.unlockAfter == 0 }!
    }

    func neighborIsAvailable(_ neighbor: FestivalNeighbor) -> Bool { unlockedLevel >= neighbor.area * 10 }
    func hasMet(_ neighbor: FestivalNeighbor) -> Bool { defaults.bool(forKey: "neighborMet-\(neighbor.id)") }
    func markMet(_ neighbor: FestivalNeighbor) {
        guard neighborIsAvailable(neighbor) else { return }
        defaults.set(true, forKey: "neighborMet-\(neighbor.id)")
    }

    func select(_ companion: Companion) {
        guard unlocked(companion) else { return }
        defaults.set(companion.id, forKey: companion.kind == .animal ? "selectedAnimal" : "selectedHuman")
    }

    func hasMet(_ host: FestivalHost) -> Bool {
        defaults.bool(forKey: "hostMet-\(host.id)")
    }

    func markMet(_ host: FestivalHost) {
        guard hostIsAvailable(host) else { return }
        defaults.set(true, forKey: "hostMet-\(host.id)")
    }
}

struct BubblePoint: Equatable {
    var x: Double
    var y: Double
}

struct BubbleFlight {
    let points: [BubblePoint]
    let landing: Cell?
    var bounces: [BubblePoint] = []
}

enum BubbleGeometry {
    static let radius = 21.0
    static let left = 48.0
    static let right = 342.0
    static let ceiling = 688.0
    static let origin = BubblePoint(x: 195, y: 176)
    static let lossLine = 360.0
    static let maxAngle = 1.2
    static func bouncePoints(_ flight: BubbleFlight) -> [BubblePoint] {
        flight.bounces
    }

    static func point(_ cell: Cell, ceilingOffset: Double = 0) -> BubblePoint {
        BubblePoint(x: left + Double(cell.column) * radius * 2 + Double(cell.row % 2) * radius,
                    y: ceiling - ceilingOffset - Double(cell.row) * radius * sqrt(3))
    }

    static func distance(_ a: BubblePoint, _ b: BubblePoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    static func flight(angle: Double, board: BubbleBoard, ceilingOffset: Double = 0) -> BubbleFlight {
        let clamped = min(maxAngle, max(-maxAngle, angle))
        var position = origin
        var dx = sin(clamped)
        let dy = cos(clamped)
        var points = [position]
        var bounces: [BubblePoint] = []
        let occupied = board.bubbles.keys.sorted {
            $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row
        }
        for _ in 0..<700 {
            position.x += dx * 3
            position.y += dy * 3
            if position.x < left {
                bounces.append(BubblePoint(x: left, y: position.y - (left - position.x) * dy / max(0.0001, abs(dx))))
                position.x = left * 2 - position.x; dx *= -1
            }
            if position.x > right {
                bounces.append(BubblePoint(x: right, y: position.y - (position.x - right) * dy / max(0.0001, abs(dx))))
                position.x = right * 2 - position.x; dx *= -1
            }
            points.append(position)
            let hit = occupied.filter { distance(point($0, ceilingOffset: ceilingOffset), position) <= radius * 2 - 1 }
                .min { distance(point($0, ceilingOffset: ceilingOffset), position) < distance(point($1, ceilingOffset: ceilingOffset), position) }
            if position.y >= ceiling - ceilingOffset || hit != nil {
                let candidates = hit.map { BubbleBoard.neighbors(of: $0) }
                    ?? (0..<BubbleBoard.columns).map { Cell(row: 0, column: $0) }
                let free = candidates.filter { board.bubbles[$0] == nil }
                let landing = free.min {
                    let a = distance(point($0, ceilingOffset: ceilingOffset), position)
                    let b = distance(point($1, ceilingOffset: ceilingOffset), position)
                    return abs(a - b) < 0.00001 ? ($0.row == $1.row ? $0.column < $1.column : $0.row < $1.row) : a < b
                }
                if let landing { points.append(point(landing, ceilingOffset: ceilingOffset)) }
                return BubbleFlight(points: points, landing: landing, bounces: bounces)
            }
        }
        return BubbleFlight(points: points, landing: nil, bounces: bounces)
    }
}
