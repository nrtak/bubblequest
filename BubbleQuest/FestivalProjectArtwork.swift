import SpriteKit
import UIKit

/// Painted five-state props share the same footprint and baseline as the map cast.
enum FestivalProjectArtwork {
    private struct Frame: Decodable { let x: Double; let y: Double; let width: Double; let height: Double }
    private struct Atlas: Decodable { let image: String; let frames: [Frame] }
    private static let catalog: [String: Atlas] = {
        guard let url = Bundle.main.url(forResource: "festival-project-artwork-v3", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let values = try? JSONDecoder().decode([String: Atlas].self, from: data) else { return [:] }
        return values
    }()
    private static var textures: [String: SKTexture] = [:]
    static var imageNames: [String] { catalog.values.map(\.image).sorted() }

    static func node(style: FestivalProject.DisplayStyle, stage: Int, fitting size: CGSize) -> SKSpriteNode? {
        let key = String(describing: style)
        guard let atlas = catalog[key] else { return nil }
        let index = min(4, max(0, stage))
        guard atlas.frames.indices.contains(index) else { return nil }
        let source: SKTexture
        if let cached = textures[key] { source = cached }
        else {
            guard let path = Bundle.main.path(forResource: atlas.image, ofType: nil),
                  let image = UIImage(contentsOfFile: path) else { return nil }
            source = SKTexture(image: image); source.filteringMode = .linear
            if textures.count >= 3 { textures.removeAll() }
            textures[key] = source
        }
        let frame = atlas.frames[index]
        let region = CGRect(x: CGFloat(frame.x), y: CGFloat(frame.y), width: CGFloat(frame.width), height: CGFloat(frame.height))
        let texture = SKTexture(rect: region, in: source); texture.filteringMode = .linear
        let pixels = CGSize(width: source.size().width * region.width, height: source.size().height * region.height)
        let scale = min(size.width / pixels.width, size.height / pixels.height)
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: pixels.width * scale, height: pixels.height * scale))
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0); sprite.name = "project-painted-illustration"
        return sprite
    }
}
