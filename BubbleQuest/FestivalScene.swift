import SpriteKit
import UIKit

final class FestivalScene: SKScene {
    private let palette: [UIColor] = [.systemPink, .systemTeal, .systemYellow, .systemPurple, .systemOrange]
    private let symbols = ["✿", "◆", "★", "●", "♥"]
    private let radius: CGFloat = 21
    private let left: CGFloat = 48
    private let ceiling: CGFloat = 688
    private let origin = CGPoint(x: 195, y: 176)
    private var board = BubbleBoard()
    private var nodes: [Cell: SKNode] = [:]
    private let playfield = SKNode()
    private let guide = SKNode()
    private let hud = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let status = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var loaded: SKNode?
    private var nextNode: SKNode?
    private var projectile: SKNode?
    private var velocity = CGVector.zero
    private var previousTime: TimeInterval = 0
    private var aim = CGVector(dx: 0, dy: 1)
    private var currentColor = 0
    private var nextColor = 1
    private var shots = 24
    private var level = 0
    private var score = 0
    private var finished = false
    private var won = false
    private var aiming = false
    private var levelMenu: SKNode?
    private let levelNames = ["Lantern Street", "Lantern Lane", "Summer Courtyard", "Festival Square", "Firework Night"]

    override func didMove(to view: SKView) {
        guard children.isEmpty else { return }
        backgroundColor = UIColor(red: 0.12, green: 0.14, blue: 0.28, alpha: 1)
        decorate()
        addChild(playfield)
        addChild(guide)
        hud.fontSize = 19
        hud.position = CGPoint(x: 195, y: 735)
        addChild(hud)
        status.fontSize = 14
        status.position = CGPoint(x: 195, y: 279)
        addChild(status)
        button("↻", name: "retry", x: 50, y: 80)
        button("Swap", name: "swap", x: 195, y: 80)
        button(UserDefaults.standard.bool(forKey: "muted") ? "Muted" : "Sound", name: "sound", x: 340, y: 80)
        level = min(4, max(0, UserDefaults.standard.integer(forKey: "unlockedLevel")))
        startLevel()
        if !ProcessInfo.processInfo.arguments.contains("--gameplay-preview") { showLevels() }
    }

    private func label(_ text: String, size: CGFloat, point: CGPoint, parent: SKNode? = nil) {
        let node = SKLabelNode(fontNamed: "AvenirNext-Bold")
        node.text = text
        node.fontSize = size
        node.position = point
        (parent ?? self).addChild(node)
    }

    private func decorate() {
        label("Bubble Quest", size: 29, point: CGPoint(x: 195, y: 785))
        let line = SKShapeNode(rectOf: CGSize(width: 342, height: 2))
        line.fillColor = UIColor.white.withAlphaComponent(0.15)
        line.position = CGPoint(x: 195, y: ceiling + radius + 4)
        addChild(line)
        for x in stride(from: 30, through: 370, by: 68) {
            let lantern = SKShapeNode(rectOf: CGSize(width: 23, height: 31), cornerRadius: 9)
            lantern.position = CGPoint(x: x, y: 760)
            lantern.fillColor = .systemOrange
            lantern.strokeColor = .systemYellow
            lantern.alpha = 0.45
            lantern.zPosition = -1
            addChild(lantern)
        }
        let companionSheet = SKTexture(imageNamed: "festival-companions")
        for (index, x) in [CGFloat(74), CGFloat(319)].enumerated() {
            let texture = SKTexture(rect: CGRect(x: CGFloat(index) * 0.5, y: 0, width: 0.5, height: 1), in: companionSheet)
            let companion = SKSpriteNode(texture: texture, size: CGSize(width: 74, height: 148))
            companion.position = CGPoint(x: x, y: 207)
            companion.name = "companion-\(index)"
            addChild(companion)
        }
        let place = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        place.name = "place"
        place.fontSize = 15
        place.position = CGPoint(x: 195, y: 115)
        addChild(place)
        button("Levels", name: "levels", x: 340, y: 785)
        let cannon = SKShapeNode(rectOf: CGSize(width: 65, height: 48), cornerRadius: 12)
        cannon.position = CGPoint(x: origin.x, y: origin.y - 18)
        cannon.fillColor = UIColor(red: 0.45, green: 0.28, blue: 0.24, alpha: 1)
        cannon.strokeColor = .systemOrange
        addChild(cannon)
    }

