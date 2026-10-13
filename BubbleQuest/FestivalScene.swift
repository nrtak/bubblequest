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
    private let progress = GameProgress(defaults: ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) ? UserDefaults(suiteName: "BubbleQuestPreview")! : .standard)
    private let audio = FestivalAudio()
    private let gameRoot = SKNode()
    private var mapArea = 0
    private var menuKind = "title"
    private var returnMenu = "game"
    private var friendsPage = 0
    private var attemptCounted = false
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
    private var questPlay = QuestPlay()
    private var completedQuest: FestivalQuest?
    private var selectedQuest: FestivalQuest?
    private var questArea = 0
    private var wheelSpinning = false
    private var pendingGift: BubbleShot?
    private var hasStartedPuzzle = false
    private var freeRainbow = true
    private var freeBomb = true
    private var challengeMode = false
    private var specialToLearn: SpecialBubble?
    private var powerObserver: NSObjectProtocol?
    private var questMarkers: [Cell: String] = [:]

    deinit { if let powerObserver { NotificationCenter.default.removeObserver(powerObserver) } }

    override func didMove(to view: SKView) {
        guard children.isEmpty else { return }
        view.preferredFramesPerSecond = 60
        powerObserver = NotificationCenter.default.addObserver(forName: .NSProcessInfoPowerStateDidChange, object: nil, queue: .main) { [weak self] _ in self?.updateControlLayout() }
        backgroundColor = UIColor(red: 0.12, green: 0.14, blue: 0.28, alpha: 1)
        addChild(gameRoot)
        decorate()
        progress.adventure.synchronize(completedLevels: progress.completedCount)
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
        hasStartedPuzzle = progress.checkpoint != nil
        if ProcessInfo.processInfo.arguments.contains("--dusk-preview") { level = 49 }
        if ProcessInfo.processInfo.arguments.contains("--courtyard-preview") { level = 10 }
        if ProcessInfo.processInfo.arguments.contains("--water-preview") { level = 5 }
        if ProcessInfo.processInfo.arguments.contains("--tea-preview") { level = 14 }
        if ProcessInfo.processInfo.arguments.contains("--aki-preview") { level = 20 }
        if ProcessInfo.processInfo.arguments.contains("--lantern-preview") { level = 22 }
        if ProcessInfo.processInfo.arguments.contains("--pearl-preview") { level = 32 }
        if ProcessInfo.processInfo.arguments.contains("--spark-preview") { level = 42 }
        mapArea = level / 10
        startLevel(restoring: !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }))
        if ProcessInfo.processInfo.arguments.contains("--friends-preview") { friendsPage = 1; showFriends() }
        else if ProcessInfo.processInfo.arguments.contains("--quest-preview") { showQuests(area: 2) }
        else if ProcessInfo.processInfo.arguments.contains("--quest-detail-preview") { showQuest(FestivalQuest.all[2]) }
        else if ProcessInfo.processInfo.arguments.contains("--quest-reward-preview") {
            for index in 0..<23 { progress.recordVictory(index: index, score: 200, stars: 1) }
            let quest = FestivalQuest.all[2]
            progress.adventure.accept(quest, unlockedLevel: progress.unlockedLevel)
            for index in 20..<23 { progress.adventure.recordWin(level: index, play: QuestPlay(collected: [quest.id]), completedLevels: progress.completedCount) }
            showQuest(quest)
        }
        else if ProcessInfo.processInfo.arguments.contains("--wheel-preview") { progress.adventure.synchronize(completedLevels: 5); showWheel() }
        else if ProcessInfo.processInfo.arguments.contains("--ending-preview") { showEnding() }
        else if ProcessInfo.processInfo.arguments.contains("--settings-preview") { returnMenu = "title"; showSettings() }
        else if ProcessInfo.processInfo.arguments.contains("--map-preview") { showLevels() }
        else if ProcessInfo.processInfo.arguments.contains("--host-preview") { showHost(FestivalHost.all[mapArea]) }
        else if ProcessInfo.processInfo.arguments.contains("--cancel-preview") { updateAim(CGPoint(x: 195, y: 220)) }
        else if ProcessInfo.processInfo.arguments.contains("--gameplay-preview") { updateAim(CGPoint(x: 242, y: 600)) }
        else { showTitle() }
    }

    func setActive(_ active: Bool) {
        if !active { saveCheckpoint() }
        suspended = !active
        isPaused = !active
        aiming = false
        aimGesture.cancel()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        guide.removeAllChildren()
        audio.suspend(!active)
        audio.update(area: level / 10, enabled: progress.enabled(.music), volume: progress.musicVolume)
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
        let veil = SKShapeNode(rectOf: CGSize(width: 336, height: 360), cornerRadius: 14)
        veil.name = "board-veil"; veil.position = CGPoint(x: 195, y: 529)
        veil.fillColor = .black; veil.strokeColor = .clear; veil.zPosition = -3; veil.alpha = 0.1
        gameRoot.addChild(veil)
        let ambient = SKNode(); ambient.name = "ambient"; ambient.zPosition = -4
        gameRoot.addChild(ambient)
        for index in 0..<8 {
            let glow = SKShapeNode(circleOfRadius: 1.5)
            glow.fillColor = .white; glow.strokeColor = .clear; glow.alpha = 0.45
            glow.position = CGPoint(x: index % 2 == 0 ? 20 : 375, y: 380 + CGFloat(index) * 45)
            ambient.addChild(glow)
            glow.run(.repeatForever(.sequence([.group([.moveBy(x: 0, y: 7, duration: 2), .fadeAlpha(to: 0.12, duration: 2)]), .group([.moveBy(x: 0, y: -7, duration: 2), .fadeAlpha(to: 0.45, duration: 2)])])))
        }
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
            companion.anchorPoint = CGPoint(x: 0.5, y: 0)
            companion.position = CGPoint(x: x, y: 134)
            companion.name = "companion-\(index)"
            gameRoot.addChild(companion)
        }
        let base = SKShapeNode(rectOf: CGSize(width: 354, height: 24), cornerRadius: 5)
        base.position = CGPoint(x: origin.x, y: 126)
        base.zPosition = -1
        base.fillColor = UIColor(red: 0.43, green: 0.23, blue: 0.13, alpha: 1)
        base.strokeColor = UIColor(red: 1, green: 0.77, blue: 0.42, alpha: 1)
        base.lineWidth = 3
        gameRoot.addChild(base)
        let surface = SKShapeNode(rectOf: CGSize(width: 350, height: 14), cornerRadius: 4)
        surface.position = CGPoint(x: origin.x, y: 138)
        surface.zPosition = -0.5
        surface.fillColor = UIColor(red: 0.76, green: 0.48, blue: 0.26, alpha: 1)
        surface.strokeColor = UIColor(red: 1, green: 0.79, blue: 0.43, alpha: 1)
        gameRoot.addChild(surface)
        for x in [CGFloat(35), 145, 245, 355] {
            let support = SKShapeNode(rectOf: CGSize(width: 14, height: 24), cornerRadius: 2)
            support.position = CGPoint(x: x, y: 106)
            support.zPosition = -1.5
            support.fillColor = UIColor(red: 0.38, green: 0.20, blue: 0.11, alpha: 1)
            support.strokeColor = UIColor(red: 0.82, green: 0.58, blue: 0.32, alpha: 1)
            gameRoot.addChild(support)
        }
        for x in [CGFloat(74), 319] {
            let shadow = SKShapeNode(ellipseOf: CGSize(width: 70, height: 8))
            shadow.position = CGPoint(x: x, y: 139)
            shadow.zPosition = -0.25
            shadow.fillColor = UIColor.brown.withAlphaComponent(0.45)
            shadow.strokeColor = .clear
            gameRoot.addChild(shadow)
        }
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

    private func startLevel(restoring: Bool = false) {
        let saved = restoring ? progress.checkpoint : nil
        if let saved { level = saved.level; challengeMode = saved.challenge ?? false }
        pendingGift = nil
        gameRoot.childNode(withName: "result")?.removeFromParent()
        projectile?.removeFromParent()
        projectile = nil
        guide.removeAllChildren()
        playfield.removeAllChildren()
        nodes.removeAll()
        board = .level(level)
        shots = LevelCatalog.level(level).shots
        rainbowLeft = 1 + progress.adventure.rainbowGifts
        bombLeft = 1 + progress.adventure.bombGifts
        freeRainbow = !challengeMode; freeBomb = !challengeMode
        if challengeMode { shots = max(12, shots * 3 / 4); rainbowLeft = 0; bombLeft = 0 }
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
            sprite?.position.y = 134
            sprite?.zRotation = 0
            sprite?.xScale = index == 1 ? -1 : 1
            sprite?.run(.repeatForever(.sequence([.scaleY(to: 1.015, duration: 1.5), .scaleY(to: 1, duration: 1.5)])), withKey: "breathing")
        }
        score = 0
        questPlay = QuestPlay()
        attemptCounted = false
        completedQuest = nil
        finished = false
        aiming = false
        updateMachineStyle()
        let area = LevelCatalog.areas[level / 10]
        backdrop?.texture = SKTexture(imageNamed: LevelCatalog.level(level).background)
        backdrop?.color = UIColor(red: 0.25, green: 0.27, blue: 0.55, alpha: 1)
        backdrop?.colorBlendFactor = area.nightTint ? 0.18 : 0
        audio.update(area: level / 10, enabled: progress.enabled(.music), volume: progress.musicVolume)
        if let saved, let restoredBoard = saved.board {
            board = restoredBoard; shots = saved.shots; score = saved.score
            currentColor = saved.currentColor; nextColor = saved.nextColor; colorBag = saved.bag
            freeRainbow = saved.freeRainbow ?? (saved.rainbow > 0)
            freeBomb = saved.freeBomb ?? (saved.bomb > 0)
            rainbowLeft = challengeMode ? 0 : (freeRainbow ? 1 : 0) + progress.adventure.rainbowGifts
            bombLeft = challengeMode ? 0 : (freeBomb ? 1 : 0) + progress.adventure.bombGifts
            questPlay = saved.play
            attemptCounted = true
        }
        for (cell, color) in board.bubbles {
            let node = board.specials[cell].map { specialBubble($0) } ?? bubble(color)
            node.position = point(cell)
            playfield.addChild(node)
            nodes[cell] = node
        }
        if saved == nil { currentColor = availableColor(); nextColor = availableColor() }
        reload()
        refreshHUD()
        addQuestMarker()
        applyCompanionPins()
        updateControlLayout()
        saveCheckpoint()
    }

    private func makeMenu(background: String) -> SKNode {
        saveCheckpoint()
        levelMenu?.removeFromParent()
        aiming = false
        aimGesture.cancel()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        guide.removeAllChildren()
        setOperatorHands(working: false)
        gameRoot.isPaused = true
        gameRoot.removeAction(forKey: "control-help")
        view?.preferredFramesPerSecond = 30
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
        let overlay = makeMenu(background: "festival-day")
        let logo = SKSpriteNode(imageNamed: "festival-logo")
        logo.size = CGSize(width: 285, height: 190)
        logo.position = CGPoint(x: 195, y: 683)
        overlay.addChild(logo)
        panel(width: 342, height: 482, point: CGPoint(x: 195, y: 340), parent: overlay)
        label("Home", size: 26, point: CGPoint(x: progress.pendingBuddy == nil ? 195 : 113, y: 550), parent: overlay)
        if progress.pendingBuddy != nil { menuButton("New buddy!", name: "new-buddy", point: CGPoint(x: 271, y: 556), parent: overlay, width: 154, height: 44) }
        let saved = progress.checkpoint
        menuButton(saved == nil ? "Play" : "Continue puzzle", name: saved == nil ? "start-adventure" : "resume-play", point: CGPoint(x: 195, y: 489), parent: overlay, height: 54)
        menuButton("Festival map", name: "start-adventure", point: CGPoint(x: 195, y: 421), parent: overlay, height: 50)
        menuButton("Friends", name: "friends", point: CGPoint(x: 195, y: 357), parent: overlay, height: 50)
        menuButton("Settings", name: "settings", point: CGPoint(x: 195, y: 293), parent: overlay, height: 50)
        menuButton("Saved progress", name: "saved-progress", point: CGPoint(x: 195, y: 229), parent: overlay, height: 50)
        label("\(progress.completedCount)/50 stops • \(progress.totalStars) stars", size: 16, point: CGPoint(x: 195, y: 175), parent: overlay)
        label("Progress saves automatically on this iPhone", size: 13, point: CGPoint(x: 195, y: 140), parent: overlay)
        label("Irvine Dynamics", size: 12, point: CGPoint(x: 195, y: 62), parent: overlay)
    }

    private func showSavedProgress() {
        menuKind = "saved-progress"
        let overlay = makeMenu(background: "festival-courtyard")
        panel(width: 342, height: 468, point: CGPoint(x: 195, y: 441), parent: overlay)
        label("Saved progress", size: 28, point: CGPoint(x: 195, y: 630), parent: overlay)
        paragraph("Your levels, stars, friends, quests and prizes save automatically on this iPhone.", y: 554, parent: overlay)
        label("\(progress.completedCount)/50 stops • \(progress.totalStars)/150 stars", size: 19, point: CGPoint(x: 195, y: 468), parent: overlay)
        label(progress.checkpoint.map { "Puzzle \($0.level + 1) ready to resume" } ?? "No unfinished puzzle", size: 17, point: CGPoint(x: 195, y: 428), parent: overlay)
        let stamp = progress.lastSaved.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "Ready for your first adventure"
        label(stamp, size: 14, point: CGPoint(x: 195, y: 385), parent: overlay)
        menuButton("Save now", name: "save-now", point: CGPoint(x: 195, y: 306), parent: overlay, height: 50)
        label("This save stays on this device", size: 14, point: CGPoint(x: 195, y: 246), parent: overlay)
        menuButton("Home", name: "home", point: CGPoint(x: 195, y: 136), parent: overlay, height: 50)
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
        let station = panel(width: 128, height: 174, point: CGPoint(x: 80, y: 404), parent: overlay)
        station.name = "meet-host"
        station.fillColor = UIColor(red: 0.39, green: 0.23, blue: 0.15, alpha: 0.94)
        station.strokeColor = UIColor(red: 1, green: 0.79, blue: 0.43, alpha: 1)
        station.lineWidth = 2.5
        let awning = SKShapeNode(rectOf: CGSize(width: 136, height: 18), cornerRadius: 5)
        awning.position = CGPoint(x: 0, y: 80)
        awning.fillColor = .systemRed
        awning.strokeColor = UIColor(red: 1, green: 0.94, blue: 0.81, alpha: 1)
        station.addChild(awning)
        let host = SKSpriteNode(texture: atlasTexture("festival-hosts", index: mapArea), size: CGSize(width: 104, height: 104))
        host.position = CGPoint(x: 0, y: 28)
        station.addChild(host)
        label("Meet \(FestivalHost.all[mapArea].name)", size: 19, point: CGPoint(x: 0, y: -50), parent: station)
        label(["Market stall", "Courtyard", "Lantern stall", "Food stall", "Fireworks"][mapArea], size: 11, point: CGPoint(x: 0, y: -70), parent: station)
        station.alpha = progress.hostIsAvailable(FestivalHost.all[mapArea]) ? 1 : 0.55
        if progress.hostIsAvailable(FestivalHost.all[mapArea]) && !progress.hasMet(FestivalHost.all[mapArea]) {
            station.run(.repeatForever(.sequence([.scale(to: 1.025, duration: 1.1), .scale(to: 1, duration: 1.1)])))
        }
        addQuestDecorations(to: station)
        host.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 1.6), .moveBy(x: 0, y: -3, duration: 1.6)])))
        let wheelStop = panel(width: 128, height: 52, point: CGPoint(x: 80, y: 270), parent: overlay)
        wheelStop.name = "open-wheel"
        label("Prize Wheel", size: 18, point: CGPoint(x: 0, y: 3), parent: wheelStop)
        label("Free spins: \(progress.adventure.availableSpins)", size: 14, point: CGPoint(x: 0, y: -15), parent: wheelStop)
        menuButton("Current stop", name: "current-stop", point: CGPoint(x: 195, y: 133), parent: overlay, width: 210, height: 44)
        menuButton("Home", name: "home", point: CGPoint(x: 70, y: 75), parent: overlay, width: 108, height: 44)
        menuButton("Friends", name: "friends", point: CGPoint(x: 195, y: 75), parent: overlay, width: 112, height: 44)
        menuButton("Settings", name: "settings", point: CGPoint(x: 320, y: 75), parent: overlay, width: 112, height: 44)
    }

    private func availableColor() -> Int {
        var random = SystemRandomNumberGenerator()
        return BubbleColorQueue.draw(board: board, bag: &colorBag, using: &random)
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
            audio.effect("load", enabled: progress.enabled(.effects), volume: progress.effectsVolume)
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
        refreshQuestBadge()
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
        if aimGesture.shouldCancel { setOperatorHands(working: false); return }
        let angle = aimGesture.angle
        aim = CGVector(dx: sin(angle), dy: cos(angle))
        gameRoot.childNode(withName: "cannon")?.zRotation = -CGFloat(angle)
        gameRoot.childNode(withName: "handwheel")?.zRotation = -CGFloat(angle) * 2.5
        animateCompanion(.human, frames: [1, 2], repeating: false)
        guide.removeAllChildren()
        guard progress.enabled(.guide) else { return }
        setOperatorHands(working: true)
        let flight = BubbleGeometry.flight(angle: angle, board: board)
        for point in BubbleGeometry.bouncePoints(flight) {
            let bounce = SKShapeNode(circleOfRadius: 7)
            bounce.position = CGPoint(x: point.x, y: point.y)
            bounce.fillColor = .systemYellow; bounce.strokeColor = .white; bounce.lineWidth = 2
            guide.addChild(bounce)
        }
        if let armed, let landing = flight.landing {
            var preview = board
            let result = preview.place(armed, at: landing)
            for cell in result.matched.union(result.dropped) where board.bubbles[cell] != nil {
                let highlight = SKShapeNode(circleOfRadius: 19)
                highlight.position = point(cell); highlight.fillColor = .clear
                highlight.strokeColor = result.matched.contains(cell) ? .systemYellow : .systemTeal
                highlight.lineWidth = 3; guide.addChild(highlight)
            }
        }
        for (index, point) in flight.points.enumerated() where index % 7 == 0 {
            let dot = SKShapeNode(circleOfRadius: 2.5)
            dot.fillColor = .white
            dot.strokeColor = .clear
            dot.alpha = progress.enabled(.contrast) ? 0.95 : 0.65
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
        gameRoot.removeAction(forKey: "control-help")
        guard !suspended, let location = touches.first?.location(in: self) else { return }
        let names = interactionNames(at: location)
        if levelMenu != nil { handleMenu(names); return }
        if let control = names.first(where: { ["rainbow", "bomb", "swap"].contains($0) }) {
            gameRoot.run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in self?.showControlHelp(control) }]), withKey: "control-help")
        }
        if names.contains("quest-objective") { showObjectives(); return }
        if names.contains("levels") { mapArea = level / 10; showLevels(); return }
        if names.contains("settings") { returnMenu = "game"; showSettings(); return }
        if names.contains("retry") { showRetryPrompt(); return }
        if finished {
            if let buddy = progress.pendingBuddy { showBuddyWelcome(buddy); return }
            if let completedQuest { showQuest(completedQuest); return }
            if challengeMode && won { challengeMode = false; showQuests(area: level / 10); return }
            if won && level == 49 { showEnding(); return }
            if won { level += 1 }
            beginSelectedLevel()
            return
        }
        guard projectile == nil, !loadingBubble else { return }
        if names.contains("rainbow") && rainbowLeft > 0 { armed = armed == .rainbow ? nil : .rainbow; reload(); refreshHUD(); return }
        if names.contains("bomb") && bombLeft > 0 { armed = armed == .bomb ? nil : .bomb; reload(); refreshHUD(); return }
        if names.contains("swap") { armed = nil; swap(&currentColor, &nextColor); reload(); refreshHUD(); return }
        guard location.y > 350 && location.y < 710 else { return }
        aiming = true
        aimGesture.begin(at: BubblePoint(x: Double(location.x), y: Double(location.y)))
        updateAim(location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aiming, let point = touches.first?.location(in: self) else { return }
        updateAim(point)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        gameRoot.removeAction(forKey: "control-help")
        aiming = false
        aimGesture.cancel()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        guide.removeAllChildren()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        gameRoot.removeAction(forKey: "control-help")
        guard aiming, !finished, projectile == nil, !loadingBubble, levelMenu == nil, let shot = loaded else { return }
        aiming = false
        guide.removeAllChildren()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        setOperatorHands(working: false)
        let lift = touches.first?.location(in: self)
        guard let angle = aimGesture.end(at: lift.map { BubblePoint(x: Double($0.x), y: Double($0.y)) }) else { return }
        if !attemptCounted && !challengeMode && !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) {
            progress.recordAttempt(level)
            attemptCounted = true
        }
        let kind = armed ?? .color(currentColor)
        let flight = BubbleGeometry.flight(angle: angle, board: board)
        questPlay.bounces += BubbleGeometry.bouncePoints(flight).count
        projectile = shot
        loaded = nil
        if kind == .rainbow { if freeRainbow { freeRainbow = false } else { pendingGift = .rainbow }; rainbowLeft -= 1 }
        if kind == .bomb { if freeBomb { freeBomb = false } else { pendingGift = .bomb }; bombLeft -= 1 }
        armed = nil
        shots -= 1
        audio.effect("launch", enabled: progress.enabled(.effects), volume: progress.effectsVolume)
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
        if let pendingGift { progress.adventure.consumeGift(pendingGift); self.pendingGift = nil }
        let oldColors = board.bubbles
        let oldSpecials = board.specials
        let result = board.place(kind, at: cell)
        questPlay.collected.formUnion(result.matched.union(result.dropped).compactMap { questMarkers[$0] })
        if level == 0 && !result.matched.isEmpty {
            progress.practiceDone = true; gameRoot.childNode(withName: "practice-caption")?.removeFromParent()
        }
        questPlay.dropped += result.dropped.count
        questPlay.colors.formUnion(result.matched.union(result.dropped).compactMap { oldColors[$0] })
        let refunds = result.matched.filter { oldSpecials[$0] == .riverPearl }.count
        shots = min(LevelCatalog.level(level).shots, shots + refunds)
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        for (index, match) in result.matched.sorted(by: { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }).enumerated() {
            if index < (quiet ? 8 : 12) { popEffect(at: point(match), color: palette[oldColors[match] ?? currentColor], special: oldSpecials[match], quiet: quiet) }
            nodes.removeValue(forKey: match)?.run(.sequence([.group([.scale(to: quiet ? 1 : 1.18, duration: 0.12), .fadeOut(withDuration: 0.16)]), .removeFromParent()]))
        }
        for (index, dropped) in result.dropped.enumerated() {
            if !quiet && index < 6 { dropTrail(at: point(dropped), color: palette[oldColors[dropped] ?? currentColor]) }
            nodes.removeValue(forKey: dropped)?.run(.sequence([.group([.moveBy(x: 0, y: quiet ? -24 : -650, duration: quiet ? 0.18 : 0.55), .rotate(byAngle: quiet ? 0 : 1.2, duration: 0.55), .fadeOut(withDuration: quiet ? 0.18 : 0.55)]), .removeFromParent()]))
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
            audio.effect(kind == .bomb ? "bomb" : "pop", enabled: progress.enabled(.effects), volume: progress.effectsVolume)
        }
        if board.bubbles.isEmpty { finish(success: true); return }
        if shots <= 0 || board.bubbles.keys.contains(where: { point($0).y < CGFloat(BubbleGeometry.lossLine) }) { finish(success: false); return }
        currentColor = Set(board.bubbles.values).contains(nextColor) ? nextColor : availableColor()
        nextColor = availableColor()
        reload(animateLoading: true)
        refreshHUD()
        saveCheckpoint()
    }

    private func finish(success: Bool) {
        progress.clearCheckpoint()
        if !challengeMode && !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) {
            progress.recordOutcome(index: level, won: success, shotsRemaining: shots)
        }
        finished = true
        won = success
        aiming = false
        guide.removeAllChildren()
        loaded?.removeFromParent()
        nextNode?.removeFromParent()
        animateCompanion(.animal, frames: success ? [3, 0, 3, 0] : [0])
        animateCompanion(.human, frames: success ? [3, 0, 3, 0] : [0])
        if success {
            if challengeMode && LevelCatalog.level(level).stars(shotsRemaining: shots) == 3 { progress.recordChallenge(level / 10) }
            score += shots * 25
            status.text = level % 3 == 0 ? FestivalHost.all[level / 10].encouragement : "Beautiful popping!"
            let unlocked = progress.recordVictory(index: level, score: score,
                                                   stars: LevelCatalog.level(level).stars(shotsRemaining: shots))
            let newQuests = progress.adventure.recordWin(level: level, play: questPlay, completedLevels: progress.completedCount)
            completedQuest = newQuests.first
            if let completedQuest { status.text = "Story complete: \(completedQuest.title)" }
            if !unlocked.isEmpty && completedQuest == nil { status.text = "New friend: \(unlocked.map { $0.name }.joined(separator: ", "))" }
            if progress.enabled(.vibration) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            audio.effect("victory", enabled: progress.enabled(.effects), volume: progress.effectsVolume)
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
        let panel = SKShapeNode(rectOf: CGSize(width: 330, height: 270), cornerRadius: 24)
        panel.name = "result"
        panel.fillColor = UIColor(red: 0.21, green: 0.22, blue: 0.39, alpha: 0.98)
        panel.strokeColor = .systemOrange
        panel.position = CGPoint(x: 195, y: 414)
        panel.zPosition = 20
        gameRoot.addChild(panel)
        label(success ? "Festival cheers! 🎉" : "Try another angle", size: 23, point: CGPoint(x: 0, y: 100), parent: panel)
        label(success ? String(repeating: "★", count: LevelCatalog.level(level).stars(shotsRemaining: shots)) : "Keep trying!", size: 23, point: CGPoint(x: 0, y: 64), parent: panel)
        label("Score \(score) • Best \(progress.bestScore(level))", size: 16, point: CGPoint(x: 0, y: 31), parent: panel)
        if success { label("★★★ Save \(LevelCatalog.level(level).shots / 2) shots • ★★ Save \(LevelCatalog.level(level).shots / 4)", size: 11, point: CGPoint(x: 0, y: 6), parent: panel) }
        let message = SKLabelNode(fontNamed: "AvenirNext-Medium")
        message.text = success ? status.text : "Try a wall bounce or swap your next bubble."
        message.fontSize = 14
        message.numberOfLines = 2
        message.preferredMaxLayoutWidth = 278
        message.verticalAlignmentMode = .center
        message.position = CGPoint(x: 0, y: -35)
        panel.addChild(message)
        label(success ? (completedQuest != nil ? "Tap to see your story reward" : level == 49 ? "Tap for the celebration" : "Tap for the next level") : "Tap to retry", size: 16, point: CGPoint(x: 0, y: -109), parent: panel)
        shotsLabel.text = "\(shots)"
    }
}

