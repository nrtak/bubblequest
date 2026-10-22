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
    static let balanceVersion = 5
    let index: Int
    let area: Int
    let shots: Int
    let initialBubbles: [Cell: Int]
    var number: Int { index + 1 }
    var maximumStartingGroup: Int { index < 20 ? 8 : index < 80 ? 4 : 3 }
    var ceilingInterval: Int { index < 3 ? 10 : max(4, 8 - index / 8) }
    var ceilingStep: Double { index < 3 ? 6 + Double(index) * 0.2 : 14 + Double(min(index, 59)) * 0.5 + Double(max(0, index - 59)) * 0.06 }
    func ceilingOffset(after shotsFired: Int, seed: UInt64 = 0, balanceVersion: Int = GameLevel.balanceVersion) -> Double {
        // An unfinished puzzle retains the ceiling schedule it started with.
        let interval = balanceVersion < 4 ? (index < 3 ? 10 : max(4, 10 - index / 5)) : ceilingInterval
        let step = balanceVersion < 4 ? (index < 3 ? 6 + Double(index) * 0.2 : 6 + Double(min(index, 49)) * 0.60 + Double(max(0, index - 49)) * 0.05) : ceilingStep
        var state = seed
        var threshold = 0
        var drops = 0
        while threshold <= shotsFired {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            threshold += interval - 1 + Int((state >> 32) % 4)
            if threshold <= shotsFired { drops += 1 }
        }
        return min(240, Double(drops) * step)
    }
    var board: BubbleBoard { BubbleBoard(bubbles: initialBubbles, specials: initialSpecials, armor: initialArmor, blockers: initialBlockers) }
    var initialSpecials: [Cell: SpecialBubble] {
        guard index % 10 >= 2, area >= 2 else { return [:] }
        let style = area < 5 ? area : 2 + area % 3
        let kind: SpecialBubble = style == 2 ? .lantern : style == 3 ? .riverPearl : .blossomSpark
        let color = style == 2 ? 1 : style == 3 ? 2 : 0
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
        if let scenery = SummerScenery.forArea(area) { return scenery.background }
        if area % 5 == 0 && index % 10 >= 5 { return "festival-summer-water" }
        if area % 5 == 1 && index % 10 >= 4 { return "festival-tea-fields" }
        return LevelCatalog.areas[area].background
    }
    /// Seeded generation keeps the level's depth, row populations, palette and budget.
    func randomized(seed: UInt64) -> GameLevel {
        var random = LayoutRandom(state: seed)
        var values: [Cell: Int] = [:]
        let palette = Array(Set(initialBubbles.values)).sorted()
        var colorBag = palette.shuffled(using: &random)
        let rowColumns = Dictionary(grouping: initialBubbles.keys, by: \.row).mapValues { $0.map(\.column).sorted() }
        for row in rowColumns.keys.sorted() {
            let originalColumns = rowColumns[row] ?? []
            let width = BubbleBoard.columns - row % 2
            let count = originalColumns.count
            var columns = Array(0..<width).shuffled(using: &random).prefix(count).sorted()
            // Every lower bubble must touch an anchored bubble in the preceding row.
            if row > 0 {
                let candidates = Array(0..<width).filter { column in
                    BubbleBoard.neighbors(of: Cell(row: row, column: column)).contains { values[$0] != nil }
                }
                if candidates.count >= count { columns = candidates.shuffled(using: &random).prefix(count).sorted() }
                else { columns = originalColumns }
            }
            // Keep each courtyard's designed lower openings while varying its colors.
            // Otherwise shuffling columns can erase a bank route or the area pattern.
            if isBankRoute || isMilestone || (row >= 3 && count < width) {
                columns = originalColumns
            }
            var color = -1
            var remaining = 0
            for column in columns {
                if remaining == 0 {
                    let maximum = index < 10 ? 3 : 2
                    remaining = Int.random(in: (index < 5 ? 2 : 1)...maximum, using: &random)
                    if colorBag.isEmpty { colorBag = palette.shuffled(using: &random) }
                    if colorBag.last == color && colorBag.count > 1 { colorBag.swapAt(0, colorBag.count - 1) }
                    color = colorBag.removeLast()

                }
                values[Cell(row: row, column: column)] = color
                if index >= 20 {
                    let cell = Cell(row: row, column: column)
                    func groupSize(_ candidate: Int) -> Int {
                        var trial = values; trial[cell] = candidate
                        return BubbleBoard(bubbles: trial).connected(from: cell, matchingColor: true).count
                    }
                    // Check the combined group at every cell, including the second
                    // half of a pair, instead of only checking individual supports.
                    if groupSize(color) > maximumStartingGroup,
                       let replacement = palette.shuffled(using: &random).first(where: { groupSize($0) <= maximumStartingGroup }) {
                        color = replacement; values[cell] = color
                    }
                }
                remaining -= 1
            }
        }
        if isMilestone {
            // Give ceiling targets a matching partner; reaching them remains the puzzle.
            for column in stride(from: 0, to: BubbleBoard.columns - 1, by: 2) {
                let target = Cell(row: 0, column: column)
                let partner = Cell(row: 0, column: column + 1)
                if let color = values[target], values[partner] != nil { values[partner] = color }
            }
        }
        let shell = BubbleBoard(bubbles: values)
        let anchored = values.keys.filter { $0.row == 0 }.reduce(into: Set<Cell>()) { $0.formUnion(shell.connected(from: $1, matchingColor: false)) }
        if anchored.count != values.count || Set(values.values) != Set(initialBubbles.values) { values = initialBubbles }
        return GameLevel(index: index, area: area, shots: shots, initialBubbles: values)
    }
    var hint: String {
        if let special = initialSpecials.values.first { return special.explanation }
        if index < 5 {
            return ["Match three bubbles of the same color and symbol.",
                    "Tap the bubble your buddy holds to swap.",
                    "Pop a support to drop the bubbles below it.",
                    "The wall can help you reach another angle.",
                    "Try a booster, or save shots for five stars."][index]
        }
        return ["Look for a group you can pop in one shot.",
                "Clear the edges to open a new angle.",
                "Use the gap to reach a supporting group.",
                "Look for a wall bounce around the arch.",
                "Plan your next color before you shoot."][index % 5]
    }

    func stars(shotsRemaining: Int) -> Int {
        PuzzleRating.stars(shotsRemaining: shotsRemaining, budget: shots)
    }
}