    private func button(_ title: String, name: String, x: CGFloat, y: CGFloat) {
        let box = SKShapeNode(rectOf: CGSize(width: 82, height: 42), cornerRadius: 18)
        box.fillColor = UIColor.white.withAlphaComponent(0.1)
        box.strokeColor = UIColor.white.withAlphaComponent(0.25)
        box.position = CGPoint(x: x, y: y)
        box.name = name
        let titleNode = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        titleNode.text = title
        titleNode.fontSize = 15
        titleNode.verticalAlignmentMode = .center
        box.addChild(titleNode)
        addChild(box)
    }

    private func bubble(_ color: Int) -> SKNode {
        let node = SKShapeNode(circleOfRadius: radius - 1)
        node.fillColor = palette[color]
        node.strokeColor = .white.withAlphaComponent(0.7)
        node.lineWidth = 2
        let symbol = SKLabelNode(fontNamed: "AvenirNext-Bold")
        symbol.text = symbols[color]
        symbol.fontSize = 22
        symbol.fontColor = .white
        symbol.verticalAlignmentMode = .center
        node.addChild(symbol)
        return node
    }

    private func point(_ cell: Cell) -> CGPoint {
        CGPoint(x: left + CGFloat(cell.column) * radius * 2 + CGFloat(cell.row % 2) * radius,
                y: ceiling - CGFloat(cell.row) * radius * sqrt(3))
    }

    private func startLevel() {
        childNode(withName: "result")?.removeFromParent()
        projectile?.removeFromParent()
        projectile = nil
        guide.removeAllChildren()
        playfield.removeAllChildren()
        nodes.removeAll()
        board = .level(level)
        shots = [24, 28, 30, 34, 38][level]
        score = 0
        finished = false
        aiming = false
        for (cell, color) in board.bubbles {
            let node = bubble(color)
            node.position = point(cell)
            playfield.addChild(node)
            nodes[cell] = node
        }
        currentColor = availableColor()
        nextColor = availableColor()
        reload()
        refreshHUD()
        (childNode(withName: "place") as? SKLabelNode)?.text = levelNames[level]
    }

    private func showLevels() {
        guard levelMenu == nil else { return }
        aiming = false
        guide.removeAllChildren()
        let overlay = SKShapeNode(rectOf: size)
        overlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.fillColor = UIColor(red: 0.12, green: 0.14, blue: 0.28, alpha: 0.98)
        overlay.strokeColor = .clear
        overlay.zPosition = 40
        addChild(overlay)
        levelMenu = overlay
        label("Festival adventures", size: 27, point: CGPoint(x: 0, y: 235), parent: overlay)
        label("Pick a stop and clear its bubbles", size: 15, point: CGPoint(x: 0, y: 203), parent: overlay)
        let unlocked = min(4, max(0, UserDefaults.standard.integer(forKey: "unlockedLevel")))
        for index in 0..<5 {
            let entry = SKShapeNode(rectOf: CGSize(width: 320, height: 66), cornerRadius: 18)
            entry.position = CGPoint(x: 0, y: 135 - CGFloat(index) * 82)
            entry.fillColor = index <= unlocked ? UIColor.systemTeal.withAlphaComponent(0.2) : UIColor.white.withAlphaComponent(0.04)
            entry.strokeColor = index <= unlocked ? .systemTeal : .darkGray
            entry.name = index <= unlocked ? "level-\(index)" : "locked"
            overlay.addChild(entry)
            label("\(index + 1) · \(levelNames[index])", size: 19, point: CGPoint(x: 0, y: 5), parent: entry)
            let best = UserDefaults.standard.integer(forKey: "bestScore-\(index)")
            label(index > unlocked ? "Clear the previous stop to unlock" : best > 0 ? "Best score: \(best)" : "Ready to play", size: 12, point: CGPoint(x: 0, y: -18), parent: entry)
        }
        let close = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        close.text = "Back to game"
        close.name = "close-levels"
        close.fontSize = 19
        close.position = CGPoint(x: 0, y: -285)
        overlay.addChild(close)
    }