private extension FestivalScene {
    func interactionNames(at location: CGPoint) -> [String] {
        let parent = levelMenu ?? gameRoot
        let point = convert(location, to: parent)
        let hits = parent.nodes(at: point)
        let names = hits.flatMap { node -> [String] in
            var result: [String] = []; var current: SKNode? = node
            while let value = current { if let name = value.name { result.append(name) }; current = value.parent }
            return result
        }
        // Keep controls at least 44 physical points tall on compact iPhones.
        let scale = min((view?.bounds.width ?? size.width) / size.width, (view?.bounds.height ?? size.height) / size.height)
        let minimum = 44 / max(0.1, scale)
        let targets = parent.children.filter { $0 is SKShapeNode && $0.name != nil && $0.name != "board-veil" && $0.name != "result" && $0.name != "control-tip" }
        if targets.contains(where: { names.contains($0.name!) }) { return names }
        let nearby = targets.filter { node in
            let rect = node.calculateAccumulatedFrame()
            return rect.insetBy(dx: -max(0, (minimum - rect.width) / 2), dy: -max(0, (minimum - rect.height) / 2)).contains(point)
        }.min { a, b in
            let x = a.calculateAccumulatedFrame(), y = b.calculateAccumulatedFrame()
            return hypot(x.midX - point.x, x.midY - point.y) < hypot(y.midX - point.x, y.midY - point.y)
        }
        return nearby?.name.map { names + [$0] } ?? names
    }

