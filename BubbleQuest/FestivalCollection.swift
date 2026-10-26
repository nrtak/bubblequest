import Foundation
import CoreGraphics

enum ChallengeMedal: String, Codable, CaseIterable {
    case noBoosters, bankArtist
    case fiveStars = "threeStars"
    var title: String {
        switch self {
        case .noBoosters: return "No boosters"
        case .bankArtist: return "Three bank matches"
        case .fiveStars: return "Five stars"
        }
    }
    var symbol: String {
        switch self {
        case .noBoosters: return "hand.raised.fill"
        case .bankArtist: return "arrow.uturn.up"
        case .fiveStars: return "star.fill"
        }
    }
    static func earned(stars: Int, boosters: Int, bankMatches: Int) -> Set<ChallengeMedal> {
        var result: Set<ChallengeMedal> = []
        if boosters == 0 { result.insert(.noBoosters) }
        if bankMatches >= 3 { result.insert(.bankArtist) }
        if stars == PuzzleRating.maximumStars { result.insert(.fiveStars) }
        return result
    }
}

struct FestivalCollection: Codable {
    var medals: [Int: Set<ChallengeMedal>] = [:]
    var readConversations: Set<Int> = []
    mutating func recordWin(level: Int, stars: Int, boosters: Int, banks: Int) {
        medals[level, default: []].formUnion(ChallengeMedal.earned(stars: stars, boosters: boosters, bankMatches: banks))
    }
}

enum ReplayFilter: String, CaseIterable {
    case stars = "Stars", medals = "Medals", all = "All"
}

enum FestivalPattern: Int, CaseIterable {
    case diamonds, branches, arches, waves, terraces
    static func forArea(_ area: Int) -> FestivalPattern {
        if area < 5 { return allCases[max(0, area)] }
        return [FestivalPattern.waves, .terraces, .arches, .diamonds, .branches][(area - 5) % 5]
    }
    func gap(row: Int, width: Int, index: Int) -> Int {
        switch self {
        case .diamonds: return min(width - 1, max(0, width / 2 + (row % 3 - 1)))
        case .branches: return min(width - 1, width / 2 + row % 2)
        case .arches: return width / 2
        case .waves: return (index / 3 + row * 2) % width
        case .terraces: return row % 2 == 0 ? 0 : width - 1
        }
    }
}

extension GameLevel {
    var isPrecision: Bool { index >= 15 && index % 10 == 5 }
}

enum FestivalCelebration: Int, CaseIterable {
    case petals, lanterns, water, leaves, fireworks
    static func forArea(_ area: Int) -> FestivalCelebration {
        if area < 5 { return [FestivalCelebration.petals, .leaves, .lanterns, .water, .fireworks][max(0, area)] }
        return [FestivalCelebration.water, .leaves, .petals, .water, .fireworks][(area - 5) % 5]
    }
    var symbol: String {
        switch self {
        case .petals: return "camera.macro"
        case .lanterns: return "lightbulb.fill"
        case .water: return "drop.fill"
        case .leaves: return "leaf.fill"
        case .fireworks: return "sparkles"
        }
    }
    var souvenir: String {
        switch self {
        case .petals: return "Blossom charm"
        case .lanterns: return "Paper lantern"
        case .water: return "River pebble"
        case .leaves: return "Tea-leaf bookmark"
        case .fireworks: return "Festival ribbon"
        }
    }
}

enum BuddyPersonality {
    enum Reaction { case bank, drop, low }
    static func cheer(id: String, event: Reaction) -> String {
        switch event {
        case .low: return id.contains("rabbit") ? "One careful hop!" : id == "river-otter" ? "Steady now!" : "Take your time!"
        case .bank: return id == "calico" ? "Purrfect bounce!" : id.contains("rabbit") ? "Lovely bounce!" : "Clever shot!"
        case .drop: return id == "river-otter" ? "Big splash!" : id.contains("shiba") ? "Pawsome!" : "What a drop!"
        }
    }
    static func loadingFrames(id: String) -> [Int] {
        id.contains("rabbit") ? [0, 1, 2, 0] : id == "calico" ? [1, 0, 2, 0] : id == "river-otter" ? [1, 2, 0] : [1, 2, 1, 0]
    }
}

