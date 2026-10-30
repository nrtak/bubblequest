import SpriteKit
import SwiftUI
import UIKit

/// Artwork, native glass, and sharp SpriteKit text occupy separate layers.
/// Keeping the SKView in front preserves the existing map gestures and hit targets.
struct FestivalGlassView: UIViewRepresentable {
    let scene: FestivalScene

    func makeUIView(context: Context) -> FestivalGlassHost { FestivalGlassHost(scene: scene) }
    func updateUIView(_ view: FestivalGlassHost, context: Context) { scene.refreshGlassPresentation() }
    static func dismantleUIView(_ view: FestivalGlassHost, coordinator: ()) { view.detach() }
}

enum FestivalGlassPolicy {
    static func enabled(menu: String, preference: Bool, reduceTransparency: Bool, highContrast: Bool) -> Bool {
        preference && !reduceTransparency && !highContrast &&
            ["title", "map", "settings", "control-settings", "sound-levels"].contains(menu)
    }
}

final class FestivalGlassHost: UIView {
    let spriteView = SKView()
    private let artwork = UIView()
    private let surfaces = UIView()
    private weak var festival: FestivalScene?
    private var images: [ObjectIdentifier: Backdrop] = [:]
    private var effects: [ObjectIdentifier: Surface] = [:]
    private(set) var isPresentingGlass = false
    var surfaceCount: Int { effects.count }
    var artworkCount: Int { images.count }

    private final class Backdrop {
        weak var node: SKSpriteNode?
        let image = UIImageView()
        let wasHidden: Bool
        init(_ node: SKSpriteNode, image source: UIImage) {
            self.node = node; wasHidden = node.isHidden
            image.image = source; image.contentMode = .scaleToFill
            image.isUserInteractionEnabled = false
        }
        func restore() { node?.isHidden = wasHidden; image.removeFromSuperview() }
    }

    private final class Surface {
        weak var node: SKShapeNode?
        let effect: UIVisualEffectView
        let fill: UIColor
        let stroke: UIColor
        let texture: SKTexture?
        let lineWidth: CGFloat

        init(_ node: SKShapeNode) {
            self.node = node; fill = node.fillColor; stroke = node.strokeColor
            texture = node.fillTexture; lineWidth = node.lineWidth
            let role = node.userData?["glassRole"] as? String ?? "panel"
            let tint = role == "light" ? FestivalStyle.cream : role == "primary" ? FestivalStyle.coral : FestivalStyle.ink
            if #available(iOS 26.0, *) {
                let glass = UIGlassEffect(style: .regular)
                glass.tintColor = tint.withAlphaComponent(role == "primary" ? 0.86 : 0.68)
                effect = UIVisualEffectView(effect: glass)
            } else {
                // Earlier iOS versions get the system's frosted material.
                effect = UIVisualEffectView(effect: UIBlurEffect(style: role == "light" ? .systemMaterialLight : .systemMaterialDark))
                effect.contentView.backgroundColor = tint.withAlphaComponent(0.55)
            }
            effect.overrideUserInterfaceStyle = role == "light" ? .light : .dark
            effect.isUserInteractionEnabled = false
            effect.layer.borderColor = UIColor.white.withAlphaComponent(0.32).cgColor
            effect.layer.borderWidth = 0.7
            effect.clipsToBounds = true
            // A subtle dark wash keeps white labels legible on bright street art.
            let wash = UIView(); wash.backgroundColor = tint.withAlphaComponent(role == "primary" ? 0.20 : 0.16)
            wash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            wash.frame = effect.bounds; wash.isUserInteractionEnabled = false
            effect.contentView.addSubview(wash)
            node.fillTexture = nil; node.fillColor = .clear
            node.strokeColor = .clear
        }