    func questIcon(_ name: String, size: CGFloat, color: UIColor = .white) -> SKSpriteNode {
        let image = (UIImage(systemName: name) ?? UIImage(systemName: "star.fill")!)
            .withTintColor(color, renderingMode: .alwaysOriginal)
        return SKSpriteNode(texture: SKTexture(image: image), size: CGSize(width: size, height: size))
    }

    func showQuests(area: Int) {
        questArea = area
        menuKind = "quests"
        let overlay = makeMenu(background: LevelCatalog.areas[area].background)
        panel(width: 342, height: 150, point: CGPoint(x: 195, y: 702), parent: overlay)
        label("Festival favors", size: 30, point: CGPoint(x: 195, y: 744), parent: overlay)
        paragraph("A little help for our friends. Choose a story whenever you like.", y: 675, parent: overlay)
        let quests = FestivalQuest.all.filter { $0.area == area }
        for (index, quest) in quests.enumerated() {
            let card = panel(width: 342, height: 112, point: CGPoint(x: 195, y: 555 - CGFloat(index) * 136), parent: overlay)
            card.name = "quest-\(quest.id)"
            label(quest.title, size: 20, point: CGPoint(x: 0, y: 25), parent: card)
            let count = progress.adventure.count(quest)
            let text = progress.adventure.completed(quest) ? "Story complete • Choose colors" : progress.adventure.accepted(quest) ? "\(count)/3 • \(quest.steps[count])" : "Tap to hear the story"
            let detail = SKLabelNode(fontNamed: "AvenirNext-Medium")
            detail.text = text; detail.fontSize = 15; detail.numberOfLines = 2
            detail.preferredMaxLayoutWidth = 290; detail.verticalAlignmentMode = .center
            detail.position = CGPoint(x: 0, y: -17); card.addChild(detail)
        }
        if (area * 10..<area * 10 + 10).allSatisfy({ progress.stars($0) > 0 }) {
            menuButton("Extra challenge", name: "open-challenge", point: CGPoint(x: 195, y: 272), parent: overlay)
        }
        menuButton("Meet the neighbors", name: "neighbors", point: CGPoint(x: 195, y: 201), parent: overlay, height: 44)
        menuButton("Back to the map", name: "quest-back", point: CGPoint(x: 195, y: 130), parent: overlay)
    }

