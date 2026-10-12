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
    private let shotsLabel = SKLabelNode(fontNamed: "AvenirNext-Bold")
    private let status = SKLabelNode(fontNamed: "AvenirNext-Medium")
    private var loaded: SKNode?
    private var nextNode: SKNode?
    private var projectile: SKNode?
    private var aim = CGVector(dx: 0, dy: 1)
    private var aimGesture = AimGesture()
    private var loadingBubble = false
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
        shotsLabel.fontSize = 23
        shotsLabel.verticalAlignmentMode = .center
        shotsLabel.position = CGPoint(x: 207, y: 755)
        gameRoot.addChild(shotsLabel)
        iconButton("map.fill", name: "levels", point: CGPoint(x: 47, y: 755))
        iconButton("gearshape.fill", name: "settings", point: CGPoint(x: 343, y: 755))
        iconButton("arrow.counterclockwise", name: "retry", point: CGPoint(x: 48, y: 65))
        iconButton("arrow.triangle.2.circlepath", name: "swap", point: CGPoint(x: 195, y: 65))
        boosterButton(.rainbow, name: "rainbow", point: CGPoint(x: 132, y: 65))
        boosterButton(.bomb, name: "bomb", point: CGPoint(x: 258, y: 65))
        level = progress.unlockedLevel
        if ProcessInfo.processInfo.arguments.contains("--dusk-preview") { level = 49 }
        if ProcessInfo.processInfo.arguments.contains("--courtyard-preview") { level = 10 }
        if ProcessInfo.processInfo.arguments.contains("--water-preview") { level = 5 }
        if ProcessInfo.processInfo.arguments.contains("--tea-preview") { level = 14 }
        mapArea = level / 10
        startLevel()
        if ProcessInfo.processInfo.arguments.contains("--ending-preview") { showEnding() }
        else if ProcessInfo.processInfo.arguments.contains("--settings-preview") { returnMenu = "title"; showSettings() }
        else if ProcessInfo.processInfo.arguments.contains("--map-preview") { showLevels() }
        else if ProcessInfo.processInfo.arguments.contains("--host-preview") { showHost(FestivalHost.all[mapArea]) }
        else if ProcessInfo.processInfo.arguments.contains("--cancel-preview") { updateAim(CGPoint(x: 195, y: 220)) }
        else if ProcessInfo.processInfo.arguments.contains("--gameplay-preview") { updateAim(CGPoint(x: 242, y: 600)) }
        else { showTitle() }
    }

    func setActive(_ active: Bool) {
        suspended = !active
        isPaused = !active
        aiming = false
        aimGesture.cancel()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
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
        panel(width: 126, height: 47, point: CGPoint(x: 195, y: 755), parent: gameRoot)
        let shotSymbol = bubble(0)
        shotSymbol.setScale(0.42)
        shotSymbol.position = CGPoint(x: 155, y: 755)
        gameRoot.addChild(shotSymbol)
        label("LEFT", size: 9, point: CGPoint(x: 240, y: 752))
        decorateRail()
        for (index, x) in [CGFloat(74), CGFloat(319)].enumerated() {
            let friend = progress.selected(index == 0 ? .animal : .human)
            let companion = SKSpriteNode(texture: companionTexture(friend, frame: 0), size: CGSize(width: 125, height: 125))
            companion.position = CGPoint(x: x, y: 185)
            companion.name = "companion-\(index)"
            gameRoot.addChild(companion)
        }
        let base = SKShapeNode(rectOf: CGSize(width: 224, height: 20), cornerRadius: 7)
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
        let nextStand = panel(width: 40, height: 28, point: CGPoint(x: 113, y: 151), parent: gameRoot)
        nextStand.fillColor = UIColor(red: 0.45, green: 0.27, blue: 0.16, alpha: 0.65)
        decorateMechanism()
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
        bubbleArt(index: color)
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
        loadingBubble = false
        aimGesture.cancel()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        colorBag.removeAll()
        gameRoot.isPaused = false
        for index in 0..<2 {
            let friend = progress.selected(index == 0 ? .animal : .human)
            let sprite = gameRoot.childNode(withName: "companion-\(index)") as? SKSpriteNode
            sprite?.removeAllActions()
            sprite?.texture = companionTexture(friend, frame: 0)
            sprite?.position.y = 185
            sprite?.zRotation = 0
            sprite?.xScale = index == 1 ? -1 : 1
            sprite?.run(.repeatForever(.sequence([.scaleY(to: 1.015, duration: 1.5), .scaleY(to: 1, duration: 1.5)])), withKey: "breathing")
        }
        score = 0
        finished = false
        aiming = false
        let area = LevelCatalog.areas[level / 10]
        backdrop?.texture = SKTexture(imageNamed: LevelCatalog.level(level).background)
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
    }

    private func makeMenu(background: String) -> SKNode {
        levelMenu?.removeFromParent()
        aiming = false
        aimGesture.cancel()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
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

    private func menuButton(_ title: String, name: String, point: CGPoint, parent: SKNode, width: CGFloat = 270, height: CGFloat = 60) {
        let button = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: min(28, height / 2))
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
        let logo = SKSpriteNode(imageNamed: "festival-logo")
        logo.size = CGSize(width: 344, height: 229)
        logo.position = CGPoint(x: 195, y: 652)
        overlay.addChild(logo)
        let cast = SKSpriteNode(imageNamed: "festival-title-cast")
        cast.size = CGSize(width: 340, height: 340)
        cast.position = CGPoint(x: 195, y: 363)
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
        let overlay = makeMenu(background: mapArea < 2 ? "festival-map-day" : "festival-map")
        panel(width: 346, height: 82, point: CGPoint(x: 195, y: 738), parent: overlay)
        label(area.name, size: 23, point: CGPoint(x: 195, y: 750), parent: overlay)
        label("Stars \(progress.totalStars)/150 • Stops \(progress.completedCount)/50", size: 14, point: CGPoint(x: 195, y: 720), parent: overlay)
        // Marker centers follow the painted roads, leaving the scenery visible.
        let dayXs: [CGFloat] = [223, 234, 238, 251, 270, 232, 174, 184, 246, 242]
        let nightXs: [CGFloat] = [218, 260, 246, 192, 222, 300, 314, 306, 312, 337]
        let xs = mapArea < 2 ? dayXs : nightXs
        let positions = xs.enumerated().map { CGPoint(x: $0.element, y: 205 + CGFloat($0.offset) * 52) }
        for (local, position) in positions.enumerated() {
            let index = mapArea * 10 + local
            let entry = SKShapeNode(circleOfRadius: 22)
            entry.position = position
            entry.fillColor = index == progress.unlockedLevel ? .systemPink : progress.stars(index) > 0 ? .systemOrange : index <= progress.unlockedLevel ? .systemTeal : .darkGray
            entry.strokeColor = .white
            entry.lineWidth = 3
            entry.name = index <= progress.unlockedLevel ? "level-\(index)" : "locked"
            overlay.addChild(entry)
            label("\(index + 1)", size: 20, point: CGPoint(x: 0, y: -7), parent: entry)
            if index == progress.unlockedLevel {
                entry.run(.repeatForever(.sequence([.scale(to: 1.08, duration: 0.8), .scale(to: 1, duration: 0.8)])))
            }
            if progress.stars(index) > 0 {
                label(String(repeating: "★", count: progress.stars(index)) + String(repeating: "☆", count: 3 - progress.stars(index)), size: 12, point: CGPoint(x: 0, y: -34), parent: entry)
            }
        }
        menuButton("‹", name: "area-prev", point: CGPoint(x: 39, y: 738), parent: overlay, width: 42)
        menuButton("›", name: "area-next", point: CGPoint(x: 351, y: 738), parent: overlay, width: 42)
        menuButton("Meet \(FestivalHost.all[mapArea].name)", name: "meet-host", point: CGPoint(x: 211, y: 133), parent: overlay, width: 220, height: 44)
        let host = SKSpriteNode(texture: atlasTexture("festival-hosts", index: mapArea), size: CGSize(width: 78, height: 78))
        host.position = CGPoint(x: 52, y: 142)
        host.name = "meet-host"
        host.alpha = progress.hostIsAvailable(FestivalHost.all[mapArea]) ? 1 : 0.35
        overlay.addChild(host)
        host.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 1.6), .moveBy(x: 0, y: -3, duration: 1.6)])))
        menuButton("Home", name: "home", point: CGPoint(x: 70, y: 75), parent: overlay, width: 108, height: 44)
        menuButton("Friends", name: "friends", point: CGPoint(x: 195, y: 75), parent: overlay, width: 112, height: 44)
        menuButton("Settings", name: "settings", point: CGPoint(x: 320, y: 75), parent: overlay, width: 112, height: 44)
    }

    private func availableColor() -> Int {
        let available = Set(board.bubbles.values)
        colorBag.removeAll { !available.contains($0) }
        if colorBag.isEmpty { colorBag = available.sorted().shuffled() }
        return colorBag.popLast() ?? 0
    }

    private func reload(animateLoading: Bool = false) {
        loaded?.removeFromParent()
        nextNode?.removeFromParent()
        let node = shotNode(armed ?? .color(currentColor))
        node.position = animateLoading ? CGPoint(x: 113, y: 151) : origin
        gameRoot.addChild(node)
        loaded = node
        if animateLoading {
            loadingBubble = true
            audio.effect("load", enabled: progress.enabled(.effects))
            animateCompanion(.animal, frames: [1, 2, 1, 0])
            node.run(.sequence([.move(to: origin, duration: 0.3), .run { [weak self] in self?.loadingBubble = false }]))
        }
        let next = bubble(nextColor)
        next.setScale(0.75)
        next.position = CGPoint(x: 113, y: 151)
        gameRoot.addChild(next)
        nextNode = next
    }

    private func refreshHUD() {
        shotsLabel.text = "\(shots)"
        for (name, count) in [("rainbow", rainbowLeft), ("bomb", bombLeft)] {
            let box = gameRoot.childNode(withName: name) as? SKShapeNode
            (box?.childNode(withName: "count") as? SKLabelNode)?.text = "\(count)"
            box?.alpha = count > 0 ? 1 : 0.35
            let selected = (name == "rainbow" && armed == .rainbow) || (name == "bomb" && armed == .bomb)
            box?.strokeColor = selected ? .systemYellow : .white.withAlphaComponent(0.8)
            box?.lineWidth = selected ? 4 : 1.5
        }
    }

    private func updateAim(_ target: CGPoint) {
        let location = BubblePoint(x: Double(target.x), y: Double(target.y))
        if aimGesture.isActive { aimGesture.update(at: location) }
        else { aimGesture.begin(at: location) }
        guide.removeAllChildren()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = !aimGesture.shouldCancel
        if aimGesture.shouldCancel { return }
        let angle = aimGesture.angle
        aim = CGVector(dx: sin(angle), dy: cos(angle))
        gameRoot.childNode(withName: "cannon")?.zRotation = -CGFloat(angle)
        gameRoot.childNode(withName: "handwheel")?.zRotation = -CGFloat(angle) * 2.5
        animateCompanion(.human, frames: [1, 2], repeating: false)
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
        let names = hitNodes.flatMap { node -> [String] in
            var names: [String] = []
            var current: SKNode? = node
            while let value = current { if let name = value.name { names.append(name) }; current = value.parent }
            return names
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
        guard projectile == nil, !loadingBubble else { return }
        if names.contains("rainbow") && rainbowLeft > 0 { armed = armed == .rainbow ? nil : .rainbow; reload(); refreshHUD(); return }
        if names.contains("bomb") && bombLeft > 0 { armed = armed == .bomb ? nil : .bomb; reload(); refreshHUD(); return }
        if names.contains("swap") { armed = nil; swap(&currentColor, &nextColor); reload(); refreshHUD(); return }
        guard location.y > 350 else { return }
        aiming = true
        aimGesture.begin(at: BubblePoint(x: Double(location.x), y: Double(location.y)))
        updateAim(location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aiming, let point = touches.first?.location(in: self) else { return }
        updateAim(point)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        aiming = false
        aimGesture.cancel()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        guide.removeAllChildren()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aiming, !finished, projectile == nil, !loadingBubble, levelMenu == nil, let shot = loaded else { return }
        aiming = false
        guide.removeAllChildren()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        let lift = touches.first?.location(in: self)
        guard let angle = aimGesture.end(at: lift.map { BubblePoint(x: Double($0.x), y: Double($0.y)) }) else { return }
        let kind = armed ?? .color(currentColor)
        let flight = BubbleGeometry.flight(angle: angle, board: board)
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
        reload(animateLoading: true)
        refreshHUD()
    }

    private func finish(success: Bool) {
        finished = true
        won = success
        aiming = false
        guide.removeAllChildren()
        loaded?.removeFromParent()
        nextNode?.removeFromParent()
        animateCompanion(.animal, frames: success ? [3, 0, 3, 0] : [0])
        animateCompanion(.human, frames: success ? [3, 0, 3, 0] : [0])
        if success {
            score += shots * 25
            status.text = level % 3 == 0 ? FestivalHost.all[level / 10].encouragement : "Beautiful popping!"
            let unlocked = progress.recordVictory(index: level, score: score,
                                                   stars: LevelCatalog.level(level).stars(shotsRemaining: shots))
            if !unlocked.isEmpty { status.text = "New friend: \(unlocked.map { $0.name }.joined(separator: ", "))" }
            if progress.enabled(.vibration) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            audio.effect("victory", enabled: progress.enabled(.effects))
            if level % 10 == 9 {
                for index in 0..<18 {
                    let confetti = SKShapeNode(rectOf: CGSize(width: 5, height: 9), cornerRadius: 1)
                    confetti.position = CGPoint(x: 30 + CGFloat(index) * 19, y: 720)
                    confetti.fillColor = palette[index % palette.count]
                    confetti.strokeColor = .clear
                    confetti.zPosition = 19
                    gameRoot.addChild(confetti)
                    confetti.run(.sequence([.group([.moveBy(x: index % 2 == 0 ? 18 : -18, y: -420, duration: 1.8), .rotate(byAngle: .pi * 3, duration: 1.8), .fadeOut(withDuration: 1.8)]), .removeFromParent()]))
                }
            }
            for index in 0..<2 {
                gameRoot.childNode(withName: "companion-\(index)")?.run(.repeat(.sequence([.moveBy(x: 0, y: 10, duration: 0.15), .moveBy(x: 0, y: -10, duration: 0.15)]), count: 3))
            }
        } else {
            for index in 0..<2 {
                gameRoot.childNode(withName: "companion-\(index)")?.run(.sequence([.rotate(byAngle: 0.08, duration: 0.15), .rotate(byAngle: -0.08, duration: 0.15)]))
            }
        }
        let panel = SKShapeNode(rectOf: CGSize(width: 330, height: 230), cornerRadius: 24)
        panel.name = "result"
        panel.fillColor = UIColor(red: 0.21, green: 0.22, blue: 0.39, alpha: 0.98)
        panel.strokeColor = .systemOrange
        panel.position = CGPoint(x: 195, y: 414)
        panel.zPosition = 20
        gameRoot.addChild(panel)
        label(success ? "Festival cheers! 🎉" : "Try another angle", size: 23, point: CGPoint(x: 0, y: 74), parent: panel)
        label(success ? String(repeating: "★", count: LevelCatalog.level(level).stars(shotsRemaining: shots)) : "Keep trying!", size: 23, point: CGPoint(x: 0, y: 38), parent: panel)
        label("Score \(score) • Best \(progress.bestScore(level))", size: 16, point: CGPoint(x: 0, y: 5), parent: panel)
        let message = SKLabelNode(fontNamed: "AvenirNext-Medium")
        message.text = success ? status.text : "Try a wall bounce or swap your next bubble."
        message.fontSize = 14
        message.numberOfLines = 2
        message.preferredMaxLayoutWidth = 278
        message.verticalAlignmentMode = .center
        message.position = CGPoint(x: 0, y: -35)
        panel.addChild(message)
        label(success ? (level == 49 ? "Tap for the celebration" : "Tap for the next level") : "Tap to retry", size: 16, point: CGPoint(x: 0, y: -88), parent: panel)
        shotsLabel.text = "\(shots)"
    }
}

private extension FestivalScene {
    func companionTexture(_ friend: Companion, frame: Int) -> SKTexture {
        SKTexture(rect: CGRect(x: CGFloat(frame) / 4, y: CGFloat(5 - friend.atlasIndex) / 6,
                               width: 0.25, height: 1.0 / 6), in: SKTexture(imageNamed: "festival-companion-motion"))
    }

    func animateCompanion(_ kind: Companion.Kind, frames: [Int], repeating: Bool = false) {
        let index = kind == .animal ? 0 : 1
        guard let sprite = gameRoot.childNode(withName: "companion-\(index)") as? SKSpriteNode else { return }
        let key = kind == .animal ? "loading" : "operating"
        if frames == [1, 2], sprite.action(forKey: key) != nil { return }
        sprite.removeAction(forKey: key)
        let friend = progress.selected(kind)
        let animation = SKAction.animate(with: frames.map { companionTexture(friend, frame: $0) }, timePerFrame: 0.1, resize: false, restore: true)
        sprite.run(repeating ? .repeatForever(animation) : animation, withKey: key)
    }

    func decorateMechanism() {
        let linkage = SKShapeNode(rectOf: CGSize(width: 72, height: 8), cornerRadius: 3)
        linkage.position = CGPoint(x: 249, y: 153)
        linkage.fillColor = UIColor(red: 0.83, green: 0.61, blue: 0.33, alpha: 1)
        linkage.strokeColor = .brown
        gameRoot.addChild(linkage)
        let wheel = SKNode()
        wheel.name = "handwheel"
        wheel.position = CGPoint(x: 280, y: 173)
        let rim = SKShapeNode(circleOfRadius: 21)
        rim.fillColor = UIColor(red: 0.36, green: 0.23, blue: 0.18, alpha: 1)
        rim.strokeColor = UIColor(red: 1, green: 0.82, blue: 0.5, alpha: 1)
        rim.lineWidth = 5
        wheel.addChild(rim)
        for index in 0..<6 {
            let spoke = SKShapeNode(rectOf: CGSize(width: 4, height: 33), cornerRadius: 2)
            spoke.zRotation = CGFloat(index) * .pi / 3
            spoke.fillColor = UIColor(red: 0.89, green: 0.69, blue: 0.4, alpha: 1)
            spoke.strokeColor = .clear
            wheel.addChild(spoke)
        }
        let crank = SKShapeNode(circleOfRadius: 5)
        crank.position = CGPoint(x: 0, y: 18)
        crank.fillColor = .brown
        crank.strokeColor = .white
        wheel.addChild(crank)
        gameRoot.addChild(wheel)
        let cue = SKNode()
        cue.name = "cancel-cue"
        cue.isHidden = true
        cue.zPosition = 18
        cue.position = origin
        let ring = SKShapeNode(circleOfRadius: 48)
        ring.fillColor = UIColor.systemPink.withAlphaComponent(0.18)
        ring.strokeColor = .systemPink
        ring.lineWidth = 3
        cue.addChild(ring)
        label("Release to cancel", size: 13, point: CGPoint(x: 0, y: 90), parent: cue)
        gameRoot.addChild(cue)
    }

    func atlasTexture(_ name: String, index: Int) -> SKTexture {
        SKTexture(rect: CGRect(x: CGFloat(index % 3) / 3, y: index < 3 ? 0.5 : 0,
                               width: 1.0 / 3, height: 0.5), in: SKTexture(imageNamed: name))
    }

    func shotNode(_ kind: BubbleShot) -> SKNode {
        switch kind {
        case .color(let color): return bubble(color)
        case .rainbow: return bubbleArt(index: 5)
        case .bomb: return bubbleArt(index: 6)
        }
    }

    func bubbleArt(index: Int) -> SKSpriteNode {
        let cell = CGRect(x: CGFloat(index % 4) / 4 + 0.0125,
                          y: (index < 4 ? 0.5 : 0) + 0.025,
                          width: 0.225, height: 0.45)
        let texture = SKTexture(rect: cell, in: SKTexture(imageNamed: "festival-bubbles"))
        return SKSpriteNode(texture: texture, size: CGSize(width: 42, height: 42))
    }

    func iconButton(_ symbol: String, name: String, point: CGPoint) {
        let box = panel(width: 48, height: 44, point: point, parent: gameRoot)
        box.name = name
        if let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold))?.withTintColor(.white, renderingMode: .alwaysOriginal) {
            let icon = SKSpriteNode(texture: SKTexture(image: image))
            icon.size = CGSize(width: 25, height: 25)
            box.addChild(icon)
        }
    }

    func boosterButton(_ kind: BubbleShot, name: String, point: CGPoint) {
        let box = SKShapeNode(circleOfRadius: 25)
        box.position = point
        box.name = name
        box.fillColor = UIColor(red: 0.23, green: 0.28, blue: 0.47, alpha: 0.6)
        box.strokeColor = .white.withAlphaComponent(0.8)
        box.lineWidth = 1.5
        box.addChild(shotNode(kind))
        let badge = SKShapeNode(circleOfRadius: 10)
        badge.fillColor = .darkGray
        badge.strokeColor = .white
        badge.position = CGPoint(x: 18, y: -18)
        box.addChild(badge)
        let count = SKLabelNode(fontNamed: "AvenirNext-Bold")
        count.name = "count"
        count.fontSize = 12
        count.verticalAlignmentMode = .center
        count.position = badge.position
        box.addChild(count)
        gameRoot.addChild(box)
    }

    func decorateRail() {
        let rail = SKShapeNode(rectOf: CGSize(width: 336, height: 15), cornerRadius: 5)
        rail.position = CGPoint(x: 195, y: 717)
        rail.fillColor = UIColor(red: 0.55, green: 0.31, blue: 0.16, alpha: 1)
        rail.strokeColor = UIColor(red: 1, green: 0.82, blue: 0.51, alpha: 1)
        rail.lineWidth = 2
        gameRoot.addChild(rail)
        for x in [CGFloat(34), CGFloat(356)] {
            let hanger = SKShapeNode(rectOf: CGSize(width: 7, height: 26), cornerRadius: 3)
            hanger.position = CGPoint(x: x, y: 738)
            hanger.fillColor = UIColor(red: 0.92, green: 0.72, blue: 0.43, alpha: 1)
            hanger.strokeColor = .brown
            gameRoot.addChild(hanger)
        }
        for column in 0..<BubbleBoard.columns {
            let hook = SKShapeNode(rectOf: CGSize(width: 3, height: 10), cornerRadius: 1)
            hook.position = CGPoint(x: left + CGFloat(column) * radius * 2, y: 705)
            hook.fillColor = UIColor(red: 1, green: 0.84, blue: 0.58, alpha: 1)
            hook.strokeColor = .clear
            gameRoot.addChild(hook)
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
        let stationSymbol = ["basket.fill", "leaf.fill", "lightbulb.fill", "cup.and.saucer.fill", "sparkles"][host.area]
        if let image = UIImage(systemName: stationSymbol)?.withTintColor(.systemYellow, renderingMode: .alwaysOriginal) {
            let prop = SKSpriteNode(texture: SKTexture(image: image), size: CGSize(width: 36, height: 36))
            prop.position = CGPoint(x: 320, y: 426)
            overlay.addChild(prop)
        }
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
        let bodies = ["Drag above the launcher to aim. Release to shoot. Drag back down toward the launcher to cancel. Match three bubbles with the same color and symbol.",
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
