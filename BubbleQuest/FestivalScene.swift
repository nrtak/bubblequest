import SpriteKit
import UIKit

final class FestivalScene: SKScene {
    private let palette: [UIColor] = [UIColor(red: 1, green: 0.36, blue: 0.53, alpha: 1), .systemYellow, .systemBlue, .systemGreen, .systemPurple]
    private let radius: CGFloat = 21
    private let left: CGFloat = 48
    private let ceiling: CGFloat = 688
    private let origin = CGPoint(x: 195, y: 176)
    private var board = BubbleBoard()
    private var nodes: [Cell: SKNode] = [:]
    private let playfield = SKNode()
    private let guide = SKNode()
    private let hud = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let shotsLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
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
    private var backdrop: SKSpriteNode?
    private let levelNames = ["Lantern Street", "Lantern Lane", "Summer Courtyard", "Festival Square", "Firework Night"]

    override func didMove(to view: SKView) {
        guard children.isEmpty else { return }
        backgroundColor = UIColor(red: 0.12, green: 0.14, blue: 0.28, alpha: 1)
        decorate()
        addChild(playfield)
        addChild(guide)
        hud.fontSize = 21
        hud.position = CGPoint(x: 88, y: 752)
        addChild(hud)
        shotsLabel.fontSize = 21
        shotsLabel.position = CGPoint(x: 291, y: 752)
        addChild(shotsLabel)
        scoreLabel.fontSize = 15
        scoreLabel.position = CGPoint(x: 195, y: 317)
        addChild(scoreLabel)
        status.fontSize = 13
        status.position = CGPoint(x: 195, y: 279)
        addChild(status)
        button("↻", name: "retry", x: 50, y: 80)
        button("Swap", name: "swap", x: 195, y: 80)
        button(UserDefaults.standard.bool(forKey: "muted") ? "Muted" : "Sound", name: "sound", x: 340, y: 80)
        level = min(4, max(0, UserDefaults.standard.integer(forKey: "unlockedLevel")))
        if ProcessInfo.processInfo.arguments.contains("--dusk-preview") { level = 4 }
        startLevel()
        if ProcessInfo.processInfo.arguments.contains("--map-preview") { showLevels() }
        else if ProcessInfo.processInfo.arguments.contains("--gameplay-preview") { updateAim(CGPoint(x: 242, y: 600)) }
        else { showTitle() }
    }

    private func label(_ text: String, size: CGFloat, point: CGPoint, parent: SKNode? = nil) {
        let node = SKLabelNode(fontNamed: "AvenirNext-Bold")
        node.text = text
        node.fontSize = size
        node.position = point
        (parent ?? self).addChild(node)
    }

    private func decorate() {
        let background = SKSpriteNode(imageNamed: "festival-day")
        background.size = size
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.zPosition = -10
        addChild(background)
        backdrop = background
        panel(width: 132, height: 47, point: CGPoint(x: 88, y: 759), parent: self)
        panel(width: 132, height: 47, point: CGPoint(x: 291, y: 759), parent: self)
        panel(width: 256, height: 31, point: CGPoint(x: 195, y: 322), parent: self)
        panel(width: 278, height: 28, point: CGPoint(x: 195, y: 284), parent: self)
        let companionSheet = SKTexture(imageNamed: "festival-companions")
        for (index, x) in [CGFloat(74), CGFloat(319)].enumerated() {
            let texture = SKTexture(rect: CGRect(x: CGFloat(index) * 0.5, y: 0, width: 0.5, height: 1), in: companionSheet)
            let companion = SKSpriteNode(texture: texture, size: CGSize(width: 105, height: 210))
            companion.position = CGPoint(x: x, y: 185)
            companion.name = "companion-\(index)"
            addChild(companion)
        }
        let place = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        place.name = "place"
        place.fontSize = 15
        place.position = CGPoint(x: 195, y: 31)
        panel(width: 230, height: 24, point: CGPoint(x: 195, y: 36), parent: self)
        addChild(place)
        button("Map", name: "levels", x: 195, y: 759, width: 60)
        let base = SKShapeNode(rectOf: CGSize(width: 91, height: 20), cornerRadius: 7)
        base.position = CGPoint(x: origin.x, y: 128)
        base.fillColor = UIColor(red: 0.43, green: 0.23, blue: 0.13, alpha: 1)
        base.strokeColor = UIColor(red: 1, green: 0.77, blue: 0.42, alpha: 1)
        base.lineWidth = 3
        addChild(base)
        let barrelPath = CGMutablePath()
        barrelPath.move(to: CGPoint(x: -31, y: -39))
        barrelPath.addLine(to: CGPoint(x: -23, y: 16))
        barrelPath.addQuadCurve(to: CGPoint(x: 23, y: 16), control: CGPoint(x: 0, y: 25))
        barrelPath.addLine(to: CGPoint(x: 31, y: -39))
        barrelPath.closeSubpath()
        let cannon = SKShapeNode(path: barrelPath)
        cannon.position = origin
        cannon.fillColor = UIColor(red: 0.60, green: 0.33, blue: 0.16, alpha: 1)
        cannon.strokeColor = UIColor(red: 1, green: 0.79, blue: 0.43, alpha: 1)
        cannon.lineWidth = 3
        addChild(cannon)
        label("✿", size: 21, point: CGPoint(x: 0, y: -31), parent: cannon)
        label("Next", size: 12, point: CGPoint(x: 252, y: 127))
    }