struct LayoutRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}

enum BubbleColorQueue {
    static func draw<R: RandomNumberGenerator>(board: BubbleBoard, bag: inout [Int], using random: inout R) -> Int {
        let colors = board.playableColors
        bag.removeAll { !colors.contains($0) }
        if bag.isEmpty { bag = colors.sorted().shuffled(using: &random) }
        if board.bubbles.count <= 12 {
            let useful = Set(board.bubbles.keys.filter { board.connected(from: $0, matchingColor: true).count >= 2 }
                .compactMap { board.bubbles[$0] })
            if let index = bag.lastIndex(where: useful.contains) { return bag.remove(at: index) }
        }
        return bag.popLast() ?? 0
    }
}

enum LevelCatalog {
    static let levelsPerArea = 20
    static let levelCount = 220
    static let maximumStars = levelCount * PuzzleRating.maximumStars
    static let originalAreas = [
        FestivalArea(name: "Sunlit Market", subtitle: "A bright beginning", background: "festival-day", nightTint: false),
        FestivalArea(name: "Summer Courtyard", subtitle: "A playful afternoon", background: "festival-courtyard", nightTint: false),
        FestivalArea(name: "Lantern Street", subtitle: "The evening lights up", background: "festival-lantern", nightTint: false),
        FestivalArea(name: "Riverside Festival", subtitle: "Bubbles by the water", background: "festival-riverside", nightTint: false),
        FestivalArea(name: "Firework Night", subtitle: "One last festival cheer", background: "festival-dusk", nightTint: true)
    ]
    static let areas: [FestivalArea] = (0..<levelCount / levelsPerArea).map { index in
        if index < originalAreas.count { return originalAreas[index] }
        let scenery = SummerScenery.forArea(index)!
        let visit = (index - originalAreas.count) / SummerScenery.allCases.count + 1
        let name = index == 10 ? "Riverside Fan Fair" : scenery.title + (visit > 1 ? " \(visit)" : "")
        return FestivalArea(name: name, subtitle: "Levels \(index * levelsPerArea + 1)–\((index + 1) * levelsPerArea)", background: scenery.background, nightTint: false)
    }
    static let levels: [GameLevel] = (0..<levelCount).map { index in
        let area = index / levelsPerArea
        let layoutIndex = min(index, 49)
        let local = layoutIndex % 10
        let layoutArea = layoutIndex / 10
        let height = index < 5 ? [2, 2, 3, 3, 3][index] : min(8, 3 + layoutIndex / 8)
        let colors = index < 5 ? [2, 2, 3, 3, 3][index] : min(5, 3 + (layoutArea + local / 8) / 2)
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
                        (column / 2 + (row + local % 3) / 2 + layoutArea + local) % colors
                }
            }
        }
        if let authored = AuthoredLayouts.bubbles(for: layoutIndex) { cells = authored }
        if index >= 10 {
            // Keep authored shapes, but stop carrying large, ready-made color clusters
            // through the campaign. Later boards use independently colored pairs.
            cells = challengeBubbles(index: index, template: cells)
        }
        let budgetColors = Set(cells.values).count
        let shots: Int
        if index < 3 {
            shots = max(18, cells.count / 2 + budgetColors * 2 + 8 - index / 4)
        } else if index < 10 {
            shots = max(index < 5 ? 18 : 15, (cells.count + 2) / 3 + budgetColors + (index < 5 ? 6 : 3))
        } else {
            let allowance = index < 20 ? 3 : max(0, 2 - index / 40)
            shots = max(index < 20 ? 16 : 14, (cells.count + 2) / 3 + budgetColors + allowance)
        }
        let precision = index >= 15 && index % 10 == 5
        let budget = precision ? max(12, (cells.count + 2) / 3 + budgetColors + 2) : shots
        let draft = GameLevel(index: index, area: area, shots: budget, initialBubbles: cells)
        let objectiveAllowance = index >= 20 && [.lanterns, .charms].contains(draft.objective) ? -2 : 0
        // Obstacles should add decisions rather than refund their entire cost.
        let protectionAllowance = index < 20 ? draft.initialArmor.count + draft.initialBlockers.count :
            (draft.initialArmor.count + draft.initialBlockers.count + 1) / 2
        return GameLevel(index: index, area: area,
                         shots: max(12, budget + objectiveAllowance + protectionAllowance + (draft.isMilestone ? 1 : 0)),
                         initialBubbles: cells)
    }

    private static func challengeBubbles(index: Int, template: [Cell: Int]) -> [Cell: Int] {
        var cells = template
        if index >= 50 {
            // Increase depth across the later campaign instead of recycling levels 21–50.
            let height = min(7, 6 + (index - 50) / 50)
            cells = [:]
            for row in 0..<height {
                let width = BubbleBoard.columns - row % 2
                for column in 0..<width {
                    // Lower openings vary by level; full upper rows anchor every branch.
                    let gap = FestivalPattern.forArea(index / levelsPerArea).gap(row: row, width: width, index: index)
                    if row >= 3 && row % 2 == index % 2 && column == gap { continue }
                    cells[Cell(row: row, column: column)] = 0
                }
            }
        }
        if index >= 10 && (index % 10 == 9 || index % 10 == 3) {
            cells = cells.filter { cell, _ in
                guard cell.row > 1 else { return true }
                let width = BubbleBoard.columns - cell.row % 2
                return index % 10 == 9 ? cell.column != width / 2 : (cell.column > 0 && cell.column < width - 1)
            }
        }
        // These dense clear-board stops need an access lane as pressure rises.
        // Preserve the lane during randomized attempts, like the bank-shot boards.
        if [148, 157, 160].contains(index) {
            cells = cells.filter { cell, _ in
                cell.row < 3 || cell.column != (BubbleBoard.columns - cell.row % 2) / 2
            }
        }
        if index >= 15 && index % 10 == 5 {
            let depth = index < 100 ? 4 : 5
            cells = cells.filter { $0.key.row < depth }
        }
        let shell = BubbleBoard(bubbles: cells)
        var anchored = Set<Cell>()
        for root in cells.keys where root.row == 0 { anchored.formUnion(shell.connected(from: root, matchingColor: false)) }
        cells = cells.filter { anchored.contains($0.key) }
        let palette = index < 30 ? 4 : 5
        var state = UInt64(index + 1) &* 997
        var pairColors: [Cell: Int] = [:]
        let lastRow = cells.keys.map(\.row).max() ?? 0
        for cell in cells.keys.sorted(by: { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }) {
            let pair = Cell(row: cell.row, column: cell.column / 2)
            if pairColors[pair] == nil {
                state = state &* 6364136223846793005 &+ 1442695040888963407
                var color = Int((state >> 32) % UInt64(palette))
                // Avoid long stripes that can remove most of a board in one shot.
                if color == pairColors[Cell(row: cell.row, column: pair.column - 1)] {
                    color = (color + 1) % palette
                }
                pairColors[pair] = color
            }
            var color = pairColors[pair]!
            // Introduce occasional setup shots, then increase them in later areas.
            let splitInterval = max(3, 10 - index / 20)
            if index >= 30 && cell.row < lastRow && (cell.row * 8 + cell.column + index) % splitInterval == 0 {
                color = (color + 1) % palette
            }
            cells[cell] = color
        }
        return cells
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
        if let id = unlockQuest, let quest = FestivalQuest.all.first(where: { $0.id == id }) { return "Area \(unlockAfter / LevelCatalog.levelsPerArea) + \(quest.title)" }
        return "Clear area \(max(1, unlockAfter / LevelCatalog.levelsPerArea))"
    }

    static let all = [
        Companion(id: "shiba", name: "Shiba", kind: .animal, atlasIndex: 0, unlockAfter: 0),
        Companion(id: "white-shiba", name: "White Shiba", kind: .animal, atlasIndex: 1, unlockAfter: 20),
        Companion(id: "calico", name: "Calico Cat", kind: .animal, atlasIndex: 2, unlockAfter: 40),
        Companion(id: "rabbit", name: "Rabbit", kind: .animal, atlasIndex: 3, unlockAfter: 60),
        Companion(id: "guide", name: "Festival Guide", kind: .human, atlasIndex: 4, unlockAfter: 0),
        Companion(id: "host", name: "Festival Host", kind: .human, atlasIndex: 5, unlockAfter: 140),
        Companion(id: "haru", name: "Haru", kind: .human, atlasIndex: 6, unlockAfter: 20),
        Companion(id: "mei", name: "Mei", kind: .human, atlasIndex: 7, unlockAfter: 40, unlockQuest: "parcels"),
        Companion(id: "daichi", name: "Daichi", kind: .human, atlasIndex: 8, unlockAfter: 60),
        Companion(id: "nao", name: "Nao", kind: .human, atlasIndex: 9, unlockAfter: 80, unlockQuest: "pinwheels"),
        Companion(id: "kaito", name: "Kaito", kind: .human, atlasIndex: 10, unlockAfter: 100, unlockQuest: "picnic"),
        Companion(id: "emi", name: "Emi", kind: .human, atlasIndex: 11, unlockAfter: 120),
        Companion(id: "sesame-shiba", name: "Sesame Shiba", kind: .animal, atlasIndex: 12, unlockAfter: 80),
        Companion(id: "cream-rabbit", name: "Cream Rabbit", kind: .animal, atlasIndex: 13, unlockAfter: 100),
        Companion(id: "river-otter", name: "River Otter", kind: .animal, atlasIndex: 14, unlockAfter: 120)
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
        if defaults.integer(forKey: "starRatingVersion") < 1 {
            // Preserve old achievements: 1/3 -> 1/5, 2/3 -> 3/5, 3/3 -> 5/5.
            for level in LevelCatalog.levels.indices {
                let old = defaults.integer(forKey: "stars-\(level)")
                if old > 0 { defaults.set([0, 1, 3, 5][min(3, old)], forKey: "stars-\(level)") }
            }
            defaults.set(1, forKey: "starRatingVersion")
        }
        if defaults.integer(forKey: "courtyardProgressVersion") < 1 {
            let legacy: [String: Int] = ["white-shiba": 10, "calico": 20, "rabbit": 30, "host": 40, "haru": 5, "daichi": 15, "emi": 35, "sesame-shiba": 50, "cream-rabbit": 80, "river-otter": 110]
            let cleared = LevelCatalog.levels.filter { defaults.integer(forKey: "stars-\($0.index)") > 0 || defaults.integer(forKey: "bestScore-\($0.index)") > 0 }.count
            let earned = Companion.all.filter { companion in
                if let questID = companion.unlockQuest {
                    return FestivalQuest.all.first(where: { $0.id == questID }).map { adventure.completed($0) } ?? false
                }
                return legacy[companion.id].map { cleared >= $0 } ?? false
            }.map(\.id)
            defaults.set(earned, forKey: "unlockedCompanions")
            let souvenirs = (0..<min(10, LevelCatalog.areas.count)).filter { defaults.integer(forKey: "stars-\($0 * 10 + 9)") > 0 }
            defaults.set(souvenirs, forKey: "courtyardLegacySouvenirs")
            defaults.set(1, forKey: "courtyardProgressVersion")
        }
        // Older campaigns capped the unlocked index at 49, even after the finale.
        if defaults.integer(forKey: "stars-49") > 0 && defaults.integer(forKey: "unlockedLevel") == 49 {
            defaults.set(50, forKey: "unlockedLevel")
        }
        // Completing the former 200-level campaign opens the new courtyard.
        if defaults.integer(forKey: "unlockedLevel") == 199,
           defaults.integer(forKey: "stars-199") > 0 || defaults.integer(forKey: "bestScore-199") > 0 {
            defaults.set(200, forKey: "unlockedLevel")
        }
        if defaults.bool(forKey: "muted") {
            for setting in [GameSetting.music, .effects] where defaults.object(forKey: setting.rawValue) == nil {
                defaults.set(false, forKey: setting.rawValue)
            }
        }
    }

    func freshLayout(for level: Int) -> (level: GameLevel, seed: UInt64) {
        let base = LevelCatalog.level(level)
        let key = "layoutHistory-\(level)"
        let history = defaults.stringArray(forKey: key) ?? []
        var seed = UInt64.random(in: 1...UInt64.max)
        var candidate = base.randomized(seed: seed)
        func fingerprint(_ value: GameLevel) -> String {
            let text = value.initialBubbles.keys.sorted { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }
                .map { "\($0.row),\($0.column),\(value.initialBubbles[$0]!)" }.joined(separator: ";")
            var hash: UInt64 = 14695981039346656037
            for byte in text.utf8 { hash = (hash ^ UInt64(byte)) &* 1099511628211 }
            return String(hash, radix: 16)
        }
        let seen = Set(history)
        for _ in 0..<1024 {
            if !seen.contains(fingerprint(candidate)) { break }
            seed = seed &+ 1; candidate = base.randomized(seed: seed)
        }
        defaults.set(history + [fingerprint(candidate)], forKey: key)
        return (candidate, seed)
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
    func lives(for index: Int, challenge: Bool = false, now: Date = Date()) -> LevelLives {
        let key = "levelLives-\(index)" + (challenge ? "-challenge" : "")
        let saved = defaults.data(forKey: key).flatMap { try? JSONDecoder().decode(LevelLives.self, from: $0) }
        var value = saved ?? LevelLives()
        value.refresh(at: now)
        if value != (saved ?? LevelLives()), let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: key) }
        return value
    }
    @discardableResult
    func takeTry(for index: Int, challenge: Bool = false, now: Date = Date()) -> Bool {
        guard LevelCatalog.levels.indices.contains(index) else { return false }
        var value = lives(for: index, challenge: challenge, now: now)
        guard value.consume(at: now), let data = try? JSONEncoder().encode(value) else { return false }
        defaults.set(data, forKey: "levelLives-\(index)" + (challenge ? "-challenge" : ""))
        markSaved()
        return true
    }

    func attempts(_ index: Int) -> Int { max(0, defaults.integer(forKey: "attempts-\(index)")) }
    func recordAttempt(_ index: Int) {
        guard LevelCatalog.levels.indices.contains(index) else { return }
        defaults.set(attempts(index) + 1, forKey: "attempts-\(index)")
    }
    func recordOutcome(index: Int, won: Bool, shotsRemaining: Int, shotsFired: Int = 0, bankMatches: Int = 0, boosterShots: Int = 0) {
        guard LevelCatalog.levels.indices.contains(index) else { return }
        var results = levelResults(index)
        results.record(won: won, fired: shotsFired, remaining: shotsRemaining, banks: bankMatches, boosters: boosterShots)
        if let data = try? JSONEncoder().encode(results) { defaults.set(data, forKey: "levelResults-\(index)") }
        defaults.set(won, forKey: "lastWon-\(index)")
        defaults.set(max(0, shotsRemaining), forKey: "lastRemaining-\(index)")
        markSaved()
    }
    func levelResults(_ index: Int) -> LevelPlayResults {
        guard let data = defaults.data(forKey: "levelResults-\(index)"),
              let result = try? JSONDecoder().decode(LevelPlayResults.self, from: data),
              result.version == LevelPlayResults.balanceVersion else { return LevelPlayResults() }
        return result
    }
    var collection: FestivalCollection {
        guard let data = defaults.data(forKey: "festivalCollection"),
              let value = try? JSONDecoder().decode(FestivalCollection.self, from: data) else { return FestivalCollection() }
        return value
    }
    @discardableResult
    func recordCollection(level: Int, stars: Int, boosters: Int, banks: Int) -> Set<ChallengeMedal> {
        guard LevelCatalog.levels.indices.contains(level) else { return [] }
        var value = collection
        let before = value.medals[level] ?? []
        value.recordWin(level: level, stars: stars, boosters: boosters, banks: banks)
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "festivalCollection") }
        return (value.medals[level] ?? []).subtracting(before)
    }
    func dismissConversation(area: Int) {
        guard LevelCatalog.areas.indices.contains(area) else { return }
        var value = collection; value.readConversations.insert(area)
        if let data = try? JSONEncoder().encode(value) { defaults.set(data, forKey: "festivalCollection") }
        markSaved()
    }
    func medals(for index: Int) -> Set<ChallengeMedal> {
        var medals = collection.medals[index] ?? []
        if stars(index) == PuzzleRating.maximumStars { medals.insert(.fiveStars) }
        return medals
    }
    func hasSouvenir(area: Int) -> Bool {
        guard LevelCatalog.areas.indices.contains(area) else { return false }
        return (defaults.array(forKey: "courtyardLegacySouvenirs") as? [Int] ?? []).contains(area) ||
            (area * LevelCatalog.levelsPerArea..<(area + 1) * LevelCatalog.levelsPerArea).allSatisfy { stars($0) > 0 }
    }
    func replayLevels(area: Int, filter: ReplayFilter) -> [Int] {
        guard LevelCatalog.areas.indices.contains(area) else { return [] }
        let medals = collection.medals
        return (area * LevelCatalog.levelsPerArea..<(area + 1) * LevelCatalog.levelsPerArea).filter { index in
            guard index <= unlockedLevel else { return false }
            switch filter {
            case .all: return true
            case .stars: return stars(index) < PuzzleRating.maximumStars
            case .medals:
                var earned = medals[index] ?? []
                if stars(index) == PuzzleRating.maximumStars { earned.insert(.fiveStars) }
                return earned.count < ChallengeMedal.allCases.count
            }
        }
    }
    func hasWelcomedCourtyard(_ area: Int) -> Bool { defaults.bool(forKey: "learned-courtyard-\(area)") }
    func markCourtyardWelcomed(_ area: Int) {
        guard area > 0, LevelCatalog.areas.indices.contains(area), area <= unlockedLevel / LevelCatalog.levelsPerArea else { return }
        defaults.set(true, forKey: "learned-courtyard-\(area)")
    }

    func hasSeenObjective(_ kind: PuzzleObjective) -> Bool { defaults.bool(forKey: "learned-objective-\(kind.rawValue)") }
    func markObjectiveSeen(_ kind: PuzzleObjective) { defaults.set(true, forKey: "learned-objective-\(kind.rawValue)") }
    var hasSeenTriesHelp: Bool {
        get { defaults.bool(forKey: "learned-tries-help") }
        set { defaults.set(newValue, forKey: "learned-tries-help") }
    }
    func hasLearnedObstacle(_ key: String) -> Bool { defaults.bool(forKey: "learned-obstacle-\(key)") }
    func learnObstacle(_ key: String) { defaults.set(true, forKey: "learned-obstacle-\(key)") }
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
    func nextSpecialLesson(in board: BubbleBoard) -> SpecialBubble? {
        [SpecialBubble.lantern, .riverPearl, .blossomSpark].first {
            board.specials.values.contains($0) && !hasLearned($0)
        }
    }
    func markLearned(_ kind: SpecialBubble) { defaults.set(true, forKey: "learned-\(kind.rawValue)") }
    func challengeWon(_ area: Int) -> Bool { defaults.bool(forKey: "challenge-\(area)") }
    func recordChallenge(_ area: Int) { if LevelCatalog.areas.indices.contains(area) { defaults.set(true, forKey: "challenge-\(area)") } }

    func stars(_ index: Int) -> Int {
        let saved = min(PuzzleRating.maximumStars, max(0, defaults.integer(forKey: "stars-\(index)")))
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
        let completedBefore = completedCount
        let previousStars = stars(index)
        let legacy = Set(defaults.stringArray(forKey: "unlockedCompanions") ?? [])
        let previouslyUnlocked = Set(Companion.all.filter { unlocked($0, completed: completedBefore, legacy: legacy) }.map(\.id))
        defaults.set(max(bestScore(index), score), forKey: "bestScore-\(index)")
        defaults.set(max(previousStars, min(PuzzleRating.maximumStars, max(1, earned))), forKey: "stars-\(index)")
        defaults.set(max(unlockedLevel, min(LevelCatalog.levels.count - 1, index + 1)), forKey: "unlockedLevel")
        let completedAfter = completedBefore + (previousStars == 0 ? 1 : 0)
        return Companion.all.filter { !previouslyUnlocked.contains($0.id) && unlocked($0, completed: completedAfter, legacy: legacy) }
    }

    func unlocked(_ companion: Companion) -> Bool {
        let legacy = Set(defaults.stringArray(forKey: "unlockedCompanions") ?? [])
        if legacy.contains(companion.id) { return true }
        return unlocked(companion, completed: completedCount, legacy: legacy)
    }
    private func unlocked(_ companion: Companion, completed: Int, legacy: Set<String>) -> Bool {
        if legacy.contains(companion.id) { return true }
        if let id = companion.unlockQuest {
            return completed >= companion.unlockAfter && (FestivalQuest.all.first(where: { $0.id == id }).map { adventure.completed($0) } ?? false)
        }
        return completed >= companion.unlockAfter
    }

    func unlockLevelProgress(_ companion: Companion) -> String {
        if unlocked(companion) { return "Unlocked ✓" }
        let end = companion.unlockAfter
        let start = max(0, end - LevelCatalog.levelsPerArea)
        let cleared = (start..<end).filter { stars($0) > 0 }.count
        return "\(cleared)/\(end - start) area levels"
    }

    func unlockQuestProgress(_ companion: Companion) -> String? {
        guard let id = companion.unlockQuest, let quest = FestivalQuest.all.first(where: { $0.id == id }) else { return nil }
        return adventure.completed(quest) ? "✓ " + quest.title : quest.title + " \(adventure.count(quest))/\(quest.steps.count)"
    }

    func selected(_ kind: Companion.Kind) -> Companion {
        let key = kind == .animal ? "selectedAnimal" : "selectedHuman"
        let saved = defaults.string(forKey: key)
        return Companion.all.first { $0.id == saved && $0.kind == kind && unlocked($0) }
            ?? Companion.all.first { $0.kind == kind && $0.unlockAfter == 0 }!
    }

    func neighborIsAvailable(_ neighbor: FestivalNeighbor) -> Bool { unlockedLevel >= neighbor.area * LevelCatalog.levelsPerArea }
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
    // Artwork includes a soft glass rim and glow. Use the inner cores for contact
    // so a bank shot can thread a visible opening without catching that halo.
    static let collisionDistance = 33.0
    static let openingCollisionDistance = 25.0
    static let left = 48.0
    static let right = 342.0
    // The board grid stays inset for save compatibility; only moving shots use
    // the device edges. One extra point keeps the bubble rim inside the screen.
    static let sceneWidth = 390.0
    static let flightLeft = radius + 1
    static let flightRight = sceneWidth - flightLeft
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
        }.map { (cell: $0, center: point($0, ceilingOffset: ceilingOffset)) }
        // Keep normal contact around isolated bubbles and solid rows. Only soften
        // the edges of a genuine missing-cell lane between two bubbles in a row.
        var openings: [Int: [ClosedRange<Double>]] = [:]
        for (row, bubbles) in Dictionary(grouping: occupied, by: { $0.cell.row }) {
            for (leftBubble, rightBubble) in zip(bubbles, bubbles.dropFirst()) {
                if rightBubble.center.x - leftBubble.center.x >= radius * 4 - 0.001 {
                    openings[row, default: []].append((leftBubble.center.x + openingCollisionDistance)...(rightBubble.center.x - openingCollisionDistance))
                }
            }
        }
        for _ in 0..<700 {
            position.x += dx * 3
            position.y += dy * 3
            if position.x < flightLeft {
                let bounce = BubblePoint(x: flightLeft, y: position.y - (flightLeft - position.x) * dy / max(0.0001, abs(dx)))
                bounces.append(bounce); points.append(bounce)
                position.x = flightLeft * 2 - position.x; dx *= -1
            }
            if position.x > flightRight {
                let bounce = BubblePoint(x: flightRight, y: position.y - (position.x - flightRight) * dy / max(0.0001, abs(dx)))
                bounces.append(bounce); points.append(bounce)
                position.x = flightRight * 2 - position.x; dx *= -1
            }
            points.append(position)
            var hit: Cell?
            var nearest = Double.infinity
            let outsideGrid = position.x < left || position.x > right
            let maximumContact = outsideGrid ? radius * 2 : collisionDistance
            for bubble in occupied {
                let x = bubble.center.x - position.x, y = bubble.center.y - position.y
                let squared = x * x + y * y
                if squared > maximumContact * maximumContact || squared >= nearest { continue }
                let inOpening = openings[bubble.cell.row]?.contains(where: { $0.contains(position.x) }) ?? false
                // Outside the grid, use the full rims. Otherwise a shot can slip
                // past the exposed edge and hit a sealed cell with no legal slot.
                let contact = outsideGrid ? radius * 2 : inOpening ? openingCollisionDistance : collisionDistance
                if squared <= contact * contact && squared < nearest {
                    hit = bubble.cell; nearest = squared
                }
            }
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