enum FestivalMapLayout {
    static let viewport = CGRect(x: 0, y: 204, width: 390, height: 512)
    static let segmentHeight: CGFloat = 576
    static let blendHeight: CGFloat = 128
    static let tileHeight: CGFloat = 704
    static func artworkArea(segment: Int) -> Int {
        level(at: CGFloat(segment) * segmentHeight + segmentHeight / 2) / LevelCatalog.levelsPerArea
    }
    static func mapScenery(area: Int) -> SummerScenery? {
        area == 3 ? .river : SummerScenery.forArea(area)
    }
    static func sourceTop(area: Int) -> CGFloat {
        mapScenery(area: area) != nil ? 0 : (area == 2 || area == 4 ? 0.5 : 0.35)
    }
    static func sceneryBlend(fromBottom height: CGFloat, x: CGFloat) -> CGFloat {
        let edge = blendHeight / 2 + sin(x * .pi / 195) * 16 + sin(x * 0.083) * 5
        let value = min(1, max(0, (height - edge + 20) / 40))
        return value * value * (3 - 2 * value)
    }
    static func roadX(area: Int, fraction: CGFloat) -> CGFloat {
        // These anchors follow the street painted into each map, bottom to top.
        // Markers follow the illustration; no independent road is drawn over it.
        let xs: [CGFloat]
        if let scenery = mapScenery(area: area) {
            xs = scenery.markerPositions.map { $0.x / 390 }
        } else if area == 2 || area == 4 {
            xs = [0.50, 0.50, 0.52, 0.58, 0.64, 0.61, 0.52, 0.48, 0.50]
        } else {
            xs = [0.50, 0.51, 0.52, 0.55, 0.61, 0.65, 0.68, 0.60, 0.47]
        }
        let value = min(1, max(0, fraction)) * CGFloat(xs.count - 1)
        let index = min(xs.count - 2, Int(value))
        return (xs[index] + (xs[index + 1] - xs[index]) * (value - CGFloat(index))) * 390
    }
    static func roadX(at height: CGFloat) -> CGFloat {
        let segment = max(0, Int(floor((height + blendHeight / 2) / segmentHeight)))
        let lower = CGFloat(segment) * segmentHeight - blendHeight / 2
        let current = roadX(area: artworkArea(segment: segment), fraction: (height - lower) / tileHeight)
        guard segment > 0 else { return current }
        let previous = roadX(area: artworkArea(segment: segment - 1), fraction: (height - lower + segmentHeight) / tileHeight)
        let blend = sceneryBlend(fromBottom: height - lower, x: (previous + current) / 2)
        return previous + (current - previous) * blend
    }
    static func position(_ level: Int) -> CGPoint {
        let y = 292 + CGFloat(level) * 96
        return CGPoint(x: roadX(at: y), y: y)
    }
    static func scrollOffset(_ value: CGFloat) -> CGFloat {
        min(136, max(428 - position(LevelCatalog.levelCount - 1).y, value))
    }
    static func focusedOffset(local: Int) -> CGFloat {
        scrollOffset(428 - position(min(LevelCatalog.levelCount - 1, max(0, local))).y)
    }
    static func level(at height: CGFloat) -> Int {
        min(LevelCatalog.levelCount - 1, max(0, Int(((height - 292) / 96).rounded())))
    }
    static func visibleSegments(offset: CGFloat) -> ClosedRange<Int> {
        let first = max(0, Int(floor((0 - offset - blendHeight) / segmentHeight)))
        let last = max(first, Int(ceil((844 - offset + blendHeight) / segmentHeight)))
        return first...last
    }
    static func variant(_ segment: Int, salt: Int = 0) -> Int {
        var seed = UInt64(max(0, segment)) &* 6364136223846793005 &+ UInt64(max(0, salt)) &* 1442695040888963407 &+ 42
        seed = (seed ^ (seed >> 30)) &* 0xbf58476d1ce4e5b9
        return Int((seed ^ (seed >> 27)) % 997)
    }
    static func visitorFoot(segment: Int, slot: Int) -> CGPoint? {
        let target = CGFloat(segment) * segmentHeight + 80 + CGFloat(slot) * 155
        guard target >= position(0).y, target < position(LevelCatalog.levelCount - 1).y else { return nil }
        let index = min(LevelCatalog.levelCount - 2, max(0, Int(floor((target - 292) / 96))))
        let a = position(index), b = position(index + 1)
        let middleY = (a.y + b.y) / 2
        let centerX = roadX(at: middleY)
        let options = [max(116, centerX - 34), min(350, centerX + 34)]
        func clearance(_ x: CGFloat) -> CGFloat {
            min(hypot(x - a.x, middleY - a.y), hypot(x - b.x, middleY - b.y))
        }
        let x = options.max { clearance($0) < clearance($1) }!
        guard clearance(x) >= 50 else { return nil }
        return CGPoint(x: x, y: middleY - 24)
    }

    static func souvenirPosition(markers: [CGPoint]) -> CGPoint? {
        guard let start = markers.first else { return nil }
        let candidates = [CGFloat(-42), CGFloat(42)].map { CGPoint(x: start.x + $0, y: start.y + 20) }
            .filter { $0.x >= 160 && $0.x <= 360 }
        return candidates.max { a, b in
            let first = markers.map { hypot($0.x - a.x, $0.y - a.y) }.min() ?? 0
            let second = markers.map { hypot($0.x - b.x, $0.y - b.y) }.min() ?? 0
            return first < second
        }
    }
}