    func showNeighbors() {
        menuKind = "neighbors"
        let overlay = makeMenu(background: LevelCatalog.areas[questArea].background)
        panel(width: 342, height: 85, point: CGPoint(x: 195, y: 732), parent: overlay)
        label("Our festival neighbors", size: 26, point: CGPoint(x: 195, y: 748), parent: overlay)
        label(LevelCatalog.areas[questArea].name, size: 17, point: CGPoint(x: 195, y: 714), parent: overlay)
        for (index, neighbor) in FestivalNeighbor.all.filter({ $0.area == questArea }).enumerated() {
            let tile = panel(width: 342, height: 145, point: CGPoint(x: 195, y: 592 - CGFloat(index) * 170), parent: overlay)
            tile.name = "neighbor-\(neighbor.id)"
            let portrait = SKSpriteNode(texture: neighborTexture(neighbor), size: CGSize(width: 120, height: 120))
            portrait.position.x = -98; tile.addChild(portrait)
            label(neighbor.name, size: 23, point: CGPoint(x: 55, y: 29), parent: tile)
            label(neighbor.role, size: 12, point: CGPoint(x: 55, y: 0), parent: tile)
            label(progress.hasMet(neighbor) ? "Say hello again" : "Tap to meet", size: 14, point: CGPoint(x: 55, y: -32), parent: tile)
        }
        menuButton("Festival favors", name: "quest-list", point: CGPoint(x: 195, y: 140), parent: overlay)
    }

    func showNeighbor(_ neighbor: FestivalNeighbor) {
        guard progress.neighborIsAvailable(neighbor) else { return }
        let met = progress.hasMet(neighbor)
        progress.markMet(neighbor)
        menuKind = "neighbor-detail"
        let overlay = makeMenu(background: LevelCatalog.areas[neighbor.area].background)
        label("Meet \(neighbor.name)", size: 30, point: CGPoint(x: 195, y: 742), parent: overlay)
        let portrait = SKSpriteNode(texture: neighborTexture(neighbor), size: CGSize(width: 300, height: 300))
        portrait.position = CGPoint(x: 195, y: 560); overlay.addChild(portrait)
        panel(width: 342, height: 170, point: CGPoint(x: 195, y: 317), parent: overlay)
        paragraph(met ? neighbor.greeting : neighbor.introduction, y: 350, parent: overlay)
        menuButton("Visit another neighbor", name: "neighbors", point: CGPoint(x: 195, y: 163), parent: overlay, height: 44)
        menuButton("Back to the map", name: "quest-back", point: CGPoint(x: 195, y: 92), parent: overlay, height: 44)
    }

    func neighborTexture(_ neighbor: FestivalNeighbor) -> SKTexture {
        if neighbor.portraitIndex >= 6 {
            return SKTexture(rect: CGRect(x: CGFloat(neighbor.portraitIndex - 6) / 2, y: 0, width: 0.5, height: 1),
                             in: SKTexture(imageNamed: "festival-neighbors-extra"))
        }
        return atlasTexture("festival-neighbors", index: neighbor.portraitIndex)
    }

    func showQuest(_ quest: FestivalQuest) {
        selectedQuest = quest; questArea = quest.area; menuKind = "quest-detail"
        let overlay = makeMenu(background: LevelCatalog.areas[quest.area].background)
        panel(width: 342, height: 62, point: CGPoint(x: 195, y: 742), parent: overlay)
        label(quest.title, size: 24, point: CGPoint(x: 195, y: 745), parent: overlay)
        let portrait = quest.id == "toy" ? SKSpriteNode(texture: companionTexture(Companion.all[0], frame: 0)) : SKSpriteNode(texture: atlasTexture("festival-hosts", index: quest.area))
        portrait.size = CGSize(width: 190, height: 190); portrait.position = CGPoint(x: 195, y: 595)
        overlay.addChild(portrait)
        panel(width: 342, height: 205, point: CGPoint(x: 195, y: 380), parent: overlay)
        let completed = progress.adventure.completed(quest)
        if completed && quest.id == "toy" {
            portrait.position.y = 600
            let floor = SKShapeNode(rectOf: CGSize(width: 210, height: 12), cornerRadius: 4)
            floor.position = CGPoint(x: 195, y: 501); floor.fillColor = .brown; floor.strokeColor = .systemYellow
            overlay.addChild(floor)
            let toy = questIcon("tennisball.fill", size: 27, color: .systemYellow)
            toy.position = CGPoint(x: 247, y: 518); overlay.addChild(toy)
            portrait.run(.animate(with: [0, 3, 0, 3, 0].map { companionTexture(Companion.all[0], frame: $0) }, timePerFrame: 0.25))
        }
        if completed && quest.id == "picnic" {
            portrait.removeFromParent()
            let cloth = SKShapeNode(rectOf: CGSize(width: 220, height: 20), cornerRadius: 6)
            cloth.position = CGPoint(x: 195, y: 510); cloth.fillColor = .systemPink; cloth.strokeColor = .white
            overlay.addChild(cloth)
            for (index, kind) in [Companion.Kind.animal, .human].enumerated() {
                let friend = progress.selected(kind)
                let sprite = SKSpriteNode(texture: companionTexture(friend, frame: 0), size: CGSize(width: 90, height: 90))
                sprite.anchorPoint = CGPoint(x: 0.5, y: 0); sprite.position = CGPoint(x: index == 0 ? 145 : 245, y: 513)
                overlay.addChild(sprite)
            }
            let basket = questIcon("basket.fill", size: 28, color: .systemYellow)
            basket.position = CGPoint(x: 195, y: 526); overlay.addChild(basket)
        }
        paragraph(completed ? quest.thanks : quest.conversation(step: progress.adventure.count(quest)), y: 430, parent: overlay)
        if completed {
            if let friend = Companion.all.first(where: { $0.unlockQuest == quest.id }) {
                label("\(friend.name) has joined your friends!", size: 17, point: CGPoint(x: 195, y: 357), parent: overlay)
            }
            label("Choose a display color", size: 18, point: CGPoint(x: 195, y: 325), parent: overlay)
            for (index, color) in [UIColor.systemPink, .systemYellow, .systemTeal].enumerated() {
                let option = SKShapeNode(circleOfRadius: 25)
                option.position = CGPoint(x: 125 + CGFloat(index) * 70, y: 245)
                option.name = "quest-style-\(index)"; option.fillColor = color
                option.strokeColor = .white; option.lineWidth = progress.adventure.style(quest) == index ? 5 : 1.5
                overlay.addChild(option)
            }
            menuButton("Visit the display", name: "quest-back", point: CGPoint(x: 195, y: 172), parent: overlay, height: 44)
        } else {
            let step = progress.adventure.count(quest)
            label("\(step)/3 • \(quest.steps[step])", size: 15, point: CGPoint(x: 195, y: 343), parent: overlay)
            let buddy = Companion.all.first { $0.unlockQuest == quest.id }
            label(buddy.map { "Reward: \($0.name) joins as a buddy" } ?? "Reward: a festival decoration + free spin", size: 14, point: CGPoint(x: 195, y: 302), parent: overlay)
            menuButton(progress.adventure.accepted(quest) ? "Play a puzzle" : "I'll help!", name: progress.adventure.accepted(quest) ? "quest-play" : "quest-accept", point: CGPoint(x: 195, y: 222), parent: overlay)
        }
        menuButton("Stories", name: "quest-list", point: CGPoint(x: 195, y: 104), parent: overlay, width: 160, height: 44)
    }

    func addQuestDecorations(to station: SKNode) {
        let quests = FestivalQuest.all.filter { $0.area == mapArea && progress.adventure.completed($0) }
        for (index, quest) in quests.enumerated() {
            let colors: [UIColor] = [.systemPink, .systemYellow, .systemTeal]
            let color = colors[progress.adventure.style(quest)]
            if quest.id == "parcels" {
                for x in [CGFloat(-42), -14, 14, 42] {
                    let flag = questIcon("flag.fill", size: 15, color: color)
                    flag.position = CGPoint(x: x, y: 66); station.addChild(flag)
                }
                continue
            }
            for x in [CGFloat(-49), 49] {
                let prop: SKNode
                if quest.id == "lanterns" {
                    let paper = SKShapeNode(ellipseOf: CGSize(width: 17, height: 23))
                    paper.fillColor = color; paper.strokeColor = .white
                    let cord = SKShapeNode(rectOf: CGSize(width: 1.5, height: 79))
                    cord.fillColor = .white; cord.strokeColor = .clear; cord.position.y = 50.5; paper.addChild(cord)
                    prop = paper
                } else if quest.id == "pinwheels" {
                    let pinwheel = SKNode()
                    let stem = SKShapeNode(rectOf: CGSize(width: 2, height: 66))
                    stem.position.y = -34; stem.fillColor = .white; stem.strokeColor = .clear; pinwheel.addChild(stem)
                    let head = SKNode(); pinwheel.addChild(head)
                    for blade in 0..<4 {
                        let path = CGMutablePath(); path.move(to: .zero); path.addLine(to: CGPoint(x: 0, y: 13)); path.addLine(to: CGPoint(x: 11, y: 8)); path.closeSubpath()
                        let shape = SKShapeNode(path: path); shape.fillColor = blade % 2 == 0 ? color : .white
                        shape.strokeColor = .clear; shape.zRotation = CGFloat(blade) * .pi / 2; head.addChild(shape)
                    }
                    if !UIAccessibility.isReduceMotionEnabled { head.run(.repeatForever(.rotate(byAngle: .pi * 2, duration: 4))) }
                    prop = pinwheel
                } else { prop = questIcon(quest.symbol, size: 19, color: color) }
                prop.position = CGPoint(x: x, y: -10 + CGFloat(index) * 26)
                station.addChild(prop)
                if !UIAccessibility.isReduceMotionEnabled && quest.id != "pinwheels" {
                    prop.run(.repeatForever(.sequence([.fadeAlpha(to: 0.75, duration: 1.2), .fadeAlpha(to: 1, duration: 1.2)])))
                }
            }
        }
        if progress.adventure.hasBunting && !quests.contains(where: { $0.id == "parcels" }) {
            for x in [CGFloat(-30), 0, 30] {
                let flag = questIcon("flag.fill", size: 13, color: .systemTeal)
                flag.position = CGPoint(x: x, y: 66); station.addChild(flag)
            }
        }
        if progress.challengeWon(mapArea) {
            let ribbon = questIcon("rosette", size: 23, color: .systemYellow)
            ribbon.position = CGPoint(x: 52, y: -65); station.addChild(ribbon)
        }
    }

