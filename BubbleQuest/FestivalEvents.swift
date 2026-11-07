import Foundation

/// Authored finales change the board and its interactions, not the shot physics.
enum FestivalEvent: String, CaseIterable {
    case market, parade, lanternWalk, picnic, fireworks

    static func forLevel(_ index: Int) -> FestivalEvent? {
        guard index >= 0, (index + 1).isMultiple(of: 20) else { return nil }
        switch index / 20 {
        case 0: return .market
        case 1, 7, 9: return .parade
        case 2, 8: return .lanternWalk
        case 3, 5, 6: return .picnic
        case 4, 10: return .fireworks
        default: return nil
        }
    }
    var rows: [String] {
        switch self {
        case .market: return ["00112233", "0012233", "11223300", "00.11.2", ".001133."]
        case .parade: return ["00112233", "001.233", ".01..23.", "01...23", "00....33", ".0...3."]
        case .lanternWalk: return ["00112233", "2233001", "11002233", "00.11.2", "011.233.", ".11.33."]
        case .picnic: return ["00112233", "00...33", ".01..23.", "01...23", "001..233", "011.233", ".00..33."]
        case .fireworks: return ["00112233", "0012233", "11223300", "22.33.1", "00112233", ".11.33.", "..1..3.."]
        }
    }
    var bubbles: [Cell: Int] {
        var result: [Cell: Int] = [:]
        for (row, line) in rows.enumerated() {
            for (column, token) in line.enumerated() {
                if let color = token.wholeNumberValue { result[Cell(row: row, column: column)] = color }
            }
        }
        return result
    }
    var objective: PuzzleObjective {
        switch self {
        case .market: return .clear
        case .parade: return .ceiling
        case .lanternWalk: return .lanterns
        case .picnic, .fireworks: return .charms
        }
    }
    /// Repeated event families keep their authored routes but start with a distinct palette.
    func startingBubbles(for index: Int) -> [Cell: Int] {
        let original = bubbles
        guard Self.forLevel(index) == self else { return original }
        let palette = Set(original.values).sorted()
        guard !palette.isEmpty else { return original }
        let rotation = stride(from: 19, to: index, by: 20).filter { Self.forLevel($0) == self }.count
        return original.mapValues { color in
            palette[(palette.firstIndex(of: color)! + rotation) % palette.count]
        }
    }
    var goal: PuzzleGoal {
        let cells: [Cell]
        switch self {
        case .market: return PuzzleGoal()
        case .parade: cells = [0, 2, 4, 6].map { Cell(row: 0, column: $0) }
        case .lanternWalk, .fireworks: cells = [0, 2, 5, 7].map { Cell(row: 2, column: $0) }
        case .picnic: cells = [Cell(row: 5, column: 1), Cell(row: 6, column: 1), Cell(row: 5, column: 5), Cell(row: 6, column: 6)]
        }
        return PuzzleGoal(kind: objective, targets: Set(cells))
    }
    var specials: [Cell: SpecialBubble] {
        switch self {
        case .market: return [Cell(row: 2, column: 2): .blossomSpark]
        case .parade: return [:]
        case .lanternWalk: return [Cell(row: 1, column: 2): .lantern, Cell(row: 3, column: 1): .lantern, Cell(row: 3, column: 4): .lantern]
        case .picnic: return [:]
        case .fireworks: return [Cell(row: 6, column: 2): .blossomSpark, Cell(row: 6, column: 5): .blossomSpark,
                                Cell(row: 5, column: 2): .blossomSpark, Cell(row: 5, column: 5): .blossomSpark,
                                Cell(row: 4, column: 3): .blossomSpark, Cell(row: 4, column: 5): .blossomSpark]
        }
    }
    var armor: Set<Cell> {
        switch self {
        case .fireworks, .lanternWalk: return [Cell(row: 1, column: 1), Cell(row: 1, column: 5)]
        case .picnic: return [Cell(row: 1, column: 5)]
        default: return []
        }
    }
    var blockers: Set<Cell> {
        self == .parade ? [Cell(row: 2, column: 2), Cell(row: 2, column: 5)] : []
    }
    var shotBudget: Int {
        switch self {
        case .market: return 16
        case .parade, .picnic: return 12
        case .lanternWalk, .fireworks: return 14
        }
    }
    var mission: String {
        switch self {
        case .market: return "Open the market"
        case .parade: return "Reach the parade flags"
        case .lanternWalk: return "Light the lantern walk"
        case .picnic: return "Bring down the picnic baskets"
        case .fireworks: return "Launch the festival fireworks"
        }
    }
    var instruction: String {
        switch self {
        case .market: return "Clear every bubble to open the market. Match the blossom spark to start a bigger pop."
        case .parade: return "Free all four marked flags. Wooden gates leave side routes for wall bounces. The other bubbles can stay."
        case .lanternWalk: return "Free all four glowing lanterns. Match a striped lantern to clear its row and set off the next lantern. Ice rings need two matches."
        case .picnic: return "Free all four marked baskets. Pop the narrow supports to bring a whole picnic branch down. Matching a basket also frees it. The ice anchor needs two matches."
        case .fireworks: return "Free all four marked fireworks. Match the sparkling bubbles to set off neighboring sparks in a chain. Ice rings need two matches."
        }
    }
    var targetSymbol: String {
        switch self {
        case .market: return "basket.fill"
        case .parade: return "flag.fill"
        case .lanternWalk: return "lightbulb.fill"
        case .picnic: return "basket.fill"
        case .fireworks: return "sparkles"
        }
    }
    func targetNoun(count: Int) -> String {
        let singular: String
        switch self {
        case .market: singular = "bubble"
        case .parade: singular = "flag"
        case .lanternWalk: singular = "lantern"
        case .picnic: singular = "basket"
        case .fireworks: singular = "firework"
        }
        return singular + (count == 1 ? "" : "s")
    }
    func progressText(goal: PuzzleGoal, bubblesLeft: Int) -> String {
        if objective == .clear { return "\(mission) • \(bubblesLeft) \(targetNoun(count: bubblesLeft)) left" }
        return "\(mission) \(goal.total - goal.remaining.count)/\(goal.total)"
    }
    func completionSummary(bubblesLeft: Int) -> String {
        let title: String
        switch self {
        case .market: return "Every bubble cleared. The market is ready!"
        case .parade: title = "All four parade flags freed!"
        case .lanternWalk: title = "All four lanterns are glowing!"
        case .picnic: title = "All four picnic baskets are ready!"
        case .fireworks: title = "All four fireworks are ready for the show!"
        }
        return title + (bubblesLeft > 0 ? "\nOther bubbles didn't need clearing." : "")
    }
}