    @discardableResult
    private func panel(width: CGFloat, height: CGFloat, point: CGPoint, parent: SKNode) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: min(20, height / 2))
        node.position = point
        node.fillColor = UIColor(red: 0.19, green: 0.22, blue: 0.39, alpha: 0.86)
        node.strokeColor = UIColor(red: 1, green: 0.90, blue: 0.73, alpha: 0.8)
        node.lineWidth = 1.5
        parent.addChild(node)
        return node
    }

    private func button(_ title: String, name: String, x: CGFloat, y: CGFloat, width: CGFloat = 82) {
        let box = SKShapeNode(rectOf: CGSize(width: width, height: 42), cornerRadius: 18)
        box.fillColor = UIColor(red: 0.23, green: 0.28, blue: 0.47, alpha: 0.9)
        box.strokeColor = UIColor(red: 1, green: 0.85, blue: 0.60, alpha: 1)
        box.lineWidth = 2
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
        let node = SKNode()
        let shadow = SKShapeNode(circleOfRadius: radius - 1)
        shadow.fillColor = palette[color].withAlphaComponent(0.45)
        shadow.strokeColor = .clear
        shadow.position = CGPoint(x: 0, y: -2)
        node.addChild(shadow)
        let body = SKShapeNode(circleOfRadius: radius - 1)
        body.fillColor = palette[color]
        body.strokeColor = UIColor.white.withAlphaComponent(0.9)
        body.lineWidth = 1.8
        node.addChild(body)
        let glow = SKShapeNode(ellipseOf: CGSize(width: 13, height: 6))
        glow.position = CGPoint(x: -7, y: 11)
        glow.zRotation = 0.5
        glow.fillColor = .white.withAlphaComponent(0.75)
        glow.strokeColor = .clear
        node.addChild(glow)
        node.addChild(bubbleIcon(color))
        return node
    }

    private func bubbleIcon(_ color: Int) -> SKNode {
        let icon = SKNode()
        func shape(_ path: CGPath) -> SKShapeNode {
            let piece = SKShapeNode(path: path)
            piece.fillColor = UIColor.white.withAlphaComponent(0.66)
            piece.strokeColor = UIColor.white.withAlphaComponent(0.9)
            piece.lineWidth = 1
            icon.addChild(piece)
            return piece
        }
        switch color {
        case 0:
            for petal in 0..<5 {
                let angle = CGFloat(petal) * .pi * 2 / 5
                let piece = shape(CGPath(ellipseIn: CGRect(x: -3.5, y: -5.5, width: 7, height: 11), transform: nil))
                piece.position = CGPoint(x: sin(angle) * 5.5, y: cos(angle) * 5.5)
                piece.zRotation = -angle
            }
        case 1:
            let star = CGMutablePath()
            for point in 0..<10 {
                let angle = CGFloat(point) * .pi / 5 + .pi / 2
                let length: CGFloat = point % 2 == 0 ? 12 : 5.5
                let vertex = CGPoint(x: cos(angle) * length, y: sin(angle) * length)
                if point == 0 { star.move(to: vertex) } else { star.addLine(to: vertex) }
            }
            star.closeSubpath()
            _ = shape(star)
        case 2:
            let drop = CGMutablePath()
            drop.move(to: CGPoint(x: 0, y: 12))
            drop.addCurve(to: CGPoint(x: 0, y: -11), control1: CGPoint(x: -18, y: -6), control2: CGPoint(x: -10, y: -11))
            drop.addCurve(to: CGPoint(x: 0, y: 12), control1: CGPoint(x: 10, y: -11), control2: CGPoint(x: 18, y: -6))
            _ = shape(drop)
        case 3:
            let leaf = shape(CGPath(ellipseIn: CGRect(x: -7, y: -11, width: 14, height: 22), transform: nil))
            leaf.zRotation = -0.5
            let vein = CGMutablePath()
            vein.move(to: CGPoint(x: -4, y: -8))
            vein.addLine(to: CGPoint(x: 4, y: 8))
            let line = SKShapeNode(path: vein)
            line.strokeColor = UIColor(red: 0.17, green: 0.47, blue: 0.21, alpha: 1)
            line.lineWidth = 1.5
            icon.addChild(line)
        default:
            for position in [CGPoint(x: -5, y: 5), CGPoint(x: 5, y: 5), CGPoint(x: 0, y: -3), CGPoint(x: 0, y: -10)] {
                let grape = shape(CGPath(ellipseIn: CGRect(x: -4, y: -4, width: 8, height: 8), transform: nil))
                grape.position = position
            }
        }
        return icon
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
        backdrop?.texture = SKTexture(imageNamed: level < 2 ? "festival-day" : "festival-dusk")
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

    private func makeMenu(background: String) -> SKNode {
        levelMenu?.removeFromParent()
        aiming = false
        guide.removeAllChildren()
        let overlay = SKNode()
        overlay.zPosition = 40
        addChild(overlay)
        levelMenu = overlay
        let art = SKSpriteNode(imageNamed: background)
        art.size = size
        art.position = CGPoint(x: size.width / 2, y: size.height / 2)
        overlay.addChild(art)
        return overlay
    }

    private func menuButton(_ title: String, name: String, point: CGPoint, parent: SKNode, width: CGFloat = 270) {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: 60), cornerRadius: 28)
        button.position = point
        button.name = name
        button.fillColor = UIColor(red: 1, green: 0.44, blue: 0.39, alpha: 1)
        button.strokeColor = UIColor(red: 1, green: 0.94, blue: 0.81, alpha: 1)
        button.lineWidth = 3
        parent.addChild(button)
        label(title, size: 23, point: CGPoint(x: 0, y: -8), parent: button)
    }

    private func showTitle() {
        let overlay = makeMenu(background: "festival-dusk")
        let shade = SKShapeNode(rectOf: size)
        shade.position = CGPoint(x: 195, y: 422)
        shade.fillColor = UIColor(red: 0.12, green: 0.14, blue: 0.28, alpha: 0.13)
        shade.strokeColor = .clear
        overlay.addChild(shade)
        for (text, y, fontSize, color) in [("Bubble", CGFloat(673), CGFloat(72), UIColor(red: 1, green: 0.53, blue: 0.45, alpha: 1)), ("Quest", CGFloat(603), CGFloat(70), UIColor(red: 1, green: 0.96, blue: 0.80, alpha: 1))] {
            label(text, size: fontSize, point: CGPoint(x: 198, y: y - 4), parent: overlay)
            (overlay.children.last as? SKLabelNode)?.fontColor = UIColor(red: 0.14, green: 0.18, blue: 0.34, alpha: 1)
            label(text, size: fontSize, point: CGPoint(x: 195, y: y), parent: overlay)
            (overlay.children.last as? SKLabelNode)?.fontColor = color
        }
        panel(width: 228, height: 30, point: CGPoint(x: 195, y: 577), parent: overlay)
        label("Festival Pop", size: 16, point: CGPoint(x: 195, y: 571), parent: overlay)
        let cast = SKSpriteNode(imageNamed: "festival-title-cast")
        cast.size = CGSize(width: 382, height: 382)
        cast.position = CGPoint(x: 195, y: 365)
        overlay.addChild(cast)
        menuButton("Let's play  ✿", name: "start-adventure", point: CGPoint(x: 195, y: 159), parent: overlay)
        panel(width: 314, height: 31, point: CGPoint(x: 195, y: 99), parent: overlay)
        label("A little sunshine. A little festival magic.", size: 13, point: CGPoint(x: 195, y: 94), parent: overlay)
    }

    private func showLevels() {
        let overlay = makeMenu(background: "festival-map")
        panel(width: 306, height: 53, point: CGPoint(x: 195, y: 764), parent: overlay)
        label("Festival adventure", size: 23, point: CGPoint(x: 195, y: 756), parent: overlay)
        let unlocked = min(4, max(0, UserDefaults.standard.integer(forKey: "unlockedLevel")))
        let positions = [CGPoint(x: 195, y: 145), CGPoint(x: 250, y: 260), CGPoint(x: 175, y: 380), CGPoint(x: 302, y: 489), CGPoint(x: 312, y: 612)]
        for (index, position) in positions.enumerated() {
            let entry = SKShapeNode(circleOfRadius: 27)
            entry.position = position
            entry.fillColor = index == unlocked ? .systemPink : index < unlocked ? UIColor(red: 0.99, green: 0.78, blue: 0.43, alpha: 1) : UIColor(red: 0.36, green: 0.40, blue: 0.53, alpha: 0.95)
            entry.strokeColor = UIColor(red: 1, green: 0.95, blue: 0.77, alpha: 1)
            entry.lineWidth = index == unlocked ? 4 : 2
            entry.name = index <= unlocked ? "level-\(index)" : "locked"
            overlay.addChild(entry)
            label("\(index + 1)", size: 25, point: CGPoint(x: 0, y: -9), parent: entry)
            let stars = UserDefaults.standard.integer(forKey: "stars-\(index)")
            let best = UserDefaults.standard.integer(forKey: "bestScore-\(index)")
            if best > 0 {
                label(String(repeating: "★", count: max(1, stars)), size: 16, point: CGPoint(x: 0, y: -45), parent: entry)
                (entry.children.last as? SKLabelNode)?.fontColor = .systemYellow
            }
            let sign = panel(width: 138, height: 25, point: CGPoint(x: position.x > 275 ? position.x - 47 : position.x, y: position.y - (index == 0 ? 40 : 65)), parent: overlay)
            label(index > unlocked ? "Unlock next" : levelNames[index], size: 11, point: CGPoint(x: 0, y: -4), parent: sign)
        }
        menuButton("Home", name: "home", point: CGPoint(x: 77, y: 59), parent: overlay, width: 104)
        panel(width: 213, height: 32, point: CGPoint(x: 260, y: 59), parent: overlay)
        label("Clear a stop to open the next", size: 11, point: CGPoint(x: 260, y: 54), parent: overlay)
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
        hud.text = "Level \(level + 1)"
        shotsLabel.text = "Shots \(shots)"
        scoreLabel.text = "Score \(score)"
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
            if names.contains("start-adventure") { showLevels() }
            else if names.contains("home") { showTitle() }
            else if let name = names.first(where: { $0.hasPrefix("level-") }), let selected = Int(name.dropFirst(6)) {
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
            for index in 0..<6 {
                let sparkle = SKShapeNode(circleOfRadius: 2.5)
                sparkle.position = point(match)
                sparkle.fillColor = palette[currentColor]
                sparkle.strokeColor = .white.withAlphaComponent(0.6)
                sparkle.zPosition = 12
                addChild(sparkle)
                let angle = CGFloat(index) * .pi / 3
                sparkle.run(.sequence([.group([.moveBy(x: cos(angle) * 30, y: sin(angle) * 30, duration: 0.28), .fadeOut(withDuration: 0.28)]), .removeFromParent()]))
            }
            nodes.removeValue(forKey: match)?.run(.sequence([.group([.scale(to: 1.4, duration: 0.12), .fadeOut(withDuration: 0.12)]), .removeFromParent()]))
        }
        for dropped in result.dropped {
            nodes.removeValue(forKey: dropped)?.run(.sequence([.group([.moveBy(x: 0, y: -650, duration: 0.65), .rotate(byAngle: 2, duration: 0.65), .fadeOut(withDuration: 0.65)]), .removeFromParent()]))
        }
        score += result.matched.count * 10 + result.dropped.count * 20
        if !result.dropped.isEmpty {
            let cheers = SKLabelNode(fontNamed: "AvenirNext-Bold")
            cheers.text = "Nice drop! +\(result.dropped.count * 20)"
            cheers.fontSize = 23
            cheers.fontColor = .systemYellow
            cheers.position = CGPoint(x: 195, y: 385)
            cheers.zPosition = 12
            addChild(cheers)
            cheers.run(.sequence([.group([.moveBy(x: 0, y: 35, duration: 0.9), .sequence([.wait(forDuration: 0.55), .fadeOut(withDuration: 0.35)])]), .removeFromParent()]))
        }
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
            let initialShots = [24, 28, 30, 34, 38][level]
            let stars = shots >= initialShots / 2 ? 3 : shots >= initialShots / 4 ? 2 : 1
            UserDefaults.standard.set(max(stars, UserDefaults.standard.integer(forKey: "stars-\(level)")), forKey: "stars-\(level)")
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
        hud.text = "Level \(level + 1)"
        shotsLabel.text = "Shots \(shots)"
        scoreLabel.text = "Score \(score)"
        status.text = success ? "Beautiful popping!" : "You can do it!"
    }
}