        func restore() {
            node?.fillColor = fill; node?.strokeColor = stroke
            node?.fillTexture = texture; node?.lineWidth = lineWidth
            effect.removeFromSuperview()
        }
    }

    init(scene: FestivalScene) {
        super.init(frame: .zero)
        festival = scene; backgroundColor = .black
        artwork.isUserInteractionEnabled = false; surfaces.isUserInteractionEnabled = false
        addSubview(artwork); addSubview(surfaces); addSubview(spriteView)
        spriteView.allowsTransparency = true; spriteView.isOpaque = false
        spriteView.backgroundColor = .clear
        scene.backgroundColor = .clear; scene.scaleMode = .aspectFit
        scene.glassHost = self
        spriteView.presentScene(scene)
        NotificationCenter.default.addObserver(self, selector: #selector(accessibilityChanged),
                                               name: UIAccessibility.reduceTransparencyStatusDidChangeNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(accessibilityChanged),
                                               name: UIAccessibility.darkerSystemColorsStatusDidChangeNotification, object: nil)
    }

    required init?(coder: NSCoder) { fatalError("Use init(scene:)") }
    deinit { NotificationCenter.default.removeObserver(self) }

    override func layoutSubviews() {
        super.layoutSubviews()
        artwork.frame = bounds; surfaces.frame = bounds; spriteView.frame = bounds
        spriteView.layoutIfNeeded()
        festival?.refreshGlassPresentation()
    }

    @objc private func accessibilityChanged() { festival?.refreshGlassPresentation() }

    /// Restoring source nodes also makes snapshots and the classic switch reversible.
    func reset() {
        images.values.forEach { $0.restore() }; images.removeAll()
        effects.values.forEach { $0.restore() }; effects.removeAll()
        isPresentingGlass = false
    }

    func detach() {
        reset(); festival?.glassHost = nil
        spriteView.presentScene(nil); festival = nil
    }

    func synchronize(menu: SKNode, scene: FestivalScene) {
        guard bounds.width > 0, bounds.height > 0 else { return }
        var backgrounds: [SKSpriteNode] = []
        var panels: [SKShapeNode] = []
        func collect(_ parent: SKNode) {
            for child in parent.children {
                if let sprite = child as? SKSpriteNode, sprite.userData?["glassImage"] is UIImage { backgrounds.append(sprite) }
                if let shape = child as? SKShapeNode, shape.userData?["glassRole"] is String,
                   let box = shape.path?.boundingBox, box.width >= 40, box.height >= 40 { panels.append(shape) }
                collect(child)
            }
        }
        collect(menu)
        let backgroundIDs = Set(backgrounds.map(ObjectIdentifier.init))
        let panelIDs = Set(panels.map(ObjectIdentifier.init))
        for key in Array(images.keys) where !backgroundIDs.contains(key) { images.removeValue(forKey: key)?.restore() }
        for key in Array(effects.keys) where !panelIDs.contains(key) { effects.removeValue(forKey: key)?.restore() }
        UIView.performWithoutAnimation {
            for node in backgrounds {
                let key = ObjectIdentifier(node)
                guard let source = node.userData?["glassImage"] as? UIImage else { continue }
                let entry: Backdrop
                if let existing = images[key] { entry = existing }
                else { entry = Backdrop(node, image: source); images[key] = entry; artwork.addSubview(entry.image) }
                let frame = viewFrame(node, local: CGRect(x: -node.size.width * node.anchorPoint.x,
                                                         y: -node.size.height * node.anchorPoint.y,
                                                         width: node.size.width, height: node.size.height), scene: scene)
                if entry.image.frame != frame { entry.image.frame = frame }
                entry.image.layer.zPosition = worldZ(node)
                entry.image.isHidden = !ancestorsVisible(node, stoppingAt: menu)
                node.isHidden = true
            }
            for node in panels {
                let key = ObjectIdentifier(node)
                let entry: Surface
                if let existing = effects[key] { entry = existing }
                else { entry = Surface(node); effects[key] = entry; surfaces.addSubview(entry.effect) }
                guard let local = node.path?.boundingBox else { continue }
                let frame = viewFrame(node, local: local, scene: scene)
                if entry.effect.frame != frame { entry.effect.frame = frame }
                let scale = entry.effect.frame.height / max(1, local.height)
                let role = node.userData?["glassRole"] as? String
                entry.effect.layer.cornerRadius = min(role == "panel" ? 20 * scale : 28 * scale, entry.effect.bounds.height / 2)
                entry.effect.layer.zPosition = worldZ(node)
                entry.effect.isHidden = node.isHidden || !ancestorsVisible(node, stoppingAt: menu)
            }
        }
        isPresentingGlass = true
    }

    private func ancestorsVisible(_ node: SKNode, stoppingAt root: SKNode) -> Bool {
        var current = node.parent
        while let ancestor = current {
            if ancestor.isHidden || ancestor.alpha == 0 { return false }
            if ancestor === root { break }
            current = ancestor.parent
        }
        return true
    }

    private func worldZ(_ node: SKNode) -> CGFloat {
        var z: CGFloat = 0; var current: SKNode? = node
        while let value = current { z += value.zPosition; current = value.parent }
        return z
    }

    private func viewFrame(_ node: SKNode, local: CGRect, scene: SKScene) -> CGRect {
        let corners = [CGPoint(x: local.minX, y: local.minY), CGPoint(x: local.maxX, y: local.maxY)]
            .map { scene.convertPoint(toView: node.convert($0, to: scene)) }
        return CGRect(x: min(corners[0].x, corners[1].x), y: min(corners[0].y, corners[1].y),
                      width: abs(corners[1].x - corners[0].x), height: abs(corners[1].y - corners[0].y))
    }
}