    private func availableColor() -> Int {
        Array(Set(board.bubbles.values)).sorted().randomElement() ?? 0
    }

    private func reload() {
        loaded?.removeFromParent()
        nextNode?.removeFromParent()
        let node = bubble(currentColor)
        node.position = origin
        addChild(node)
        loaded = node
        let next = bubble(nextColor)
        next.setScale(0.75)
        next.position = CGPoint(x: 252, y: 158)
        addChild(next)
        nextNode = next
    }

    private func refreshHUD() {
        hud.text = "Level \(level + 1)    •    Shots \(shots)    •    \(score)"
        status.text = "Drag to aim • Release to pop"
    }

    private func updateAim(_ target: CGPoint) {
        let dx = target.x - origin.x
        let dy = max(70, target.y - origin.y)
        let length = hypot(dx, dy)
        aim = CGVector(dx: dx / length, dy: dy / length)
        guide.removeAllChildren()
        var position = origin
        var direction = aim
        for step in 0..<160 {
            position.x += direction.dx * 7
            position.y += direction.dy * 7
            if position.x < left { position.x = left * 2 - position.x; direction.dx *= -1 }
            if position.x > 342 { position.x = 684 - position.x; direction.dx *= -1 }
            if position.y >= ceiling || board.bubbles.keys.contains(where: { hypot(point($0).x - position.x, point($0).y - position.y) < radius * 2 }) { break }
            if step % 3 == 0 {
                let dot = SKShapeNode(circleOfRadius: 2.5)
                dot.fillColor = .white
                dot.strokeColor = .clear
                dot.alpha = 0.65
                dot.position = position
                guide.addChild(dot)
            }
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let location = touches.first?.location(in: self) else { return }
        let names = nodes(at: location).compactMap { $0.name ?? $0.parent?.name }
        if levelMenu != nil {
            if names.contains("close-levels") {
                levelMenu?.removeFromParent()
                levelMenu = nil
            } else if let name = names.first(where: { $0.hasPrefix("level-") }), let selected = Int(name.dropFirst(6)) {
                levelMenu?.removeFromParent()
                levelMenu = nil
                level = selected
                startLevel()
            }
            return
        }
        if names.contains("levels") { showLevels(); return }
        if names.contains("retry") { startLevel(); return }
        if names.contains("sound") {
            let muted = !UserDefaults.standard.bool(forKey: "muted")
            UserDefaults.standard.set(muted, forKey: "muted")
            if let box = childNode(withName: "sound"), let label = box.children.first as? SKLabelNode { label.text = muted ? "Muted" : "Sound" }
            return
        }
        if finished {
            if won { level = min(4, level + 1) }
            startLevel()
            return
        }
        guard projectile == nil else { return }
        if names.contains("swap") {
            swap(&currentColor, &nextColor)
            reload()
            return
        }
        guard location.y > 290 else { return }
        aiming = true
        updateAim(location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aiming, let point = touches.first?.location(in: self) else { return }
        updateAim(point)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        aiming = false
        guide.removeAllChildren()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aiming, !finished, projectile == nil else { return }
        aiming = false
        guide.removeAllChildren()
        projectile = loaded
        loaded = nil
        velocity = CGVector(dx: aim.dx * 620, dy: aim.dy * 620)
        shots -= 1
        refreshHUD()
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = previousTime == 0 ? 0 : min(currentTime - previousTime, 1.0 / 30)
        previousTime = currentTime
        guard levelMenu == nil, let shot = projectile else { return }
        // Small steps keep fast shots from tunneling through the grid.
        let steps = max(1, Int(ceil(delta * 620 / 5)))
        for _ in 0..<steps {
            shot.position.x += velocity.dx * CGFloat(delta) / CGFloat(steps)
            shot.position.y += velocity.dy * CGFloat(delta) / CGFloat(steps)
            if shot.position.x < left { shot.position.x = left * 2 - shot.position.x; velocity.dx *= -1 }
            if shot.position.x > 342 { shot.position.x = 684 - shot.position.x; velocity.dx *= -1 }
            let collision = board.bubbles.keys.filter {
                hypot(point($0).x - shot.position.x, point($0).y - shot.position.y) <= radius * 2 - 1
            }.min { distance(point($0), shot.position) < distance(point($1), shot.position) }
            if shot.position.y >= ceiling || collision != nil {
                settle(shot, collision: collision)
                return
            }
        }
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private func settle(_ shot: SKNode, collision: Cell?) {
        let candidates = collision.map { BubbleBoard.neighbors(of: $0) } ?? (0..<8).map { Cell(row: 0, column: $0) }
        let free = candidates.filter { board.bubbles[$0] == nil }
        guard let cell = free.min(by: { distance(point($0), shot.position) < distance(point($1), shot.position) }) else {
            shot.removeFromParent()
            projectile = nil
            finish(success: false)
            return
        }
        shot.removeFromParent()
        shot.position = point(cell)
        playfield.addChild(shot)
        nodes[cell] = shot
        projectile = nil
        let result = board.place(currentColor, at: cell)
        for match in result.matched {
            nodes.removeValue(forKey: match)?.run(.sequence([.group([.scale(to: 1.4, duration: 0.12), .fadeOut(withDuration: 0.12)]), .removeFromParent()]))
        }
        for dropped in result.dropped {
            nodes.removeValue(forKey: dropped)?.run(.sequence([.group([.moveBy(x: 0, y: -650, duration: 0.65), .rotate(byAngle: 2, duration: 0.65), .fadeOut(withDuration: 0.65)]), .removeFromParent()]))
        }
        score += result.matched.count * 10 + result.dropped.count * 20
        if !result.matched.isEmpty {
            for index in 0..<2 {
                childNode(withName: "companion-\(index)")?.run(.sequence([.moveBy(x: 0, y: 7, duration: 0.12), .moveBy(x: 0, y: -7, duration: 0.12)]))
            }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            if !UserDefaults.standard.bool(forKey: "muted") { run(.playSoundFileNamed("pop.wav", waitForCompletion: false)) }
        }
        if board.bubbles.isEmpty { finish(success: true); return }
        if shots <= 0 || board.bubbles.keys.contains(where: { point($0).y < 300 }) { finish(success: false); return }
        currentColor = Set(board.bubbles.values).contains(nextColor) ? nextColor : availableColor()
        nextColor = availableColor()
        reload()
        refreshHUD()
    }

    private func finish(success: Bool) {
        finished = true
        won = success
        aiming = false
        guide.removeAllChildren()
        loaded?.removeFromParent()
        nextNode?.removeFromParent()
        if success {
            let bestKey = "bestScore-\(level)"
            UserDefaults.standard.set(max(score, UserDefaults.standard.integer(forKey: bestKey)), forKey: bestKey)
            let unlocked = max(UserDefaults.standard.integer(forKey: "unlockedLevel"), min(4, level + 1))
            UserDefaults.standard.set(unlocked, forKey: "unlockedLevel")
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        let panel = SKShapeNode(rectOf: CGSize(width: 330, height: 160), cornerRadius: 24)
        panel.name = "result"
        panel.fillColor = UIColor(red: 0.21, green: 0.22, blue: 0.39, alpha: 0.98)
        panel.strokeColor = .systemOrange
        panel.position = CGPoint(x: 195, y: 414)
        panel.zPosition = 20
        addChild(panel)
        label(success ? "Festival cheers! 🎉" : "Try another angle", size: 23, point: CGPoint(x: 0, y: 24), parent: panel)
        label("Score \(score)", size: 18, point: CGPoint(x: 0, y: -8), parent: panel)
        label(success ? (level == 4 ? "Tap to play again" : "Tap for the next level") : "Tap to retry", size: 16, point: CGPoint(x: 0, y: -43), parent: panel)
        hud.text = "Level \(level + 1)    •    Shots \(shots)    •    \(score)"
        status.text = success ? "Beautiful popping!" : "You can do it!"
    }
}
