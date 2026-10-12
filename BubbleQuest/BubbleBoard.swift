import Foundation

struct Cell: Hashable {
    let row: Int
    let column: Int
}

struct BubbleBoard {
    static let columns = 8
    static let rows = 14
    var bubbles: [Cell: Int] = [:]

    static func valid(_ cell: Cell) -> Bool {
        cell.row >= 0 && cell.row < rows && cell.column >= 0 &&
        cell.column < columns - (cell.row % 2)
    }

    static func neighbors(of cell: Cell) -> [Cell] {
        let offset = cell.row % 2 == 0 ? -1 : 1
        return [Cell(row: cell.row, column: cell.column - 1),
                Cell(row: cell.row, column: cell.column + 1),
                Cell(row: cell.row - 1, column: cell.column),
                Cell(row: cell.row - 1, column: cell.column + offset),
                Cell(row: cell.row + 1, column: cell.column),
                Cell(row: cell.row + 1, column: cell.column + offset)].filter(valid)
    }

    func connected(from start: Cell, matchingColor: Bool) -> Set<Cell> {
        guard let color = bubbles[start] else { return [] }
        var visited: Set<Cell> = [start]
        var pending = [start]
        while let cell = pending.popLast() {
            for neighbor in Self.neighbors(of: cell) where !visited.contains(neighbor) {
                guard let other = bubbles[neighbor], !matchingColor || other == color else { continue }
                visited.insert(neighbor)
                pending.append(neighbor)
            }
        }
        return visited
    }

    mutating func place(_ color: Int, at cell: Cell) -> (matched: Set<Cell>, dropped: Set<Cell>) {
        place(.color(color), at: cell)
    }

    mutating func place(_ shot: BubbleShot, at cell: Cell) -> (matched: Set<Cell>, dropped: Set<Cell>) {
        guard Self.valid(cell), bubbles[cell] == nil else { return ([], []) }
        var group = Set<Cell>()
        switch shot {
        case .color(let color):
            guard (0..<5).contains(color) else { return ([], []) }
            bubbles[cell] = color
            group = connected(from: cell, matchingColor: true)
            guard group.count >= 3 else { return ([], []) }
        case .rainbow:
            var bestColor = 0
            for color in Set(bubbles.values).sorted() {
                bubbles[cell] = color
                let candidate = connected(from: cell, matchingColor: true)
                if candidate.count > group.count { group = candidate; bestColor = color }
            }
            bubbles[cell] = bestColor
            if group.isEmpty { group = [cell] }
        case .bomb:
            bubbles[cell] = 0
            var affected: Set<Cell> = [cell]
            var frontier: Set<Cell> = [cell]
            for _ in 0..<2 {
                frontier = Set(frontier.flatMap { Self.neighbors(of: $0) }).subtracting(affected)
                affected.formUnion(frontier)
            }
            group = affected.intersection(Set(bubbles.keys))
        }
        for match in group { bubbles.removeValue(forKey: match) }
        var anchored = Set<Cell>()
        for ceiling in bubbles.keys where ceiling.row == 0 {
            anchored.formUnion(connected(from: ceiling, matchingColor: false))
        }
        let dropped = Set(bubbles.keys).subtracting(anchored)
        for cell in dropped { bubbles.removeValue(forKey: cell) }
        return (group, dropped)
    }

    static func level(_ index: Int) -> BubbleBoard {
        LevelCatalog.level(index).board
    }
}
