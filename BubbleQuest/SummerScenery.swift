import CoreGraphics

enum SummerScenery: Int, CaseIterable {
    case river, tea, beach, lake, hill

    static func forArea(_ area: Int) -> SummerScenery? {
        guard area >= 5, area < LevelCatalog.levelCount / LevelCatalog.levelsPerArea else { return nil }
        return SummerScenery(rawValue: (area - 5) % allCases.count)
    }

    var title: String {
        switch self {
        case .river: return "Summer River"
        case .tea: return "Tea Countryside"
        case .beach: return "Seaside Festival"
        case .lake: return "Mountain Lake"
        case .hill: return "Coastal Hill"
        }
    }

    var background: String {
        switch self {
        case .river: return "festival-riverside"
        case .tea: return "festival-tea-fields"
        case .beach: return "festival-beach"
        case .lake: return "festival-summer-water"
        case .hill: return "festival-coastal-hill"
        }
    }

    var mapArtwork: String { self == .hill ? "festival-hill-map" : "festival-summer-map-atlas" }

    var mapRegion: CGRect {
        guard self != .hill else { return CGRect(x: 0, y: 0, width: 1, height: 1) }
        let x: CGFloat = rawValue % 2 == 0 ? 0 : 520
        let top: CGFloat = rawValue < 2 ? 0 : 774
        let height: CGFloat = rawValue < 2 ? 760 : 762
        // Exclude the review sheet's gutters when sampling its four map paintings.
        return CGRect(x: (x + 1) / 1024, y: (1536 - top - height + 1) / 1536,
                      width: 502 / 1024, height: (height - 2) / 1536)
    }

    var markerPositions: [CGPoint] {
        let xs: [CGFloat]
        switch self {
        case .river: xs = [249, 240, 214, 187, 160, 143, 145, 165, 184, 188]
        case .tea: xs = [229, 215, 192, 165, 143, 145, 168, 189, 185, 168]
        case .beach: xs = [253, 247, 234, 216, 202, 195, 196, 192, 184, 175]
        case .lake: xs = [242, 239, 227, 208, 188, 173, 165, 165, 176, 189]
        case .hill: xs = [245, 256, 258, 224, 196, 209, 260, 275, 245, 245]
        }
        return xs.enumerated().map { CGPoint(x: $0.element, y: 235 + CGFloat($0.offset) * 38) }
    }
}
