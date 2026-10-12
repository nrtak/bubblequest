import Foundation

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
    var board: BubbleBoard { BubbleBoard(bubbles: initialBubbles) }

    func stars(shotsRemaining: Int) -> Int {
        shotsRemaining >= shots / 2 ? 3 : shotsRemaining >= shots / 4 ? 2 : 1
    }
}

enum LevelCatalog {
    static let areas = [
        FestivalArea(name: "Sunlit Market", subtitle: "A bright beginning", background: "festival-day", nightTint: false),
        FestivalArea(name: "Summer Courtyard", subtitle: "A playful afternoon", background: "festival-courtyard", nightTint: false),
        FestivalArea(name: "Lantern Street", subtitle: "The evening lights up", background: "festival-dusk", nightTint: false),
        FestivalArea(name: "Riverside Festival", subtitle: "Bubbles by the water", background: "festival-dusk", nightTint: true),
        FestivalArea(name: "Firework Night", subtitle: "One last festival cheer", background: "festival-dusk", nightTint: true)
    ]
    static let levels: [GameLevel] = (0..<50).map { index in
        let area = index / 10
        let local = index % 10
        let height = min(8, 3 + area / 2 + local / 3)
        let colors = min(5, 3 + (area + local / 8) / 2)
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
        let shots = max(24, cells.count * 2 / 3 + colors * 2 + 5 - local % 3)
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

    static let all = [
        Companion(id: "shiba", name: "Shiba", kind: .animal, atlasIndex: 0, unlockAfter: 0),
        Companion(id: "white-shiba", name: "White Shiba", kind: .animal, atlasIndex: 1, unlockAfter: 10),
        Companion(id: "calico", name: "Calico Cat", kind: .animal, atlasIndex: 2, unlockAfter: 20),
        Companion(id: "rabbit", name: "Rabbit", kind: .animal, atlasIndex: 3, unlockAfter: 30),
        Companion(id: "guide", name: "Festival Guide", kind: .human, atlasIndex: 4, unlockAfter: 0),
        Companion(id: "host", name: "Festival Host", kind: .human, atlasIndex: 5, unlockAfter: 40)
    ]
}

enum GameSetting: String, CaseIterable {
    case music = "musicEnabled"
    case effects = "effectsEnabled"
    case vibration = "vibrationEnabled"
    case guide = "aimGuideEnabled"

    var title: String {
        switch self {
        case .music: return "Music"
        case .effects: return "Sounds"
        case .vibration: return "Vibration"
        case .guide: return "Aim guide"
        }
    }
}

final class GameProgress {
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
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
    var totalStars: Int { LevelCatalog.levels.reduce(0) { $0 + stars($1.index) } }
    var tutorialSeen: Bool {
        get { defaults.bool(forKey: "tutorialSeen") }
        set { defaults.set(newValue, forKey: "tutorialSeen") }
    }

    func stars(_ index: Int) -> Int {
        let saved = min(3, max(0, defaults.integer(forKey: "stars-\(index)")))
        return saved > 0 ? saved : bestScore(index) > 0 ? 1 : 0
    }

    func bestScore(_ index: Int) -> Int {
        max(0, defaults.integer(forKey: "bestScore-\(index)"))
    }

    func enabled(_ setting: GameSetting) -> Bool {
        (defaults.object(forKey: setting.rawValue) as? Bool) ?? true
    }

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
        return Companion.all.filter { $0.unlockAfter > before && $0.unlockAfter <= after }
    }

    func unlocked(_ companion: Companion) -> Bool { completedCount >= companion.unlockAfter }

    func selected(_ kind: Companion.Kind) -> Companion {
        let key = kind == .animal ? "selectedAnimal" : "selectedHuman"
        let saved = defaults.string(forKey: key)
        return Companion.all.first { $0.id == saved && $0.kind == kind && unlocked($0) }
            ?? Companion.all.first { $0.kind == kind && $0.unlockAfter == 0 }!
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
}

enum BubbleGeometry {
    static let radius = 21.0
    static let left = 48.0
    static let right = 342.0
    static let ceiling = 688.0
    static let origin = BubblePoint(x: 195, y: 176)
    static let lossLine = 360.0
    static let maxAngle = 1.2

    static func point(_ cell: Cell) -> BubblePoint {
        BubblePoint(x: left + Double(cell.column) * radius * 2 + Double(cell.row % 2) * radius,
                    y: ceiling - Double(cell.row) * radius * sqrt(3))
    }

    static func distance(_ a: BubblePoint, _ b: BubblePoint) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }

    static func flight(angle: Double, board: BubbleBoard) -> BubbleFlight {
        let clamped = min(maxAngle, max(-maxAngle, angle))
        var position = origin
        var dx = sin(clamped)
        let dy = cos(clamped)
        var points = [position]
        let occupied = board.bubbles.keys.sorted {
            $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row
        }
        for _ in 0..<700 {
            position.x += dx * 3
            position.y += dy * 3
            if position.x < left { position.x = left * 2 - position.x; dx *= -1 }
            if position.x > right { position.x = right * 2 - position.x; dx *= -1 }
            points.append(position)
            let hit = occupied.filter { distance(point($0), position) <= radius * 2 - 1 }
                .min { distance(point($0), position) < distance(point($1), position) }
            if position.y >= ceiling || hit != nil {
                let candidates = hit.map { BubbleBoard.neighbors(of: $0) }
                    ?? (0..<BubbleBoard.columns).map { Cell(row: 0, column: $0) }
                let free = candidates.filter { board.bubbles[$0] == nil }
                let landing = free.min {
                    let a = distance(point($0), position)
                    let b = distance(point($1), position)
                    return abs(a - b) < 0.00001 ? ($0.row == $1.row ? $0.column < $1.column : $0.row < $1.row) : a < b
                }
                if let landing { points.append(point(landing)) }
                return BubbleFlight(points: points, landing: landing)
            }
        }
        return BubbleFlight(points: points, landing: nil)
    }
}