    func showWheel() {
        menuKind = "wheel"; wheelSpinning = false
        let overlay = makeMenu(background: LevelCatalog.areas[mapArea].background)
        panel(width: 342, height: 112, point: CGPoint(x: 195, y: 718), parent: overlay)
        label("Festival Prize Wheel", size: 26, point: CGPoint(x: 195, y: 742), parent: overlay)
        let credits = SKLabelNode(fontNamed: "AvenirNext-Bold")
        credits.name = "wheel-credits"; credits.fontSize = 20
        credits.text = "Free spins: \(progress.adventure.availableSpins)"
        credits.position = CGPoint(x: 195, y: 694); overlay.addChild(credits)
        let wheel = SKNode(); wheel.name = "prize-wheel"; wheel.position = CGPoint(x: 195, y: 478)
        overlay.addChild(wheel)
        let colors: [UIColor] = [.systemPink, .systemYellow, .systemTeal, .systemPurple, .systemBlue, .systemOrange]
        for (index, prize) in FestivalPrize.allCases.enumerated() {
            let start = CGFloat(index) * .pi / 3
            let path = CGMutablePath(); path.move(to: .zero)
            path.addArc(center: .zero, radius: 139, startAngle: start, endAngle: start + .pi / 3, clockwise: false)
            path.closeSubpath()
            let wedge = SKShapeNode(path: path); wedge.fillColor = colors[index]; wedge.strokeColor = .white; wedge.lineWidth = 2
            wheel.addChild(wedge)
            let icon: SKNode = prize == .rainbow ? shotNode(.rainbow) : prize == .bomb ? shotNode(.bomb) : questIcon(prize.symbol, size: 32)
            icon.position = CGPoint(x: cos(start + .pi / 6) * 93, y: sin(start + .pi / 6) * 93)
            wheel.addChild(icon)
        }
        let pointer = SKShapeNode(path: { let p = CGMutablePath(); p.move(to: CGPoint(x: -13, y: 14)); p.addLine(to: CGPoint(x: 13, y: 14)); p.addLine(to: CGPoint(x: 0, y: -9)); p.closeSubpath(); return p }())
        pointer.position = CGPoint(x: 195, y: 624); pointer.fillColor = .white; pointer.strokeColor = .systemYellow; overlay.addChild(pointer)
        let result = SKLabelNode(fontNamed: "AvenirNext-Bold")
        result.name = "wheel-result"; result.fontSize = 23
        result.text = progress.adventure.lastPrize.map { "Last gift: \($0.title)" } ?? "A little festival surprise"
        result.position = CGPoint(x: 195, y: 280); overlay.addChild(result)
        label("Earn a spin every five new levels", size: 14, point: CGPoint(x: 195, y: 240), parent: overlay)
        label("80% boosters • 20% keepsakes", size: 13, point: CGPoint(x: 195, y: 260), parent: overlay)
        label("and for each completed side quest.", size: 14, point: CGPoint(x: 195, y: 219), parent: overlay)
        label("Saved boosters: \(progress.adventure.rainbowGifts) rainbow • \(progress.adventure.bombGifts) bomb", size: 13, point: CGPoint(x: 195, y: 196), parent: overlay)
        menuButton("Spin", name: "wheel-spin", point: CGPoint(x: 195, y: 165), parent: overlay)
        overlay.childNode(withName: "wheel-spin")?.alpha = progress.adventure.availableSpins > 0 ? 1 : 0.4
        menuButton("Back to the map", name: "quest-back", point: CGPoint(x: 195, y: 92), parent: overlay, height: 44)
    }

    func spinWheel() {
        guard !wheelSpinning, let overlay = levelMenu, let wheel = overlay.childNode(withName: "prize-wheel") else { return }
        var random = SystemRandomNumberGenerator()
        guard let prize = progress.adventure.draw(using: &random), let index = FestivalPrize.allCases.firstIndex(of: prize) else { return }
        wheelSpinning = true
        (overlay.childNode(withName: "wheel-credits") as? SKLabelNode)?.text = "Free spins: \(progress.adventure.availableSpins)"
        overlay.childNode(withName: "wheel-spin")?.alpha = 0.4
        var angle = CGFloat.pi / 2 - (CGFloat(index) + 0.5) * .pi / 3 - wheel.zRotation.truncatingRemainder(dividingBy: .pi * 2)
        while angle < 0 { angle += .pi * 2 }
        let spin = SKAction.rotate(byAngle: UIAccessibility.isReduceMotionEnabled ? angle : .pi * 8 + angle, duration: UIAccessibility.isReduceMotionEnabled ? 0.3 : 2.8); spin.timingMode = .easeOut
        wheel.run(.sequence([spin, .run { [weak self, weak overlay] in
            guard let self else { return }
            self.wheelSpinning = false
            (overlay?.childNode(withName: "wheel-result") as? SKLabelNode)?.text = "You won: \(prize.title)!"
            overlay?.childNode(withName: "wheel-spin")?.alpha = self.progress.adventure.availableSpins > 0 ? 1 : 0.4
            self.showWheelReward(prize)
            self.audio.effect("victory", enabled: self.progress.enabled(.effects), volume: self.progress.effectsVolume)
        }]))
    }

    func showBuddyWelcome(_ buddy: Companion) {
        menuKind = "buddy-welcome"
        let overlay = makeMenu(background: LevelCatalog.areas[level / 10].background)
        label("Meet your new buddy!", size: 27, point: CGPoint(x: 195, y: 724), parent: overlay)
        let portrait = SKSpriteNode(texture: companionTexture(buddy, frame: 0), size: CGSize(width: 236, height: 236))
        portrait.position = CGPoint(x: 195, y: 549); overlay.addChild(portrait)
        panel(width: 342, height: 147, point: CGPoint(x: 195, y: 351), parent: overlay)
        label(buddy.name, size: 28, point: CGPoint(x: 195, y: 389), parent: overlay)
        paragraph("Hi! I'd love to help you bring more color to the festival. Let's pop some bubbles together!", y: 341, parent: overlay)
        menuButton("Choose this buddy", name: "buddy-choose", point: CGPoint(x: 195, y: 201), parent: overlay, height: 52)
        menuButton("Maybe later", name: "buddy-later", point: CGPoint(x: 195, y: 128), parent: overlay, height: 48)
    }

    func showWheelReward(_ prize: FestivalPrize) {
        menuKind = "wheel-reward"
        let overlay = makeMenu(background: LevelCatalog.areas[mapArea].background)
        panel(width: 342, height: 420, point: CGPoint(x: 195, y: 472), parent: overlay)
        label("Your festival gift", size: 28, point: CGPoint(x: 195, y: 640), parent: overlay)
        let icon: SKNode = prize == .rainbow ? shotNode(.rainbow) : prize == .bomb ? shotNode(.bomb) : questIcon(prize.symbol, size: 72, color: .systemYellow)
        icon.setScale(prize == .rainbow || prize == .bomb ? 2 : 1)
        icon.position = CGPoint(x: 195, y: 548); overlay.addChild(icon)
        label(prize.title, size: 25, point: CGPoint(x: 195, y: 470), parent: overlay)
        paragraph(prize == .rainbow || prize == .bomb ? "Saved to your booster supply. Use it from the bottom controls during a puzzle." : "Saved to your collection. Pins can be chosen in Friends; bunting appears at your stations.", y: 400, parent: overlay)
        label("\(progress.adventure.rainbowGifts) extra rainbow • \(progress.adventure.bombGifts) extra bomb", size: 15, point: CGPoint(x: 195, y: 299), parent: overlay)
        menuButton("Back to the wheel", name: "wheel-return", point: CGPoint(x: 195, y: 185), parent: overlay, height: 48)
        menuButton("Festival map", name: "quest-back", point: CGPoint(x: 195, y: 115), parent: overlay, height: 48)
    }

    func showRetryPrompt() {
        menuKind = "retry-prompt"; returnMenu = "game"
        let overlay = makeMenu(background: LevelCatalog.level(level).background)
        panel(width: 340, height: 260, point: CGPoint(x: 195, y: 434), parent: overlay)
        label("Restart this puzzle?", size: 24, point: CGPoint(x: 195, y: 515), parent: overlay)
        paragraph("This attempt will start over.", y: 456, parent: overlay)
        menuButton("Restart", name: "retry-confirm", point: CGPoint(x: 195, y: 392), parent: overlay, height: 44)
        menuButton("Keep playing", name: "retry-cancel", point: CGPoint(x: 195, y: 334), parent: overlay, height: 44)
    }

