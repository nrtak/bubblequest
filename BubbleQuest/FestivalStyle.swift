import SpriteKit
import UIKit

/// Shared, cached finishes for the festival's illustrated interface.
/// Luminance textures shade each node's own color, including area-specific lacquer.
enum FestivalStyle {
    enum Material: Equatable { case panel, wood, lacquer, brass, reward }
    static let ink = UIColor(red: 0.16, green: 0.21, blue: 0.32, alpha: 1)
    static let cream = UIColor(red: 1, green: 0.94, blue: 0.79, alpha: 1)
    static let brass = UIColor(red: 0.90, green: 0.73, blue: 0.43, alpha: 1)
    static let coral = UIColor(red: 0.96, green: 0.40, blue: 0.33, alpha: 1)
    static var quiet: Bool { UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled }

    private static let smooth = texture(wood: false)
    private static let grain = texture(wood: true)

    private static func texture(wood: Bool) -> SKTexture {
        let format = UIGraphicsImageRendererFormat(); format.scale = 1; format.opaque = true
        let image = UIGraphicsImageRenderer(size: CGSize(width: 128, height: 128), format: format).image { renderer in
            let context = renderer.cgContext
            UIColor.white.setFill(); context.fill(CGRect(x: 0, y: 0, width: 128, height: 128))
            let colors = [UIColor(white: 1, alpha: 1).cgColor,
                          UIColor(white: wood ? 0.90 : 0.95, alpha: 1).cgColor,
                          UIColor(white: wood ? 0.70 : 0.76, alpha: 1).cgColor] as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.22, 1]) {
                context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: 128), options: [])
            }
            context.setStrokeColor(UIColor.white.withAlphaComponent(0.24).cgColor)
            context.setLineWidth(2); context.move(to: CGPoint(x: 4, y: 3)); context.addLine(to: CGPoint(x: 124, y: 3)); context.strokePath()
            guard wood else { return }
            // Fixed grain is reproducible and never adds per-frame drawing work.
            for index in 0..<18 {
                let y = CGFloat(index) * 7 + 5
                context.setStrokeColor(UIColor(white: index % 3 == 0 ? 0.2 : 1, alpha: 0.10).cgColor)
                context.setLineWidth(index % 3 == 0 ? 0.8 : 0.5)
                context.move(to: CGPoint(x: 0, y: y))
                context.addCurve(to: CGPoint(x: 128, y: y + 1), control1: CGPoint(x: 34, y: y - 3), control2: CGPoint(x: 79, y: y + 4))
                context.strokePath()
            }
        }
        let texture = SKTexture(image: image); texture.filteringMode = .linear
        return texture
    }

    static func finish(_ node: SKShapeNode, as material: Material) {
        node.fillTexture = material == .wood ? grain : smooth
        node.isAntialiased = true
        switch material {
        case .panel: node.strokeColor = cream.withAlphaComponent(0.65); node.lineWidth = 1.25
        case .wood: node.strokeColor = brass; node.lineWidth = 1.5
        case .lacquer: node.strokeColor = brass; node.lineWidth = 1.75
        case .brass: node.strokeColor = UIColor(red: 0.47, green: 0.32, blue: 0.15, alpha: 1); node.lineWidth = 1
        case .reward: node.strokeColor = cream; node.lineWidth = 1.5
        }
    }

    static func reveal(_ node: SKNode, quiet: Bool = FestivalStyle.quiet) {
        node.removeAction(forKey: "interface-reveal")
        guard !quiet else { node.alpha = 1; return }
        node.alpha = 0.15
        let fade = SKAction.fadeIn(withDuration: 0.18); fade.timingMode = .easeOut
        node.run(fade, withKey: "interface-reveal")
    }

}
