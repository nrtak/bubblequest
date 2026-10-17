import Foundation

struct GameCheckpoint: Codable {
    struct Bubble: Codable { let row: Int; let column: Int; let color: Int }
    struct Special: Codable { let row: Int; let column: Int; let kind: SpecialBubble }
    let version: Int
    let level: Int
    let bubbles: [Bubble]
    let specials: [Special]
    let shots: Int
    let score: Int
    let currentColor: Int
    let nextColor: Int
    let bag: [Int]
    let rainbow: Int
    let bomb: Int
    let play: QuestPlay
    let challenge: Bool?
    let freeRainbow: Bool?
    let freeBomb: Bool?
    let ceilingOffset: Double?
    let shotsFired: Int?
    let pressureSeed: UInt64?
    let layoutSeed: UInt64?
    let armor: Set<Cell>?
    let blockers: Set<Cell>?
    let goal: PuzzleGoal?
    let bankMatches: Int?
    let boosterShots: Int?
    let balanceVersion: Int?
    let shotBudget: Int?

    init(level: Int, board: BubbleBoard, shots: Int, score: Int, current: Int, next: Int,
         bag: [Int], rainbow: Int, bomb: Int, play: QuestPlay, challenge: Bool = false,
         freeRainbow: Bool = true, freeBomb: Bool = true, ceilingOffset: Double = 0, shotsFired: Int = 0, pressureSeed: UInt64 = 0, layoutSeed: UInt64? = nil, goal: PuzzleGoal? = nil, bankMatches: Int = 0, boosterShots: Int = 0, balanceVersion: Int = LevelPlayResults.balanceVersion, shotBudget: Int? = nil) {
        version = 1; self.level = level; self.shots = shots; self.score = score
        currentColor = current; nextColor = next; self.bag = bag
        self.rainbow = rainbow; self.bomb = bomb; self.play = play
        self.challenge = challenge
        self.freeRainbow = freeRainbow; self.freeBomb = freeBomb
        self.ceilingOffset = ceilingOffset; self.shotsFired = shotsFired
        self.pressureSeed = pressureSeed; self.layoutSeed = layoutSeed
        armor = board.armor; blockers = board.blockers; self.goal = goal
        self.bankMatches = bankMatches; self.boosterShots = boosterShots
        self.balanceVersion = balanceVersion
        self.shotBudget = shotBudget ?? max(shots, LevelCatalog.level(level).shots)
        bubbles = board.bubbles.map { Bubble(row: $0.key.row, column: $0.key.column, color: $0.value) }
        specials = board.specials.map { Special(row: $0.key.row, column: $0.key.column, kind: $0.value) }
    }
    var board: BubbleBoard? {
        guard version == 1, LevelCatalog.levels.indices.contains(level), shots > 0, shots <= 999,
              score >= 0, (0..<5).contains(currentColor), (0..<5).contains(nextColor),
              (shotBudget ?? shots) >= shots, (shotBudget ?? shots) <= 999,
              rainbow >= 0, bomb >= 0, (ceilingOffset ?? 0).isFinite, (0...240).contains(ceilingOffset ?? 0), (0...999).contains(shotsFired ?? 0), bag.allSatisfy({ (0..<5).contains($0) }),
              !bubbles.isEmpty, bubbles.count <= BubbleBoard.columns * BubbleBoard.rows else { return nil }
        var values: [Cell: Int] = [:]
        for item in bubbles {
            let cell = Cell(row: item.row, column: item.column)
            guard BubbleBoard.valid(cell), BubbleGeometry.point(cell, ceilingOffset: ceilingOffset ?? 0).y >= BubbleGeometry.lossLine,
                  (0..<5).contains(item.color), values[cell] == nil else { return nil }
            values[cell] = item.color
        }
        var specialValues: [Cell: SpecialBubble] = [:]
        for item in specials {
            let cell = Cell(row: item.row, column: item.column)
            guard values[cell] != nil, specialValues[cell] == nil else { return nil }
            specialValues[cell] = item.kind
        }
        let armor = self.armor ?? [], blockers = self.blockers ?? []
        guard armor.isSubset(of: Set(values.keys)), blockers.isSubset(of: Set(values.keys)),
              armor.isDisjoint(with: blockers), (bankMatches ?? 0) >= 0, (boosterShots ?? 0) >= 0 else { return nil }
        let board = BubbleBoard(bubbles: values, specials: specialValues, armor: armor, blockers: blockers)
        guard goal?.isValid(on: board) ?? true else { return nil }
        let anchored = values.keys.filter { $0.row == 0 }.reduce(into: Set<Cell>()) { result, root in
            result.formUnion(board.connected(from: root, matchingColor: false))
        }
        return anchored == Set(values.keys) ? board : nil
    }
}