    func showControlHelp(_ control: String) {
        gameRoot.childNode(withName: "control-tip")?.removeFromParent()
        let tip = panel(width: 320, height: 86, point: CGPoint(x: 195, y: 304), parent: gameRoot)
        tip.name = "control-tip"; tip.zPosition = 25
        let text = SKLabelNode(fontNamed: "AvenirNext-Medium")
        text.text = control == "rainbow" ? "Rainbow pops the largest neighboring color group." : control == "bomb" ? "Bomb pops bubbles nearby. The guide previews its reach." : "Swap your loaded bubble with the next bubble, freely."
        text.fontSize = 16; text.numberOfLines = 3; text.preferredMaxLayoutWidth = 285
        text.verticalAlignmentMode = .center; tip.addChild(text)
        tip.run(.sequence([.wait(forDuration: 3), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    func showPracticeHint() {
        guard hasStartedPuzzle, levelMenu == nil, level == 0, !progress.practiceDone, progress.stars(0) == 0 else { return }
        gameRoot.childNode(withName: "practice-caption")?.removeFromParent()
        let caption = SKLabelNode(fontNamed: "AvenirNext-Bold")
        caption.text = "Aim for a matching group, then release"
        caption.fontSize = 15; caption.name = "practice-caption"
        caption.position = CGPoint(x: 195, y: 312); caption.zPosition = 12; gameRoot.addChild(caption)
        var best: (Int, Set<Cell>)?
        for angle in stride(from: -1.2, through: 1.2, by: 0.08) {
            guard let landing = BubbleGeometry.flight(angle: angle, board: board).landing else { continue }
            var preview = board
            let result = preview.place(currentColor, at: landing)
            if best == nil || result.matched.count > best!.0 { best = (result.matched.count, result.matched) }
        }
        for cell in best?.1 ?? [] where board.bubbles[cell] != nil {
            let glow = SKShapeNode(circleOfRadius: 24)
            glow.position = point(cell); glow.strokeColor = .systemYellow; glow.lineWidth = 3; glow.fillColor = .clear
            guide.addChild(glow)
            if !UIAccessibility.isReduceMotionEnabled { glow.run(.repeatForever(.sequence([.fadeAlpha(to: 0.45, duration: 0.6), .fadeAlpha(to: 1, duration: 0.6)]))) }
        }
    }

    func showSpecialHelp(_ kind: SpecialBubble) {
        specialToLearn = kind; menuKind = "special-help"
        let overlay = makeMenu(background: LevelCatalog.level(level).background)
        panel(width: 342, height: 360, point: CGPoint(x: 195, y: 434), parent: overlay)
        label("A new festival bubble", size: 25, point: CGPoint(x: 195, y: 568), parent: overlay)
        let sample = specialBubble(kind); sample.setScale(2); sample.position = CGPoint(x: 195, y: 496); overlay.addChild(sample)
        paragraph(kind.explanation, y: 400, parent: overlay)
        menuButton("Let's try it", name: "special-ready", point: CGPoint(x: 195, y: 310), parent: overlay, height: 44)
    }

    func showChallenge() {
        guard (questArea * 10..<questArea * 10 + 10).allSatisfy({ progress.stars($0) > 0 }) else { return }
        menuKind = "challenge"
        let overlay = makeMenu(background: LevelCatalog.areas[questArea].background)
        panel(width: 342, height: 62, point: CGPoint(x: 195, y: 723), parent: overlay)
        label("A little extra challenge", size: 25, point: CGPoint(x: 195, y: 720), parent: overlay)
        panel(width: 342, height: 300, point: CGPoint(x: 195, y: 470), parent: overlay)
        paragraph("Replay this station's opening puzzle with fewer shots and no boosters. Can you earn three stars?", y: 510, parent: overlay)
        label(progress.challengeWon(questArea) ? "Challenge completed ✓" : "An optional festival challenge", size: 17, point: CGPoint(x: 195, y: 375), parent: overlay)
        menuButton("Try the challenge", name: "challenge-play", point: CGPoint(x: 195, y: 248), parent: overlay)
        menuButton("Stories", name: "quest-list", point: CGPoint(x: 195, y: 160), parent: overlay, height: 44)
    }

    func saveCheckpoint() {
        guard hasStartedPuzzle, !finished, projectile == nil, !board.bubbles.isEmpty, !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) else { return }
        progress.save(GameCheckpoint(level: level, board: board, shots: shots, score: score,
                                     current: currentColor, next: nextColor, bag: colorBag,
                                     rainbow: rainbowLeft, bomb: bombLeft, play: questPlay, challenge: challengeMode,
                                     freeRainbow: freeRainbow, freeBomb: freeBomb))
    }

    func specialBubble(_ kind: SpecialBubble) -> SKNode {
        let xs: [CGFloat] = [94, 774, 1456]
        let rectangle = CGRect(x: xs[kind.artIndex] / 2172, y: 64.0 / 724,
                               width: 620.0 / 2172, height: 620.0 / 724)
        let texture = SKTexture(rect: rectangle, in: SKTexture(imageNamed: "festival-special-bubbles"))
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 42, height: 42))
        let rim = SKShapeNode(circleOfRadius: CGFloat(BubbleGeometry.radius))
        rim.name = "bubble-rim"; rim.strokeColor = .white; rim.lineWidth = 1.5; rim.fillColor = .clear
        sprite.addChild(rim)
        return sprite
    }

    func addQuestMarker() {
        questMarkers.removeAll()
        let quests = FestivalQuest.all.filter { $0.area == level / 10 && progress.adventure.accepted($0) && !progress.adventure.completed($0) && !questPlay.collected.contains($0.id) }
        let cells = board.bubbles.keys.filter { board.specials[$0] == nil }
            .sorted { $0.row == $1.row ? $0.column < $1.column : $0.row > $1.row }
        for (quest, cell) in zip(quests, cells) {
            guard let bubble = nodes[cell] else { continue }
            questMarkers[cell] = quest.id
            let marker = questIcon(quest.artifact(step: progress.adventure.count(quest)), size: 13, color: .white)
            marker.position = CGPoint(x: 12, y: -12); marker.zPosition = 1; bubble.addChild(marker)
        }
    }

    func applyCompanionPins() {
        for index in 0..<2 {
            guard let sprite = gameRoot.childNode(withName: "companion-\(index)") else { continue }
            sprite.childNode(withName: "prize-pin")?.removeFromParent()
            if let prize = progress.adventure.equippedPin {
                let pin = questIcon(prize.symbol, size: 13, color: .systemYellow)
                pin.name = "prize-pin"; pin.position = CGPoint(x: index == 0 ? 13 : -10, y: index == 0 ? 56 : 65)
                sprite.addChild(pin)
            }
        }
    }

    func updateControlLayout() {
        let leftHand = progress.enabled(.leftHand)
        let positions: [(String, CGFloat)] = leftHand ? [("retry", 342), ("rainbow", 48), ("swap", 112), ("bomb", 178)] : [("retry", 48), ("rainbow", 132), ("swap", 195), ("bomb", 258)]
        for (name, x) in positions { gameRoot.childNode(withName: name)?.position.x = x }
        gameRoot.childNode(withName: "board-veil")?.alpha = progress.enabled(.contrast) ? 0.34 : 0.17
        view?.preferredFramesPerSecond = levelMenu != nil || ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        gameRoot.childNode(withName: "ambient")?.isHidden = quiet
        gameRoot.childNode(withName: "ambient")?.isPaused = quiet
        for node in Array(nodes.values) + [loaded, nextNode].compactMap({ $0 }) {
            let rim = node.childNode(withName: "bubble-rim") as? SKShapeNode
            rim?.strokeColor = UIColor.white.withAlphaComponent(progress.enabled(.contrast) ? 1 : 0.5)
            rim?.lineWidth = progress.enabled(.contrast) ? 2 : 1
        }
    }

    func showSoundLevels() {
        menuKind = "sound-levels"
        let overlay = makeMenu(background: LevelCatalog.level(level).background)
        panel(width: 342, height: 420, point: CGPoint(x: 195, y: 448), parent: overlay)
        label("Sound levels", size: 30, point: CGPoint(x: 195, y: 602), parent: overlay)
        for (index, music) in [true, false].enumerated() {
            let y = CGFloat(505 - index * 112)
            label(music ? "Music" : "Sounds", size: 23, point: CGPoint(x: 195, y: y + 34), parent: overlay)
            label("\(progress.volumeStep(music: music) * 20)%", size: 23, point: CGPoint(x: 195, y: y - 8), parent: overlay)
            menuButton("−", name: music ? "music-down" : "effects-down", point: CGPoint(x: 80, y: y), parent: overlay, width: 64, height: 44)
            menuButton("+", name: music ? "music-up" : "effects-up", point: CGPoint(x: 310, y: y), parent: overlay, width: 64, height: 44)
        }
        menuButton("Back", name: "sound-back", point: CGPoint(x: 195, y: 286), parent: overlay, height: 44)
    }

    func showAccessories() {
        menuKind = "accessories"
        let overlay = makeMenu(background: "festival-courtyard")
        panel(width: 342, height: 160, point: CGPoint(x: 195, y: 690), parent: overlay)
        label("Buddy pins", size: 30, point: CGPoint(x: 195, y: 728), parent: overlay)
        paragraph("Little gifts from the festival prize wheel and our friends.", y: 651, parent: overlay)
        menuButton("No pin", name: "pin-none", point: CGPoint(x: 195, y: 550), parent: overlay)
        for (index, prize) in progress.adventure.unlockedPins.enumerated() {
            menuButton(prize.title + (progress.adventure.equippedPin == prize ? " ✓" : ""), name: "pin-\(prize.rawValue)", point: CGPoint(x: 195, y: 478 - CGFloat(index) * 72), parent: overlay)
        }
        menuButton("Friends", name: "accessory-back", point: CGPoint(x: 195, y: 120), parent: overlay, height: 44)
    }

    func companionTexture(_ friend: Companion, frame: Int, glance: Bool = false) -> SKTexture {
        if friend.atlasIndex >= 6 {
            let boundaries: [CGFloat] = [0, 260, 516, 770, 1028, 1287, 1536]
            let row = friend.atlasIndex - 6
            return SKTexture(rect: CGRect(x: CGFloat(frame) / 4, y: (1536 - boundaries[row + 1]) / 1536,
                                          width: 0.25, height: (boundaries[row + 1] - boundaries[row]) / 1536),
                             in: SKTexture(imageNamed: "festival-new-human-motion"))
        }
        // The painted atlas uses different row heights for ears and human hairstyles.
        let boundaries: [CGFloat] = [0, 245, 481, 713, 976, 1254, 1536]
        let top = boundaries[friend.atlasIndex]
        let bottom = boundaries[friend.atlasIndex + 1]
        return SKTexture(rect: CGRect(x: CGFloat(frame) / 4, y: (1536 - bottom) / 1536,
                                      width: 0.25, height: (bottom - top) / 1536),
                         in: SKTexture(imageNamed: glance ? "festival-companion-glance" : "festival-companion-motion"))
    }

    func animateCompanion(_ kind: Companion.Kind, frames: [Int], repeating: Bool = false) {
        let index = kind == .animal ? 0 : 1
        guard let sprite = gameRoot.childNode(withName: "companion-\(index)") as? SKSpriteNode else { return }
        let key = kind == .animal ? "loading" : "operating"
        if frames == [1, 2], sprite.action(forKey: key) != nil { return }
        sprite.removeAction(forKey: key)
        let friend = progress.selected(kind)
        let animation = SKAction.animate(with: frames.map { companionTexture(friend, frame: $0, glance: kind == .human && frames == [1, 2]) }, timePerFrame: 0.16, resize: false, restore: true)
        sprite.run(repeating ? .repeatForever(animation) : animation, withKey: key)
    }

    func updateMachineStyle() {
        guard let cannon = gameRoot.childNode(withName: "cannon") as? SKShapeNode else { return }
        let colors: [UIColor] = [.brown, .systemGreen, .systemOrange, .systemTeal, .systemPurple]
        let symbols = ["leaf.fill", "sun.max.fill", "lightbulb.fill", "water.waves", "sparkles"]
        cannon.fillColor = colors[level / 10]
        cannon.strokeColor = .systemYellow
        cannon.removeAllChildren()
        let emblem = questIcon(symbols[level / 10], size: 18, color: .white)
        emblem.position.y = -31; cannon.addChild(emblem)
        gameRoot.childNode(withName: "machine-trim")?.removeFromParent()
        let trim = SKNode(); trim.name = "machine-trim"; trim.zPosition = -0.1
        gameRoot.addChild(trim)
        for side in [-1, 1] {
            let ornament: SKShapeNode
            switch level / 10 {
            case 1: ornament = SKShapeNode(ellipseOf: CGSize(width: 12, height: 34))
            case 2: ornament = SKShapeNode(rectOf: CGSize(width: 15, height: 24), cornerRadius: 6)
            case 3: ornament = SKShapeNode(ellipseOf: CGSize(width: 26, height: 10))
            case 4: ornament = SKShapeNode(rectOf: CGSize(width: 15, height: 15), cornerRadius: 2); ornament.zRotation = .pi / 4
            default: ornament = SKShapeNode(rectOf: CGSize(width: 12, height: 22), cornerRadius: 3)
            }
            ornament.position = CGPoint(x: 195 + CGFloat(side) * 36, y: 151)
            ornament.fillColor = colors[level / 10]; ornament.strokeColor = .systemYellow
            trim.addChild(ornament)
        }
        setOperatorHands(working: false)
    }

    func setOperatorHands(working: Bool) {
        if let hands = gameRoot.childNode(withName: "operator-hands"), hands.zPosition == (working ? 5 : -0.2) { return }
        gameRoot.childNode(withName: "operator-hands")?.removeFromParent()
        let hands = SKNode(); hands.name = "operator-hands"
        // Idle wrists sit behind the controls; gripping fingers sit in front.
        hands.zPosition = working ? 5 : -0.2
        hands.alpha = working ? 1 : 0.85
        gameRoot.addChild(hands)
        for index in 0..<2 {
            let frame = index * 2 + (working ? 0 : 1)
            let texture = SKTexture(rect: CGRect(x: CGFloat(frame % 2) / 2, y: frame < 2 ? 0.5 : 0, width: 0.5, height: 0.5), in: SKTexture(imageNamed: "festival-operator-hands"))
            let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 27, height: 27))
            sprite.position = CGPoint(x: index == 0 ? 280 : 257, y: index == 0 ? 188 : 157)
            hands.addChild(sprite)
        }
    }

    func popEffect(at location: CGPoint, color: UIColor, special: SpecialBubble?, quiet: Bool) {
        let ring = SKShapeNode(circleOfRadius: 19)
        ring.position = location; ring.zPosition = 12; ring.strokeColor = special == nil ? color : .systemYellow
        ring.lineWidth = special == nil ? 3 : 5; ring.fillColor = .clear
        gameRoot.addChild(ring)
        ring.run(.sequence([.group([.scale(to: quiet ? 1 : special == nil ? 1.65 : 2.15, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        guard !quiet else { return }
        for index in 0..<(special == nil ? 5 : 8) {
            let fragment = SKShapeNode(circleOfRadius: index % 2 == 0 ? 3 : 1.5)
            fragment.fillColor = index % 2 == 0 ? color : .white; fragment.strokeColor = .clear
            fragment.position = location; fragment.zPosition = 13
            gameRoot.addChild(fragment)
            let angle = CGFloat(index) * .pi * 2 / CGFloat(special == nil ? 5 : 8)
            fragment.run(.sequence([.group([.moveBy(x: cos(angle) * 36, y: sin(angle) * 36, duration: 0.3), .fadeOut(withDuration: 0.3), .scale(to: 0.2, duration: 0.3)]), .removeFromParent()]))
        }
    }

    func dropTrail(at location: CGPoint, color: UIColor) {
        for index in 0..<3 {
            let glint = SKShapeNode(circleOfRadius: 2)
            glint.position = CGPoint(x: location.x + CGFloat(index - 1) * 7, y: location.y + CGFloat(index) * 8)
            glint.fillColor = color; glint.strokeColor = .white; glint.zPosition = 11
            gameRoot.addChild(glint)
            glint.run(.sequence([.group([.moveBy(x: 0, y: -160, duration: 0.45), .fadeOut(withDuration: 0.45)]), .removeFromParent()]))
        }
    }

    func refreshQuestBadge() {
        gameRoot.childNode(withName: "quest-objective")?.removeFromParent()
        let quests = FestivalQuest.all.filter { $0.area == level / 10 && progress.adventure.accepted($0) && !progress.adventure.completed($0) }
        guard let quest = quests.first, !finished else { return }
        let badge = panel(width: 214, height: 26, point: CGPoint(x: 195, y: 722), parent: gameRoot)
        badge.name = "quest-objective"
        let icon = questIcon(quest.symbol, size: 17, color: .systemYellow)
        icon.position.x = -86; badge.addChild(icon)
        let step = progress.adventure.count(quest)
        let done: Bool
        switch quest.goals[step] {
        case .clear: done = questPlay.collected.contains(quest.id)
        case .bounce: done = questPlay.bounces > 0
        case .drop: done = questPlay.dropped > 0
        case .color(let color): done = questPlay.colors.contains(color)
        }
        label("\(step)/3 • \(done ? "Ready to finish" : "Festival favor")", size: 13, point: CGPoint(x: 8, y: -4), parent: badge)
    }

    func showObjectives() {
        menuKind = "objectives"
        let overlay = makeMenu(background: LevelCatalog.level(level).background)
        panel(width: 342, height: 410, point: CGPoint(x: 195, y: 443), parent: overlay)
        label("Festival favors", size: 28, point: CGPoint(x: 195, y: 615), parent: overlay)
        let quests = FestivalQuest.all.filter { $0.area == level / 10 && progress.adventure.accepted($0) && !progress.adventure.completed($0) }
        for (index, quest) in quests.enumerated() {
            label(quest.title, size: 19, point: CGPoint(x: 195, y: 550 - CGFloat(index) * 116), parent: overlay)
            paragraph(quest.steps[progress.adventure.count(quest)], y: 506 - CGFloat(index) * 116, parent: overlay)
        }
        menuButton("Keep playing", name: "objective-close", point: CGPoint(x: 195, y: 171), parent: overlay, height: 50)
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
        let sprite = SKSpriteNode(texture: texture, size: CGSize(width: 42, height: 42))
        let rim = SKShapeNode(circleOfRadius: CGFloat(BubbleGeometry.radius))
        rim.name = "bubble-rim"
        rim.strokeColor = UIColor.white.withAlphaComponent(progress.enabled(.contrast) ? 1 : 0.5)
        rim.lineWidth = progress.enabled(.contrast) ? 2 : 1; rim.fillColor = .clear
        sprite.addChild(rim)
        return sprite
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
        updateControlLayout()
        showPracticeHint()
    }

    func beginSelectedLevel() {
        hasStartedPuzzle = true
        closeMenu()
        startLevel()
        if !progress.tutorialSeen {
            tutorialPage = 0
            tutorialFromSettings = false
            returnMenu = "game"
            showTutorial()
        } else if !progress.hasMet(FestivalHost.all[level / 10]) {
            showHost(FestivalHost.all[level / 10])
        } else if let special = board.specials.values.first, !progress.hasLearned(special) {
            showSpecialHelp(special)
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
        menuButton("Festival favors", name: "host-quests", point: CGPoint(x: 195, y: 195), parent: overlay, height: 44)
        menuButton(dialoguePage == host.introduction.count - 1 ? "Let's go!" : "Next", name: "dialogue-next", point: CGPoint(x: 195, y: 142), parent: overlay, height: 44)
        menuButton("Skip", name: "dialogue-skip", point: CGPoint(x: 195, y: 84), parent: overlay, width: 132, height: 44)
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
            menuButton("\(setting.title): \(progress.enabled(setting) ? "On" : "Off")", name: "setting-\(setting.rawValue)", point: CGPoint(x: 195, y: 606 - CGFloat(index) * 58), parent: overlay, height: 44)
        }
        menuButton("How to play", name: "tutorial", point: CGPoint(x: 195, y: 250), parent: overlay, height: 44)
        menuButton("Sound levels", name: "sound-levels", point: CGPoint(x: 195, y: 193), parent: overlay, height: 44)
        menuButton(progress.soundMuted ? "Sound: Off" : "Sound: On", name: "quick-sound", point: CGPoint(x: 195, y: 136), parent: overlay, width: 220, height: 44)
        menuButton("Back", name: "back", point: CGPoint(x: 114, y: 78), parent: overlay, width: 158, height: 50)
        menuButton("Home", name: "home", point: CGPoint(x: 282, y: 78), parent: overlay, width: 158, height: 50)
    }

    func showTutorial() {
        menuKind = "tutorial"
        let overlay = makeMenu(background: "festival-courtyard")
        let titles = ["Aim and pop", "Try a wall bounce", "A little extra help", "Festival surprises"]
        let bodies = ["Drag above the launcher to aim. Release to shoot. Drag back down toward the launcher to cancel. Match three bubbles with the same color and symbol.",
                      "Use the walls to reach tricky spots. Pop a supporting group to drop the bubbles below it. Clear the board to win!",
                      "Rainbow pops its largest connected color group. Bomb clears nearby bubbles. You get one of each per attempt. Save shots to earn more stars. Hold an icon for help!",
                      "Lanterns clear a row. River pearls return a shot. Blossom sparks pop nearby bubbles. Each keeps its usual matching color."]
        panel(width: 342, height: 440, point: CGPoint(x: 195, y: 465), parent: overlay)
        label(titles[tutorialPage], size: 26, point: CGPoint(x: 195, y: 632), parent: overlay)
        for index in 0..<3 {
            let node = tutorialPage == 3 ? specialBubble([SpecialBubble.lantern, .riverPearl, .blossomSpark][index]) : tutorialPage == 2 ? shotNode(index == 0 ? .rainbow : index == 1 ? .bomb : .color(1)) : bubble(0)
            node.position = CGPoint(x: 137 + CGFloat(index) * 58, y: 550)
            overlay.addChild(node)
        }
        paragraph(bodies[tutorialPage], y: 410, parent: overlay)
        label("\(tutorialPage + 1)/4", size: 16, point: CGPoint(x: 195, y: 286), parent: overlay)
        menuButton(tutorialPage == 3 ? "Ready to play" : "Next", name: "tutorial-next", point: CGPoint(x: 195, y: 181), parent: overlay)
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
        friendsPage = min(1, max(0, friendsPage))
        let friends = Array(Companion.all.dropFirst(friendsPage * 6).prefix(6))
        for (index, friend) in friends.enumerated() {
            let x: CGFloat = index % 2 == 0 ? 105 : 285
            let y: CGFloat = 617 - CGFloat(index / 2) * 145
            let tile = panel(width: 160, height: 136, point: CGPoint(x: x, y: y), parent: overlay)
            tile.name = "friend-\(friend.id)"
            let available = progress.unlocked(friend)
            let portrait = SKSpriteNode(texture: companionTexture(friend, frame: 0), size: CGSize(width: 96, height: 96))
            portrait.position.y = 19
            portrait.alpha = available ? 1 : 0.35
            tile.addChild(portrait)
            label(friend.name, size: 14, point: CGPoint(x: 0, y: -45), parent: tile)
            let chosen = progress.selected(friend.kind).id == friend.id
            label(available ? chosen ? "Selected ✓" : "Tap to choose" : friend.unlockDescription, size: 10, point: CGPoint(x: 0, y: -65), parent: tile)
        }
        menuButton(friendsPage == 0 ? "More friends →" : "← First friends", name: "friends-page", point: CGPoint(x: 195, y: 230), parent: overlay, height: 44)
        menuButton("Buddy pins", name: "accessories", point: CGPoint(x: 195, y: 171), parent: overlay, height: 44)
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
        if wheelSpinning { return }
        if names.contains("quick-sound") {
            progress.toggleSound()
            audio.update(area: level / 10, enabled: progress.enabled(.music), volume: progress.musicVolume)
            showSettings(); return
        }
        if names.contains("wheel-return") { showWheel(); return }
        if names.contains("new-buddy"), let buddy = progress.pendingBuddy { showBuddyWelcome(buddy); return }
        if names.contains("buddy-choose") || names.contains("buddy-later") {
            if let buddy = progress.pendingBuddy { if names.contains("buddy-choose") { progress.select(buddy) }; progress.welcome(buddy) }
            if finished { closeMenu() } else { showTitle() }
            return
        }
        if names.contains("saved-progress") { showSavedProgress(); return }
        if names.contains("save-now") { saveCheckpoint(); progress.markSaved(); showSavedProgress(); return }
        if names.contains("objective-close") { closeMenu(); return }
        if names.contains("neighbors") { showNeighbors(); return }
        if let name = names.first(where: { $0.hasPrefix("neighbor-") }), let neighbor = FestivalNeighbor.all.first(where: { "neighbor-\($0.id)" == name }) { showNeighbor(neighbor); return }
        if names.contains("special-ready"), let specialToLearn { progress.markLearned(specialToLearn); closeMenu(); return }
        if names.contains("open-challenge") { showChallenge(); return }
        if names.contains("challenge-play") { level = questArea * 10; challengeMode = true; beginSelectedLevel(); return }
        if names.contains("sound-levels") { showSoundLevels(); return }
        if names.contains("sound-back") { showSettings(); return }
        if let name = names.first(where: { ["music-up", "music-down", "effects-up", "effects-down"].contains($0) }) {
            progress.changeVolume(music: name.hasPrefix("music"), by: name.hasSuffix("up") ? 1 : -1)
            audio.update(area: level / 10, enabled: progress.enabled(.music), volume: progress.musicVolume)
            showSoundLevels(); return
        }
        if names.contains("accessories") { showAccessories(); return }
        if names.contains("accessory-back") { showFriends(); return }
        if names.contains("friends-page") { friendsPage = 1 - friendsPage; showFriends(); return }
        if names.contains("pin-none") { progress.adventure.equip(nil); applyCompanionPins(); showAccessories(); return }
        if let name = names.first(where: { $0.hasPrefix("pin-") }), let pin = FestivalPrize(rawValue: String(name.dropFirst(4))) {
            progress.adventure.equip(pin); applyCompanionPins(); showAccessories(); return
        }
        if names.contains("resume-play") { closeMenu(); startLevel(restoring: true); return }
        if names.contains("retry-confirm") { closeMenu(); startLevel(); return }
        if names.contains("retry-cancel") { closeMenu(); return }
        if names.contains("host-quests") { showQuests(area: introHost?.area ?? mapArea); return }
        if names.contains("quest-list") { showQuests(area: questArea); return }
        if names.contains("quest-back") { mapArea = questArea; showLevels(); return }
        if names.contains("open-wheel") { questArea = mapArea; showWheel(); return }
        if names.contains("wheel-spin") { spinWheel(); return }
        if names.contains("current-stop") { mapArea = progress.unlockedLevel / 10; showLevels(); return }
        if names.contains("quest-accept"), let selectedQuest {
            progress.adventure.accept(selectedQuest, unlockedLevel: progress.unlockedLevel)
            showQuest(selectedQuest); return
        }
        if names.contains("quest-play"), let selectedQuest {
            if let next = progress.adventure.nextLevel(selectedQuest, unlockedLevel: progress.unlockedLevel) {
                level = next; challengeMode = false; beginSelectedLevel()
            }
            return
        }
        if let name = names.first(where: { $0.hasPrefix("quest-style-") }), let selectedQuest,
           let value = Int(name.dropFirst(12)) {
            progress.adventure.chooseStyle(value, for: selectedQuest); showQuest(selectedQuest); return
        }
        if let name = names.first(where: { $0.hasPrefix("quest-") }),
           let quest = FestivalQuest.all.first(where: { "quest-" + $0.id == name }) {
            showQuest(quest); return
        }
        if names.contains("start-adventure") { mapArea = progress.unlockedLevel / 10; showLevels() }
        else if names.contains("home") { showTitle() }
        else if names.contains("area-prev") { mapArea = max(0, mapArea - 1); showLevels() }
        else if names.contains("area-next") { mapArea = min(4, mapArea + 1); showLevels() }
        else if names.contains("meet-host") {
            let host = FestivalHost.all[mapArea]
            if progress.hostIsAvailable(host) { showHost(host) }
            else if let overlay = levelMenu {
                overlay.childNode(withName: "unlock-message")?.removeFromParent()
                let message = panel(width: 280, height: 32, point: CGPoint(x: 195, y: 139), parent: overlay)
                message.name = "unlock-message"
                label("Reach level \(host.area * 10 + 1) to meet \(host.name)", size: 12, point: CGPoint(x: 0, y: -4), parent: message)
            }
        }
        else if names.contains("settings") { returnMenu = menuKind; showSettings() }
        else if names.contains("friends") { returnMenu = menuKind; showFriends() }
        else if names.contains("back") { restoreMenu() }
        else if names.contains("tutorial") { tutorialFromSettings = true; tutorialPage = 0; showTutorial() }
        else if names.contains("tutorial-skip") { finishTutorial() }
        else if names.contains("tutorial-next") { if tutorialPage < 3 { tutorialPage += 1; showTutorial() } else { finishTutorial() } }
        else if names.contains("dialogue-skip") { finishIntroduction() }
        else if names.contains("dialogue-next"), let host = introHost {
            if dialoguePage < host.introduction.count - 1 { dialoguePage += 1; showHost(host) } else { finishIntroduction() }
        }
        else if let name = names.first(where: { $0.hasPrefix("setting-") }), let setting = GameSetting(rawValue: String(name.dropFirst(8))) {
            progress.toggle(setting)
            updateControlLayout()
            audio.update(area: level / 10, enabled: progress.enabled(.music), volume: progress.musicVolume)
            showSettings()
        }
        else if let name = names.first(where: { $0.hasPrefix("friend-") }), let friend = Companion.all.first(where: { "friend-\($0.id)" == name }) {
            progress.select(friend)
            showFriends()
        }
        else if let name = names.first(where: { $0.hasPrefix("level-") }), let selected = Int(name.dropFirst(6)), selected <= progress.unlockedLevel {
            level = selected
            challengeMode = false
            beginSelectedLevel()
        }
    }
}
