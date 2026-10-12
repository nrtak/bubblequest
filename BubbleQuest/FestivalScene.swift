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
    private let progress = GameProgress()
    private let audio = FestivalAudio()
    private let gameRoot = SKNode()
    private var mapArea = 0
    private var menuKind = "title"
    private var returnMenu = "game"
    private var armed: BubbleShot?
    private var rainbowLeft = 1
    private var bombLeft = 1
    private var colorBag: [Int] = []
    private var introHost: FestivalHost?
    private var dialoguePage = 0
    private var tutorialPage = 0
    private var tutorialFromSettings = false
    private var suspended = false
    private let playfield = SKNode()
    private let guide = SKNode()
    private let hud = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let shotsLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let scoreLabel = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
    private let status = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var loaded: SKNode?
    private var nextNode: SKNode?
    private var projectile: SKNode?
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

    override func didMove(to view: SKView) {
        guard children.isEmpty else { return }
        view.preferredFramesPerSecond = 60
        backgroundColor = UIColor(red: 0.12, green: 0.14, blue: 0.28, alpha: 1)
        addChild(gameRoot)
        decorate()
        gameRoot.addChild(playfield)
        gameRoot.addChild(guide)
        hud.fontSize = 21
        hud.position = CGPoint(x: 88, y: 752)
        gameRoot.addChild(hud)
        shotsLabel.fontSize = 21
        shotsLabel.position = CGPoint(x: 291, y: 752)
        gameRoot.addChild(shotsLabel)
        scoreLabel.fontSize = 15
        scoreLabel.position = CGPoint(x: 195, y: 317)
        gameRoot.addChild(scoreLabel)
        status.fontSize = 13
        status.position = CGPoint(x: 195, y: 279)
        gameRoot.addChild(status)
        button("Retry", name: "retry", x: 50, y: 56)
        button("Swap", name: "swap", x: 195, y: 56)
        button("Settings", name: "settings", x: 340, y: 56)
        button("Rainbow 1", name: "rainbow", x: 138, y: 102, width: 100)
        button("Bomb 1", name: "bomb", x: 252, y: 102, width: 100)
        level = progress.unlockedLevel
        if ProcessInfo.processInfo.arguments.contains("--dusk-preview") { level = 49 }
        if ProcessInfo.processInfo.arguments.contains("--courtyard-preview") { level = 10 }
        mapArea = level / 10
        startLevel()
        if ProcessInfo.processInfo.arguments.contains("--ending-preview") { showEnding() }
        else if ProcessInfo.processInfo.arguments.contains("--settings-preview") { returnMenu = "title"; showSettings() }
        else if ProcessInfo.processInfo.arguments.contains("--map-preview") { showLevels() }
        else if ProcessInfo.processInfo.arguments.contains("--host-preview") { showHost(FestivalHost.all[mapArea]) }
        else if ProcessInfo.processInfo.arguments.contains("--gameplay-preview") { updateAim(CGPoint(x: 242, y: 600)) }
        else { showTitle() }
    }

    func setActive(_ active: Bool) {
        suspended = !active
        isPaused = !active
        aiming = false
        guide.removeAllChildren()
        audio.suspend(!active)
        audio.update(area: level / 10, enabled: progress.enabled(.music))
    }

    private func label(_ text: String, size: CGFloat, point: CGPoint, parent: SKNode? = nil) {
        let node = SKLabelNode(fontNamed: "AvenirNext-Bold")
        node.text = text
        node.fontSize = size
        node.position = point
        (parent ?? gameRoot).addChild(node)
    }

    private func decorate() {
        let background = SKSpriteNode(imageNamed: "festival-day")
        background.size = size
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.zPosition = -10
        gameRoot.addChild(background)
        backdrop = background
        for x in [CGFloat(17), CGFloat(373)] {
            let lantern = SKShapeNode(ellipseOf: CGSize(width: 22, height: 33))
            lantern.fillColor = UIColor(red: 1, green: 0.67, blue: 0.35, alpha: 0.8)
            lantern.strokeColor = UIColor.white.withAlphaComponent(0.5)
            lantern.position = CGPoint(x: x, y: 481)
            lantern.zPosition = -2
            gameRoot.addChild(lantern)
            lantern.run(.repeatForever(.sequence([.group([.moveBy(x: 0, y: 4, duration: 1.8), .rotate(byAngle: 0.08, duration: 1.8)]), .group([.moveBy(x: 0, y: -4, duration: 1.8), .rotate(byAngle: -0.08, duration: 1.8)])])))
        }
        panel(width: 132, height: 47, point: CGPoint(x: 88, y: 759), parent: gameRoot)
        panel(width: 132, height: 47, point: CGPoint(x: 291, y: 759), parent: gameRoot)
        panel(width: 256, height: 31, point: CGPoint(x: 195, y: 322), parent: gameRoot)
        panel(width: 278, height: 28, point: CGPoint(x: 195, y: 284), parent: gameRoot)
        for (index, x) in [CGFloat(74), CGFloat(319)].enumerated() {
            let friend = progress.selected(index == 0 ? .animal : .human)
            let companion = SKSpriteNode(texture: atlasTexture("festival-companion-atlas", index: friend.atlasIndex), size: CGSize(width: 105, height: 105))
            companion.position = CGPoint(x: x, y: 185)
            companion.name = "companion-\(index)"
            gameRoot.addChild(companion)
        }
        let place = SKLabelNode(fontNamed: "AvenirNext-DemiBold")
        place.name = "place"
        place.fontSize = 15
        place.position = CGPoint(x: 195, y: 31)
        panel(width: 230, height: 24, point: CGPoint(x: 195, y: 24), parent: gameRoot)
        place.position.y = 19
        gameRoot.addChild(place)
        button("Map", name: "levels", x: 195, y: 759, width: 60)
        let base = SKShapeNode(rectOf: CGSize(width: 91, height: 20), cornerRadius: 7)
        base.position = CGPoint(x: origin.x, y: 128)
        base.fillColor = UIColor(red: 0.43, green: 0.23, blue: 0.13, alpha: 1)
        base.strokeColor = UIColor(red: 1, green: 0.77, blue: 0.42, alpha: 1)
        base.lineWidth = 3
        gameRoot.addChild(base)
        let barrelPath = CGMutablePath()
        barrelPath.move(to: CGPoint(x: -31, y: -39))
        barrelPath.addLine(to: CGPoint(x: -23, y: 16))
        barrelPath.addQuadCurve(to: CGPoint(x: 23, y: 16), control: CGPoint(x: 0, y: 25))
        barrelPath.addLine(to: CGPoint(x: 31, y: -39))
        barrelPath.closeSubpath()
        let cannon = SKShapeNode(path: barrelPath)
        cannon.position = origin
        cannon.name = "cannon"
        cannon.fillColor = UIColor(red: 0.60, green: 0.33, blue: 0.16, alpha: 1)
        cannon.strokeColor = UIColor(red: 1, green: 0.79, blue: 0.43, alpha: 1)
        cannon.lineWidth = 3
        gameRoot.addChild(cannon)
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
        gameRoot.addChild(box)
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
        gameRoot.childNode(withName: "result")?.removeFromParent()
        projectile?.removeFromParent()
        projectile = nil
        guide.removeAllChildren()
        playfield.removeAllChildren()
        nodes.removeAll()
        board = .level(level)
        shots = LevelCatalog.level(level).shots
        rainbowLeft = 1
        bombLeft = 1
        armed = nil
        colorBag.removeAll()
        gameRoot.isPaused = false
        for index in 0..<2 {
            let friend = progress.selected(index == 0 ? .animal : .human)
            (gameRoot.childNode(withName: "companion-\(index)") as? SKSpriteNode)?.texture = atlasTexture("festival-companion-atlas", index: friend.atlasIndex)
        }
        score = 0
        finished = false
        aiming = false
        let area = LevelCatalog.areas[level / 10]
        backdrop?.texture = SKTexture(imageNamed: area.background)
        backdrop?.color = UIColor(red: 0.25, green: 0.27, blue: 0.55, alpha: 1)
        backdrop?.colorBlendFactor = area.nightTint ? 0.18 : 0
        audio.update(area: level / 10, enabled: progress.enabled(.music))
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
        (gameRoot.childNode(withName: "place") as? SKLabelNode)?.text = LevelCatalog.areas[level / 10].name
    }

    private func makeMenu(background: String) -> SKNode {
        levelMenu?.removeFromParent()
        aiming = false
        guide.removeAllChildren()
        gameRoot.isPaused = true
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
        menuKind = "title"
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
        menuButton("Friends", name: "friends", point: CGPoint(x: 108, y: 91), parent: overlay, width: 152)
        menuButton("Settings", name: "settings", point: CGPoint(x: 282, y: 91), parent: overlay, width: 152)
        label("Irvine Dynamics", size: 12, point: CGPoint(x: 195, y: 37), parent: overlay)
    }

    private func showLevels() {
        menuKind = "map"
        mapArea = min(4, max(0, mapArea))
        let area = LevelCatalog.areas[mapArea]
        let overlay = makeMenu(background: area.background)
        panel(width: 346, height: 82, point: CGPoint(x: 195, y: 738), parent: overlay)
        label(area.name, size: 23, point: CGPoint(x: 195, y: 750), parent: overlay)
        label("Stars \(progress.totalStars)/150 • Stops \(progress.completedCount)/50", size: 14, point: CGPoint(x: 195, y: 720), parent: overlay)
        let path = CGMutablePath()
        var positions: [CGPoint] = []
        for i in 0..<10 {
            let position = CGPoint(x: i % 2 == 0 ? 117 : 273, y: 640 - CGFloat(i / 2) * 98)
            positions.append(position)
            if i == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        let trail = SKShapeNode(path: path)
        trail.strokeColor = UIColor(red: 1, green: 0.87, blue: 0.59, alpha: 0.85)
        trail.lineWidth = 12
        overlay.addChild(trail)
        for (local, position) in positions.enumerated() {
            let index = mapArea * 10 + local
            let entry = SKShapeNode(circleOfRadius: 28)
            entry.position = position
            entry.fillColor = index == progress.unlockedLevel ? .systemPink : progress.stars(index) > 0 ? .systemOrange : index <= progress.unlockedLevel ? .systemTeal : .darkGray
            entry.strokeColor = .white
            entry.lineWidth = 3
            entry.name = index <= progress.unlockedLevel ? "level-\(index)" : "locked"
            overlay.addChild(entry)
            label("\(index + 1)", size: 24, point: CGPoint(x: 0, y: -8), parent: entry)
            label(String(repeating: "★", count: progress.stars(index)) + String(repeating: "☆", count: 3 - progress.stars(index)), size: 15, point: CGPoint(x: 0, y: -48), parent: entry)
        }
        menuButton("‹", name: "area-prev", point: CGPoint(x: 39, y: 738), parent: overlay, width: 42)
        menuButton("›", name: "area-next", point: CGPoint(x: 351, y: 738), parent: overlay, width: 42)
        menuButton("Meet \(FestivalHost.all[mapArea].name)", name: "meet-host", point: CGPoint(x: 195, y: 174), parent: overlay, width: 230)
        label(area.subtitle, size: 13, point: CGPoint(x: 195, y: 126), parent: overlay)
        menuButton("Home", name: "home", point: CGPoint(x: 70, y: 75), parent: overlay, width: 108)
        menuButton("Friends", name: "friends", point: CGPoint(x: 195, y: 75), parent: overlay, width: 112)
        menuButton("Settings", name: "settings", point: CGPoint(x: 320, y: 75), parent: overlay, width: 112)
    }

    private func availableColor() -> Int {
        let available = Set(board.bubbles.values)
        colorBag.removeAll { !available.contains($0) }
        if colorBag.isEmpty { colorBag = available.sorted().shuffled() }
        return colorBag.popLast() ?? 0
    }

    private func reload() {
        loaded?.removeFromParent()
        nextNode?.removeFromParent()
        let node = shotNode(armed ?? .color(currentColor))
        node.position = origin
        gameRoot.addChild(node)
        loaded = node
        let next = bubble(nextColor)
        next.setScale(0.75)
        next.position = CGPoint(x: 252, y: 158)
        gameRoot.addChild(next)
        nextNode = next
    }

    private func refreshHUD() {
        hud.text = "Level \(level + 1)"
        shotsLabel.text = "Shots \(shots)"
        scoreLabel.text = "Score \(score)"
        status.text = armed == nil ? "Drag to aim • Release to pop" : "Booster ready • Release to use"
        for (name, count) in [("rainbow", rainbowLeft), ("bomb", bombLeft)] {
            let box = gameRoot.childNode(withName: name) as? SKShapeNode
            (box?.children.first as? SKLabelNode)?.text = "\(name.capitalized) \(count)"
            box?.alpha = count > 0 ? 1 : 0.4
            box?.fillColor = (name == "rainbow" && armed == .rainbow) || (name == "bomb" && armed == .bomb) ? .systemPink : UIColor(red: 0.23, green: 0.28, blue: 0.47, alpha: 0.9)
        }
    }

    private func updateAim(_ target: CGPoint) {
        let angle = min(BubbleGeometry.maxAngle, max(-BubbleGeometry.maxAngle,
                        atan2(Double(target.x - origin.x), Double(max(70, target.y - origin.y)))))
        aim = CGVector(dx: sin(angle), dy: cos(angle))
        gameRoot.childNode(withName: "cannon")?.zRotation = -CGFloat(angle)
        guide.removeAllChildren()
        guard progress.enabled(.guide) else { return }
        let flight = BubbleGeometry.flight(angle: angle, board: board)
        for (index, point) in flight.points.enumerated() where index % 7 == 0 {
            let dot = SKShapeNode(circleOfRadius: 2.5)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.alpha = 0.65
            dot.position = CGPoint(x: point.x, y: point.y)
            guide.addChild(dot)
        }
        if let landing = flight.landing {
            let hint = SKShapeNode(circleOfRadius: radius)
            hint.strokeColor = .white
            hint.lineWidth = 2
            hint.position = point(landing)
            hint.alpha = 0.55
            guide.addChild(hint)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !suspended, let location = touches.first?.location(in: self) else { return }
        let hitNodes = levelMenu.map { $0.nodes(at: convert(location, to: $0)) } ?? nodes(at: location)
        let names = hitNodes.compactMap { node -> String? in
            var current: SKNode? = node
            while let value = current { if let name = value.name { return name }; current = value.parent }
            return nil
        }
        if levelMenu != nil { handleMenu(names); return }
        if names.contains("levels") { mapArea = level / 10; showLevels(); return }
        if names.contains("settings") { returnMenu = "game"; showSettings(); return }
        if names.contains("retry") { startLevel(); return }
        if finished {
            if won && level == 49 { showEnding(); return }
            if won { level += 1 }
            beginSelectedLevel()
            return
        }
        guard projectile == nil else { return }
        if names.contains("rainbow") && rainbowLeft > 0 { armed = armed == .rainbow ? nil : .rainbow; reload(); refreshHUD(); return }
        if names.contains("bomb") && bombLeft > 0 { armed = armed == .bomb ? nil : .bomb; reload(); refreshHUD(); return }
        if names.contains("swap") { armed = nil; swap(&currentColor, &nextColor); reload(); refreshHUD(); return }
        guard location.y > 350 else { return }
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
        guard aiming, !finished, projectile == nil, levelMenu == nil, let shot = loaded else { return }
        if let location = touches.first?.location(in: self) { updateAim(location) }
        aiming = false
        guide.removeAllChildren()
        let kind = armed ?? .color(currentColor)
        let flight = BubbleGeometry.flight(angle: atan2(Double(aim.dx), Double(aim.dy)), board: board)
        projectile = shot
        loaded = nil
        if kind == .rainbow { rainbowLeft -= 1 }
        if kind == .bomb { bombLeft -= 1 }
        armed = nil
        shots -= 1
        audio.effect("launch", enabled: progress.enabled(.effects))
        refreshHUD()
        let path = CGMutablePath()
        for (index, point) in flight.points.enumerated() {
            let position = CGPoint(x: point.x, y: point.y)
            if index == 0 { path.move(to: position) } else { path.addLine(to: position) }
        }
        shot.run(.sequence([.follow(path, asOffset: false, orientToPath: false, speed: 620), .run { [weak self, weak shot] in
            guard let self, let shot else { return }
            self.settle(shot, landing: flight.landing, kind: kind)
        }]))
    }

    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat { hypot(a.x - b.x, a.y - b.y) }

    private func settle(_ shot: SKNode, landing: Cell?, kind: BubbleShot) {
        guard let cell = landing else {
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
        let result = board.place(kind, at: cell)
        var particleCount = 0
        for match in result.matched {
            for index in 0..<6 where particleCount < 48 {
                particleCount += 1
                let sparkle = SKShapeNode(circleOfRadius: 2.5)
                sparkle.position = point(match)
                sparkle.fillColor = palette[currentColor]
                sparkle.strokeColor = .white.withAlphaComponent(0.6)
                sparkle.zPosition = 12
                gameRoot.addChild(sparkle)
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
            gameRoot.addChild(cheers)
            cheers.run(.sequence([.group([.moveBy(x: 0, y: 35, duration: 0.9), .sequence([.wait(forDuration: 0.55), .fadeOut(withDuration: 0.35)])]), .removeFromParent()]))
        }
        if !result.matched.isEmpty {
            for index in 0..<2 {
                gameRoot.childNode(withName: "companion-\(index)")?.run(.sequence([.moveBy(x: 0, y: 7, duration: 0.12), .moveBy(x: 0, y: -7, duration: 0.12)]))
            }
            if progress.enabled(.vibration) { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            audio.effect(kind == .bomb ? "bomb" : "pop", enabled: progress.enabled(.effects))
        }
        if board.bubbles.isEmpty { finish(success: true); return }
        if shots <= 0 || board.bubbles.keys.contains(where: { point($0).y < CGFloat(BubbleGeometry.lossLine) }) { finish(success: false); return }
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
            score += shots * 25
            let unlocked = progress.recordVictory(index: level, score: score,
                                                   stars: LevelCatalog.level(level).stars(shotsRemaining: shots))
            if !unlocked.isEmpty { status.text = "New friend: \(unlocked.map { $0.name }.joined(separator: ", "))" }
            if progress.enabled(.vibration) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            audio.effect("victory", enabled: progress.enabled(.effects))
            for index in 0..<2 {
                gameRoot.childNode(withName: "companion-\(index)")?.run(.repeat(.sequence([.moveBy(x: 0, y: 10, duration: 0.15), .moveBy(x: 0, y: -10, duration: 0.15)]), count: 3))
            }
        } else {
            for index in 0..<2 {
                gameRoot.childNode(withName: "companion-\(index)")?.run(.sequence([.rotate(byAngle: 0.08, duration: 0.15), .rotate(byAngle: -0.08, duration: 0.15)]))
            }
        }
        let panel = SKShapeNode(rectOf: CGSize(width: 330, height: 160), cornerRadius: 24)
        panel.name = "result"
        panel.fillColor = UIColor(red: 0.21, green: 0.22, blue: 0.39, alpha: 0.98)
        panel.strokeColor = .systemOrange
        panel.position = CGPoint(x: 195, y: 414)
        panel.zPosition = 20
        gameRoot.addChild(panel)
        label(success ? "Festival cheers! 🎉" : "Try another angle", size: 23, point: CGPoint(x: 0, y: 24), parent: panel)
        label(success ? String(repeating: "★", count: LevelCatalog.level(level).stars(shotsRemaining: shots)) + " • Score \(score)" : "Score \(score)", size: 18, point: CGPoint(x: 0, y: -8), parent: panel)
        label(success ? (level == 49 ? "Tap for the celebration" : "Tap for the next level") : "Tap to retry", size: 16, point: CGPoint(x: 0, y: -43), parent: panel)
        hud.text = "Level \(level + 1)"
        shotsLabel.text = "Shots \(shots)"
        scoreLabel.text = "Score \(score)"
        if !success { status.text = "You can do it!" }
    }
}

private extension FestivalScene {
    func atlasTexture(_ name: String, index: Int) -> SKTexture {
        SKTexture(rect: CGRect(x: CGFloat(index % 3) / 3, y: index < 3 ? 0.5 : 0,
                               width: 1.0 / 3, height: 0.5), in: SKTexture(imageNamed: name))
    }

    func shotNode(_ kind: BubbleShot) -> SKNode {
        switch kind {
        case .color(let color): return bubble(color)
        case .rainbow:
            let node = bubble(0)
            for index in 0..<5 {
                let arc = SKShapeNode(circleOfRadius: radius - CGFloat(index) * 3)
                arc.strokeColor = palette[index]
                arc.lineWidth = 3
                node.addChild(arc)
            }
            return node
        case .bomb:
            let node = bubble(4)
            let body = SKShapeNode(circleOfRadius: 11)
            body.fillColor = .darkGray
            body.strokeColor = .white
            node.addChild(body)
            label("✦", size: 15, point: CGPoint(x: 7, y: 6), parent: node)
            return node
        }
    }

    func closeMenu() {
        levelMenu?.removeFromParent()
        levelMenu = nil
        menuKind = "game"
        gameRoot.isPaused = false
    }

    func beginSelectedLevel() {
        closeMenu()
        startLevel()
        if !progress.tutorialSeen {
            tutorialPage = 0
            tutorialFromSettings = false
            returnMenu = "game"
            showTutorial()
        } else if !progress.hasMet(FestivalHost.all[level / 10]) {
            showHost(FestivalHost.all[level / 10])
        }
    }

    func paragraph(_ text: String, y: CGFloat, parent: SKNode, width: CGFloat = 300) {
        let node = SKLabelNode(fontNamed: "AvenirNext-Medium")
        node.text = text
        node.fontSize = 18
        node.numberOfLines = 0
        node.preferredMaxLayoutWidth = width
        node.verticalAlignmentMode = .center
        node.position = CGPoint(x: 195, y: y)
        parent.addChild(node)
    }

    func showHost(_ host: FestivalHost) {
        guard progress.hostIsAvailable(host) else {
            status.text = "Reach level \(host.area * 10 + 1) to meet \(host.name)"
            return
        }
        if menuKind != "host" { returnMenu = menuKind; dialoguePage = 0 }
        introHost = host
        menuKind = "host"
        let overlay = makeMenu(background: LevelCatalog.areas[host.area].background)
        panel(width: 332, height: 75, point: CGPoint(x: 195, y: 735), parent: overlay)
        label("Meet \(host.name)", size: 29, point: CGPoint(x: 195, y: 742), parent: overlay)
        label(host.role, size: 15, point: CGPoint(x: 195, y: 714), parent: overlay)
        let portrait = SKSpriteNode(texture: atlasTexture("festival-hosts", index: host.portraitIndex), size: CGSize(width: 304, height: 304))
        portrait.position = CGPoint(x: 195, y: 529)
        overlay.addChild(portrait)
        panel(width: 340, height: 155, point: CGPoint(x: 195, y: 302), parent: overlay)
        paragraph(host.introduction[min(dialoguePage, host.introduction.count - 1)], y: 311, parent: overlay)
        label("\(dialoguePage + 1)/\(host.introduction.count)", size: 13, point: CGPoint(x: 195, y: 247), parent: overlay)
        menuButton(dialoguePage == host.introduction.count - 1 ? "Let's go!" : "Next", name: "dialogue-next", point: CGPoint(x: 195, y: 157), parent: overlay)
        menuButton("Skip", name: "dialogue-skip", point: CGPoint(x: 195, y: 86), parent: overlay, width: 132)
    }

    func finishIntroduction() {
        if let host = introHost { progress.markMet(host) }
        introHost = nil
        restoreMenu()
    }

    func restoreMenu() {
        switch returnMenu {
        case "title": showTitle()
        case "map": showLevels()
        case "settings": showSettings()
        default: closeMenu()
        }
    }

    func showSettings() {
        menuKind = "settings"
        let overlay = makeMenu(background: LevelCatalog.areas[level / 10].background)
        panel(width: 342, height: 518, point: CGPoint(x: 195, y: 442), parent: overlay)
        label("Settings", size: 31, point: CGPoint(x: 195, y: 649), parent: overlay)
        for (index, setting) in GameSetting.allCases.enumerated() {
            menuButton("\(setting.title): \(progress.enabled(setting) ? "On" : "Off")", name: "setting-\(setting.rawValue)", point: CGPoint(x: 195, y: 575 - CGFloat(index) * 73), parent: overlay)
        }
        menuButton("How to play", name: "tutorial", point: CGPoint(x: 195, y: 276), parent: overlay)
        paragraph("Progress saves on this iPhone. Free retries. No accounts or purchases.", y: 212, parent: overlay)
        menuButton("Back", name: "back", point: CGPoint(x: 195, y: 122), parent: overlay)
        label("Irvine Dynamics • Bubble Quest", size: 13, point: CGPoint(x: 195, y: 63), parent: overlay)
    }

    func showTutorial() {
        menuKind = "tutorial"
        let overlay = makeMenu(background: "festival-courtyard")
        let titles = ["Aim and pop", "Try a wall bounce", "A little extra help"]
        let bodies = ["Drag above the launcher to aim. Release to shoot. Match three bubbles with the same color and symbol.",
                      "Use the walls to reach tricky spots. Pop a supporting group to drop the bubbles below it. Clear the board to win!",
                      "Rainbow pops its largest connected color group. Bomb clears nearby bubbles. You get one of each per attempt. Save shots to earn more stars!"]
        panel(width: 342, height: 440, point: CGPoint(x: 195, y: 465), parent: overlay)
        label(titles[tutorialPage], size: 26, point: CGPoint(x: 195, y: 632), parent: overlay)
        for index in 0..<3 {
            let node = tutorialPage == 2 ? shotNode(index == 0 ? .rainbow : index == 1 ? .bomb : .color(1)) : bubble(0)
            node.position = CGPoint(x: 137 + CGFloat(index) * 58, y: 550)
            overlay.addChild(node)
        }
        paragraph(bodies[tutorialPage], y: 410, parent: overlay)
        label("\(tutorialPage + 1)/3", size: 16, point: CGPoint(x: 195, y: 286), parent: overlay)
        menuButton(tutorialPage == 2 ? "Ready to play" : "Next", name: "tutorial-next", point: CGPoint(x: 195, y: 181), parent: overlay)
        menuButton("Skip", name: "tutorial-skip", point: CGPoint(x: 195, y: 109), parent: overlay, width: 132)
    }

    func finishTutorial() {
        progress.tutorialSeen = true
        if tutorialFromSettings { tutorialFromSettings = false; showSettings() }
        else if returnMenu == "game", !progress.hasMet(FestivalHost.all[level / 10]) {
            menuKind = "game"
            showHost(FestivalHost.all[level / 10])
        } else { restoreMenu() }
    }

    func showFriends() {
        menuKind = "friends"
        let overlay = makeMenu(background: "festival-courtyard")
        panel(width: 338, height: 68, point: CGPoint(x: 195, y: 744), parent: overlay)
        label("Festival friends", size: 28, point: CGPoint(x: 195, y: 746), parent: overlay)
        label("Choose an animal and a human", size: 14, point: CGPoint(x: 195, y: 722), parent: overlay)
        for (index, friend) in Companion.all.enumerated() {
            let x: CGFloat = index % 2 == 0 ? 105 : 285
            let y: CGFloat = 617 - CGFloat(index / 2) * 166
            let tile = panel(width: 160, height: 154, point: CGPoint(x: x, y: y), parent: overlay)
            tile.name = "friend-\(friend.id)"
            let available = progress.unlocked(friend)
            let portrait = SKSpriteNode(texture: atlasTexture("festival-companion-atlas", index: friend.atlasIndex), size: CGSize(width: 96, height: 96))
            portrait.position.y = 19
            portrait.alpha = available ? 1 : 0.35
            tile.addChild(portrait)
            label(friend.name, size: 14, point: CGPoint(x: 0, y: -45), parent: tile)
            let chosen = progress.selected(friend.kind).id == friend.id
            label(available ? chosen ? "Selected ✓" : "Tap to choose" : "Clear \(friend.unlockAfter) stops", size: 11, point: CGPoint(x: 0, y: -65), parent: tile)
        }
        let next = Companion.all.filter { !progress.unlocked($0) }.min { $0.unlockAfter < $1.unlockAfter }
        paragraph(next.map { "\(progress.completedCount)/\($0.unlockAfter) stops toward \($0.name)" } ?? "You have met every companion!", y: 180, parent: overlay)
        menuButton("Back", name: "back", point: CGPoint(x: 195, y: 93), parent: overlay)
    }

    func showEnding() {
        menuKind = "ending"
        let overlay = makeMenu(background: "festival-dusk")
        panel(width: 342, height: 98, point: CGPoint(x: 195, y: 707), parent: overlay)
        label("Festival complete!", size: 30, point: CGPoint(x: 195, y: 717), parent: overlay)
        label("50 stops • \(progress.totalStars)/150 stars", size: 18, point: CGPoint(x: 195, y: 682), parent: overlay)
        let cast = SKSpriteNode(imageNamed: "festival-title-cast")
        cast.size = CGSize(width: 372, height: 372)
        cast.position = CGPoint(x: 195, y: 458)
        overlay.addChild(cast)
        panel(width: 342, height: 100, point: CGPoint(x: 195, y: 243), parent: overlay)
        paragraph("Thanks for bringing the festival to life! Visit your favorite stops and collect every star.", y: 247, parent: overlay)
        menuButton("Explore again", name: "start-adventure", point: CGPoint(x: 195, y: 145), parent: overlay)
        menuButton("Home", name: "home", point: CGPoint(x: 195, y: 77), parent: overlay, width: 150)
        let fireworks = SKAction.sequence([.run { [weak self, weak overlay] in
            guard let self, let overlay else { return }
            let center = CGPoint(x: CGFloat.random(in: 70...320), y: CGFloat.random(in: 540...650))
            for i in 0..<12 {
                let spark = SKShapeNode(circleOfRadius: 3)
                spark.fillColor = self.palette[i % 5]
                spark.strokeColor = .clear
                spark.position = center
                overlay.addChild(spark)
                let angle = CGFloat(i) * .pi / 6
                spark.run(.sequence([.group([.moveBy(x: cos(angle) * 65, y: sin(angle) * 65, duration: 0.8), .fadeOut(withDuration: 0.8)]), .removeFromParent()]))
            }
        }, .wait(forDuration: 1.4)])
        overlay.run(.repeatForever(fireworks))
    }

    func handleMenu(_ names: [String]) {
        if names.contains("start-adventure") { mapArea = progress.unlockedLevel / 10; showLevels() }
        else if names.contains("home") { showTitle() }
        else if names.contains("area-prev") { mapArea = max(0, mapArea - 1); showLevels() }
        else if names.contains("area-next") { mapArea = min(4, mapArea + 1); showLevels() }
        else if names.contains("meet-host") {
            let host = FestivalHost.all[mapArea]
            if progress.hostIsAvailable(host) { showHost(host) }
            else if let overlay = levelMenu {
                overlay.childNode(withName: "unlock-message")?.removeFromParent()
                let message = panel(width: 280, height: 32, point: CGPoint(x: 195, y: 214), parent: overlay)
                message.name = "unlock-message"
                label("Reach level \(host.area * 10 + 1) to meet \(host.name)", size: 12, point: CGPoint(x: 0, y: -4), parent: message)
            }
        }
        else if names.contains("settings") { returnMenu = menuKind; showSettings() }
        else if names.contains("friends") { returnMenu = menuKind; showFriends() }
        else if names.contains("back") { restoreMenu() }
        else if names.contains("tutorial") { tutorialFromSettings = true; tutorialPage = 0; showTutorial() }
        else if names.contains("tutorial-skip") { finishTutorial() }
        else if names.contains("tutorial-next") { if tutorialPage < 2 { tutorialPage += 1; showTutorial() } else { finishTutorial() } }
        else if names.contains("dialogue-skip") { finishIntroduction() }
        else if names.contains("dialogue-next"), let host = introHost {
            if dialoguePage < host.introduction.count - 1 { dialoguePage += 1; showHost(host) } else { finishIntroduction() }
        }
        else if let name = names.first(where: { $0.hasPrefix("setting-") }), let setting = GameSetting(rawValue: String(name.dropFirst(8))) {
            progress.toggle(setting)
            audio.update(area: level / 10, enabled: progress.enabled(.music))
            showSettings()
        }
        else if let name = names.first(where: { $0.hasPrefix("friend-") }), let friend = Companion.all.first(where: { "friend-\($0.id)" == name }) {
            progress.select(friend)
            showFriends()
        }
        else if let name = names.first(where: { $0.hasPrefix("level-") }), let selected = Int(name.dropFirst(6)), selected <= progress.unlockedLevel {
            level = selected
            beginSelectedLevel()
        }
    }
}
