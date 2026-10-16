import Foundation
import CoreGraphics

enum ChallengeMedal: String, Codable, CaseIterable {
    case noBoosters, bankArtist, threeStars
    var title: String {
        switch self {
        case .noBoosters: return "No boosters"
        case .bankArtist: return "Three bank matches"
        case .threeStars: return "Three stars"
        }
    }
    var symbol: String {
        switch self {
        case .noBoosters: return "hand.raised.fill"
        case .bankArtist: return "arrow.uturn.up"
        case .threeStars: return "star.fill"
        }
    }
    static func earned(stars: Int, boosters: Int, bankMatches: Int) -> Set<ChallengeMedal> {
        var result: Set<ChallengeMedal> = []
        if boosters == 0 { result.insert(.noBoosters) }
        if bankMatches >= 3 { result.insert(.bankArtist) }
        if stars == 3 { result.insert(.threeStars) }
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
    static let viewport = CGRect(x: 16, y: 326, width: 358, height: 356)
    static func position(_ local: Int) -> CGPoint {
        CGPoint(x: 195 + sin(CGFloat(local) * 0.95) * 112, y: 350 + CGFloat(local) * 66)
    }
    static func scrollOffset(_ value: CGFloat) -> CGFloat {
        min(0, max(viewport.maxY - position(19).y - 36, value))
    }
    static func focusedOffset(local: Int) -> CGFloat {
        scrollOffset(480 - position(min(19, max(0, local))).y)
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
