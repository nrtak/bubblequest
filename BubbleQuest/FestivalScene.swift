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
    private let profiles: GameProfiles
    private lazy var progress = profiles.makeProgress()
    var requestPlayerName: ((String, @escaping (String?) -> Void) -> Void)?
    private var playersPage = 0
    private let audio = FestivalAudio()
    private let gameRoot = SKNode()
    private var mapArea = 0
    private var menuKind = "title"
    private var returnMenu = "game"
    private var friendsPage = 0
    private var attemptCounted = false
    private var operatorBuddyID = ""
    private var operatorFriend: Companion?
    private var aimTouch: UITouch?
    private var pendingFlight: (landing: Cell?, kind: BubbleShot)?
    private var operatorTextures: [String: SKTexture] = [:]
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
    private var pressureSeed: UInt64 = 0
    private var shotsFired = 0
    private var ceilingOffset = 0.0
    private var ceilingMoving = false
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

    private static func defaultProfiles() -> GameProfiles {
        GameProfiles(registry: ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) ? UserDefaults(suiteName: "BubbleQuestPreview")! : .standard)
    }

    init(size: CGSize, profiles: GameProfiles) {
        self.profiles = profiles
        super.init(size: size)
    }

    override convenience init(size: CGSize) { self.init(size: size, profiles: Self.defaultProfiles()) }

    required init?(coder: NSCoder) {
        profiles = Self.defaultProfiles()
        super.init(coder: coder)
    }

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
        iconButton("gearshape.fill", name: "game-menu", point: CGPoint(x: 48, y: 65))
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
        if ProcessInfo.processInfo.arguments.contains("--beach-preview") { level = 70 }
        if ProcessInfo.processInfo.arguments.contains("--hill-preview") { level = 90 }
        if ProcessInfo.processInfo.arguments.contains("--summer-neighbor-preview") { level = 60 }
        if ProcessInfo.processInfo.arguments.contains("--summer-buddies-preview") { level = 110 }
        if ProcessInfo.processInfo.arguments.contains("--summer-map-preview") { level = 70 }
        let summerPreview = ["--beach-preview", "--hill-preview", "--summer-neighbor-preview", "--summer-buddies-preview", "--summer-map-preview"].contains(where: ProcessInfo.processInfo.arguments.contains)
        if summerPreview {
            for index in 0..<111 { progress.recordVictory(index: index, score: 200, stars: 1) }
            if let otter = Companion.all.first(where: { $0.id == "river-otter" }) { progress.select(otter) }
        }
        mapArea = level / 10
        if ProcessInfo.processInfo.arguments.contains("--buddy-preview") {
            for index in 0..<5 { progress.recordVictory(index: index, score: 200, stars: 1) }
        }
        if ProcessInfo.processInfo.arguments.contains("--purple-preview") {
            for index in 0..<35 { progress.recordVictory(index: index, score: 200, stars: 1) }
            let quest = FestivalQuest.all[1]
            progress.adventure.accept(quest, unlockedLevel: progress.unlockedLevel)
            for index in 10..<13 { progress.adventure.recordWin(level: index, play: QuestPlay(bounces: 1, dropped: 1), completedLevels: progress.completedCount) }
            if let purple = Companion.all.first(where: { $0.atlasIndex == 9 }) { progress.select(purple) }
        }
        startLevel(restoring: !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }))
        if ProcessInfo.processInfo.arguments.contains("--summer-neighbor-preview") { questArea = mapArea; showNeighbors() }
        else if ProcessInfo.processInfo.arguments.contains("--summer-buddies-preview") { friendsPage = 2; showMapBuddies() }
        else if ProcessInfo.processInfo.arguments.contains("--summer-map-preview") { showLevels() }
        else if ProcessInfo.processInfo.arguments.contains("--players-preview") { showPlayers() }
        else if ProcessInfo.processInfo.arguments.contains("--festival-preview") { showFestival() }
        else if ProcessInfo.processInfo.arguments.contains("--buddy-preview"), let buddy = progress.pendingBuddy { showBuddyWelcome(buddy) }
        else if ProcessInfo.processInfo.arguments.contains("--purple-preview") { updateAim(CGPoint(x: 50, y: 420)) }
        else if ProcessInfo.processInfo.arguments.contains("--pressure-preview") {
            shotsFired = LevelCatalog.level(level).ceilingInterval * 2
            ceilingOffset = LevelCatalog.level(level).ceilingOffset(after: shotsFired, seed: pressureSeed)
            positionCeiling(animated: false); refreshHUD(); updateAim(CGPoint(x: 290, y: 500))
        }
        else if ProcessInfo.processInfo.arguments.contains("--friends-preview") { friendsPage = 1; showMapBuddies() }
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
        else if ProcessInfo.processInfo.arguments.contains("--gameplay-preview") || ProcessInfo.processInfo.arguments.contains("--beach-preview") || ProcessInfo.processInfo.arguments.contains("--hill-preview") { updateAim(CGPoint(x: 242, y: 600)) }
        else { showTitle() }
    }

    func setActive(_ active: Bool) {
        if !active { saveCheckpoint(); profiles.persistActive(); synchronizeOperatorRig() }
        suspended = !active
        isPaused = !active
        aiming = false
        aimGesture.cancel()
        aimTouch = nil
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
            if index == 1 { operatorFriend = friend }
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

    private func bubble(_ color: Int) -> SKNode {
        bubbleArt(index: color)
    }

    private func point(_ cell: Cell) -> CGPoint {
        CGPoint(x: left + CGFloat(cell.column) * radius * 2 + CGFloat(cell.row % 2) * radius,
                y: ceiling - CGFloat(ceilingOffset) - CGFloat(cell.row) * radius * sqrt(3))
    }

    private func startLevel(restoring: Bool = false) {
        let saved = restoring ? progress.checkpoint : nil
        if let saved { level = saved.level; challengeMode = saved.challenge ?? false }
        pressureSeed = saved.map { $0.pressureSeed ?? 0 } ?? UInt64.random(in: 1...UInt64.max)
        shotsFired = saved?.shotsFired ?? 0
        ceilingOffset = saved?.ceilingOffset ?? 0
        ceilingMoving = false
        gameRoot.removeAction(forKey: "ceiling-move")
        positionCeiling(animated: false)
        pendingGift = nil
        pendingFlight = nil
        for name in ["practice-caption", "control-tip", "character-reaction"] { gameRoot.childNode(withName: name)?.removeFromParent() }
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
        aimTouch = nil
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        colorBag.removeAll()
        gameRoot.isPaused = false
        for name in ["rainbow", "bomb"] { gameRoot.childNode(withName: name)?.isHidden = false }
        for index in 0..<2 {
            let friend = progress.selected(index == 0 ? .animal : .human)
            if index == 1 { operatorFriend = friend }
            let sprite = gameRoot.childNode(withName: "companion-\(index)") as? SKSpriteNode
            sprite?.removeAllActions()
            sprite?.texture = companionTexture(friend, frame: 0)
            sprite?.position.y = 134
            sprite?.zRotation = 0
            sprite?.zPosition = 0
            sprite?.xScale = index == 1 ? -1 : 1
            if index == 0 { sprite?.run(.repeatForever(.sequence([.scaleY(to: 1.015, duration: 1.5), .scaleY(to: 1, duration: 1.5)])), withKey: "breathing") }
        }
        score = 0
        questPlay = QuestPlay()
        attemptCounted = false
        gameRoot.childNode(withName: "handwheel")?.zRotation = 0
        gameRoot.childNode(withName: "cannon")?.zRotation = 0
        synchronizeOperatorRig()
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
        showPracticeHint()
    }

    private func makeMenu(background: String) -> SKNode {
        saveCheckpoint()
        profiles.persistActive()
        levelMenu?.removeFromParent()
        aiming = false
        aimGesture.cancel()
        aimTouch = nil
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        guide.removeAllChildren()
        synchronizeOperatorRig()
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
        label(title, size: min(23, (width - 28) / max(1, CGFloat(title.count) * 0.58)), point: CGPoint(x: 0, y: -8), parent: button)
        if let text = button.children.first as? SKLabelNode { fitLabel(text, width: width - 28) }
        let symbols = ["Back to the map": "map.fill", "Back to the wheel": "gift.fill", "Spin": "sparkles", "Festival map": "map.fill", "Neighbors": "person.2.fill", "Prize Wheel": "gift.fill", "Pins": "star.circle.fill"]
        if let symbol = symbols[title] {
            let icon = questIcon(symbol, size: 20, color: .white)
            icon.position.x = -width / 2 + 23; button.addChild(icon)
            if let text = button.children.first as? SKLabelNode {
                text.position.x = 12
                fitLabel(text, width: width - 64)
            }
        }
    }

    private func fitLabel(_ label: SKLabelNode, width: CGFloat) {
        let font = UIFont(name: label.fontName ?? "", size: label.fontSize) ?? .boldSystemFont(ofSize: label.fontSize)
        let measured = ((label.text ?? "") as NSString).size(withAttributes: [.font: font]).width
        if measured > width { label.fontSize *= width / measured }
    }

    private func decorateMenuIcon(_ symbol: String, name: String, parent: SKNode, x: CGFloat) {
        guard let button = parent.childNode(withName: name) else { return }
        let icon = questIcon(symbol, size: 22, color: .white)
        icon.position.x = x; button.addChild(icon)
        (button.children.first as? SKLabelNode)?.position.x = 12
    }

    private func navigationCard(_ title: String, detail: String, symbol: String, name: String, y: CGFloat, parent: SKNode, primary: Bool) {
        let card = panel(width: 292, height: 82, point: CGPoint(x: 195, y: y), parent: parent)
        card.name = name
        card.fillColor = primary ? UIColor(red: 0.94, green: 0.39, blue: 0.31, alpha: 1) : UIColor(red: 0.22, green: 0.55, blue: 0.48, alpha: 1)
        let icon = questIcon(symbol, size: 30, color: .white); icon.position = CGPoint(x: -111, y: 0); card.addChild(icon)
        label(title, size: 22, point: CGPoint(x: 15, y: 5), parent: card)
        label(detail, size: 14, point: CGPoint(x: 15, y: -22), parent: card)
    }

    private func showTitle() {
        menuKind = "title"
        let overlay = makeMenu(background: "festival-day")
        let logo = SKSpriteNode(imageNamed: "festival-logo")
        logo.size = CGSize(width: 285, height: 190)
        logo.position = CGPoint(x: 195, y: 683)
        overlay.addChild(logo)
        label("Start Menu", size: 26, point: CGPoint(x: 195, y: 553), parent: overlay)
        panel(width: 342, height: 392, point: CGPoint(x: 195, y: 345), parent: overlay)
        let welcome = SKLabelNode(fontNamed: "AvenirNext-Bold")
        welcome.name = "welcome-player"; welcome.text = "Welcome, \(profiles.active.name)"
        welcome.fontSize = 18; welcome.numberOfLines = 2; welcome.preferredMaxLayoutWidth = 300
        welcome.lineBreakMode = .byCharWrapping; welcome.verticalAlignmentMode = .center
        welcome.position = CGPoint(x: 195, y: 498); overlay.addChild(welcome)
        navigationCard(progress.checkpoint == nil ? "Play" : "Continue playing", detail: "Level \(progress.currentLevel + 1) • \(LevelCatalog.level(progress.currentLevel).area + 1) / \(LevelCatalog.areas.count) areas", symbol: "play.fill", name: "continue-stop", y: 418, parent: overlay, primary: true)
        navigationCard("Explore Map", detail: "Levels • buddies • activities", symbol: "map.fill", name: "start-adventure", y: 317, parent: overlay, primary: false)
        menuButton("Players", name: "players", point: CGPoint(x: 147, y: 230), parent: overlay, width: 166, height: 44)
        decorateMenuIcon("person.2.fill", name: "players", parent: overlay, x: -56)
        let settings = panel(width: 48, height: 48, point: CGPoint(x: 303, y: 230), parent: overlay)
        settings.name = "settings"; settings.fillColor = UIColor(white: 0.96, alpha: 1)
        let gear = questIcon("gearshape.fill", size: 26, color: UIColor(white: 0.55, alpha: 1)); settings.addChild(gear)
        label("Saved automatically • \(progress.totalStars) stars", size: 14, point: CGPoint(x: 195, y: 169), parent: overlay)
        label("Irvine Dynamics", size: 12, point: CGPoint(x: 195, y: 62), parent: overlay)
    }

    private func showPlayers(message: String? = nil) {
        menuKind = "players"
        let overlay = makeMenu(background: "festival-courtyard")
        panel(width: 342, height: 625, point: CGPoint(x: 195, y: 435), parent: overlay)
        label("Choose your player", size: 27, point: CGPoint(x: 195, y: 708), parent: overlay)
        label("Each name has its own save", size: 16, point: CGPoint(x: 195, y: 674), parent: overlay)
        playersPage = min(max(0, playersPage), (profiles.players.count - 1) / 4)
        for (row, player) in profiles.players.dropFirst(playersPage * 4).prefix(4).enumerated() {
            let y = CGFloat(613 - row * 79)
            menuButton(player.name + (player.id == profiles.active.id ? " ✓" : ""), name: "player-\(player.id)", point: CGPoint(x: 195, y: y), parent: overlay, width: 300, height: 53)
            label("\(GameProgress(defaults: profiles.defaults(for: player)).currentLevel + 1) • Saved on this iPhone", size: 12, point: CGPoint(x: 195, y: y - 37), parent: overlay)
        }
        if profiles.players.count > 4 {
            menuButton("‹", name: "players-prev", point: CGPoint(x: 69, y: 291), parent: overlay, width: 60, height: 44)
            label("\(playersPage + 1)/\((profiles.players.count + 3) / 4)", size: 16, point: CGPoint(x: 195, y: 285), parent: overlay)
            menuButton("›", name: "players-next", point: CGPoint(x: 321, y: 291), parent: overlay, width: 60, height: 44)
        }
        menuButton("New player & save", name: "player-create", point: CGPoint(x: 195, y: 231), parent: overlay, height: 48)
        menuButton("Rename \(profiles.active.name)", name: "player-rename", point: CGPoint(x: 195, y: 172), parent: overlay, height: 44)
        if let message { label(message, size: 12, point: CGPoint(x: 195, y: 118), parent: overlay) }
        menuButton("Start Menu", name: "home", point: CGPoint(x: 195, y: 65), parent: overlay, height: 44)
    }

    private func enterPlayer(_ id: String) {
        saveCheckpoint()
        guard profiles.select(id) else { return }
        progress = profiles.makeProgress()
        hasStartedPuzzle = progress.checkpoint != nil
        challengeMode = false
        level = progress.currentLevel
        mapArea = level / 10
        gameRoot.removeAllActions()
        if progress.checkpoint != nil { closeMenu(); startLevel(restoring: true) }
        else { beginSelectedLevel() }
    }

    private func namePlayer(rename: Bool) {
        requestPlayerName?(rename ? profiles.active.name : "") { [weak self] value in
            guard let self, let value else { return }
            if rename {
                self.showPlayers(message: self.profiles.renameActive(value) ? "Save renamed" : "Choose a unique valid name")
            } else if let player = self.profiles.create(name: value) {
                // create changes the active slot; do not save the outgoing board into it.
                self.progress = self.profiles.makeProgress()
                self.hasStartedPuzzle = false
                self.enterPlayer(player.id)
            } else { self.showPlayers(message: "Choose a unique valid name") }
        }
    }

    private func showFestival() { mapArea = progress.currentLevel / 10; showLevels() }

    private func showSavedProgress() {
        menuKind = "saved-progress"
        let overlay = makeMenu(background: "festival-courtyard")
        panel(width: 342, height: 468, point: CGPoint(x: 195, y: 441), parent: overlay)
        label("Saved progress", size: 28, point: CGPoint(x: 195, y: 630), parent: overlay)
        paragraph("\(profiles.active.name)'s levels, stars, buddies, quests and prizes save separately on this iPhone.", y: 554, parent: overlay)
        label("\(progress.completedCount)/\(LevelCatalog.levelCount) stops • \(progress.totalStars)/\(LevelCatalog.maximumStars) stars", size: 19, point: CGPoint(x: 195, y: 468), parent: overlay)
        label(progress.checkpoint.map { "Puzzle \($0.level + 1) ready to resume" } ?? "No unfinished puzzle", size: 17, point: CGPoint(x: 195, y: 428), parent: overlay)
        let stamp = progress.lastSaved.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "Ready for your first adventure"
        label(stamp, size: 14, point: CGPoint(x: 195, y: 385), parent: overlay)
        menuButton("Save now", name: "save-now", point: CGPoint(x: 195, y: 306), parent: overlay, height: 50)
        label(profiles.active.fileName, size: 12, point: CGPoint(x: 195, y: 246), parent: overlay)
        menuButton("Festival map", name: "festival-menu", point: CGPoint(x: 195, y: 136), parent: overlay, height: 50)
    }

    private func showLevels() {
        menuKind = "map"
        mapArea = min(LevelCatalog.areas.count - 1, max(0, mapArea))
        let area = LevelCatalog.areas[mapArea]
        let scenery = SummerScenery.forArea(mapArea)
        let overlay = makeMenu(background: scenery?.mapArtwork ?? (!area.nightTint && mapArea % 5 < 2 ? "festival-map-day" : "festival-map"))
        if let scenery, let art = overlay.children.first as? SKSpriteNode {
            art.texture = SKTexture(rect: scenery.mapRegion, in: SKTexture(imageNamed: scenery.mapArtwork))
        }
        panel(width: 346, height: 82, point: CGPoint(x: 195, y: 738), parent: overlay)
        label(area.name, size: 23, point: CGPoint(x: 195, y: 750), parent: overlay)
        let current = progress.currentLevel
        label("Area \(mapArea + 1)/\(LevelCatalog.areas.count) • Active level \(current + 1) • \(progress.totalStars) stars", size: 14, point: CGPoint(x: 195, y: 720), parent: overlay)
        // Marker centers follow the painted roads, leaving the scenery visible.
        let dayXs: [CGFloat] = [223, 234, 238, 251, 270, 232, 174, 184, 246, 242]
        let nightXs: [CGFloat] = [218, 260, 246, 192, 222, 300, 314, 306, 312, 337]
        let xs = !area.nightTint && mapArea % 5 < 2 ? dayXs : nightXs
        let positions = scenery?.markerPositions ?? xs.enumerated().map { CGPoint(x: $0.element, y: 270 + CGFloat($0.offset) * 44) }
        let path = CGMutablePath(); path.move(to: positions[0])
        for position in positions.dropFirst() { path.addLine(to: position) }
        let road = SKShapeNode(path: path); road.strokeColor = UIColor(red: 0.98, green: 0.85, blue: 0.59, alpha: 0.9); road.lineWidth = 17; road.lineCap = .round
        overlay.addChild(road)
        for (local, position) in positions.enumerated() {
            let index = mapArea * 10 + local
            let entry = SKShapeNode(circleOfRadius: scenery == nil ? 18 : 16)
            entry.position = position
            entry.fillColor = index == current ? .systemPink : progress.stars(index) > 0 ? .systemOrange : index <= progress.unlockedLevel ? .systemTeal : .darkGray
            entry.strokeColor = .white
            entry.lineWidth = 3
            entry.name = index <= progress.unlockedLevel ? "level-\(index)" : "locked"
            overlay.addChild(entry)
            label("\(index + 1)", size: 17, point: CGPoint(x: 0, y: -6), parent: entry)
            if index == current {
                entry.strokeColor = .systemYellow
                entry.lineWidth = 5
                entry.zPosition = 3
                let halo = SKShapeNode(circleOfRadius: scenery == nil ? 23 : 20)
                halo.strokeColor = .systemYellow; halo.fillColor = .clear; halo.lineWidth = 2
                halo.zPosition = -1; entry.addChild(halo)
                let buddy = SKSpriteNode(texture: companionTexture(progress.selected(.human), frame: 0), size: CGSize(width: 56, height: 56))
                buddy.anchorPoint = CGPoint(x: 0.5, y: 0)
                buddy.position = CGPoint(x: position.x < 220 ? 38 : -38, y: -21)
                entry.addChild(buddy)
                label("YOU", size: 11, point: CGPoint(x: buddy.position.x, y: 39), parent: entry)
                if !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled {
                    halo.run(.repeatForever(.sequence([.fadeAlpha(to: 0.4, duration: 0.8), .fadeAlpha(to: 1, duration: 0.8)])))
                }
            }
            if progress.stars(index) > 0 {
                label(String(repeating: "★", count: progress.stars(index)), size: 8, point: CGPoint(x: 0, y: 20), parent: entry)
            }
        }
        for (name, text, x, enabled) in [("area-prev", "Previous area", CGFloat(99), mapArea > 0), ("area-next", "Next area", CGFloat(291), mapArea < LevelCatalog.areas.count - 1)] {
            let tab = SKShapeNode(rectOf: CGSize(width: 152, height: 36), cornerRadius: 7)
            tab.name = enabled ? name : "area-unavailable"; tab.position = CGPoint(x: x, y: 197)
            tab.fillColor = .systemGray4; tab.strokeColor = .white; tab.alpha = enabled ? 1 : 0.35
            overlay.addChild(tab)
            label(text, size: 15, point: CGPoint(x: 0, y: -5), parent: tab)
            (tab.children.first as? SKLabelNode)?.fontColor = .darkGray
        }
        if let quest = FestivalQuest.all.first(where: { $0.area == mapArea && progress.adventure.accepted($0) && !progress.adventure.completed($0) }) {
            let card = panel(width: 140, height: 62, point: CGPoint(x: 86, y: 646), parent: overlay)
            card.name = "map-objective"
            let icon = questIcon(quest.symbol, size: 21, color: .systemOrange); icon.position = CGPoint(x: -50, y: 10); card.addChild(icon)
            label("Active favor", size: 14, point: CGPoint(x: 10, y: 8), parent: card)
            label("\(progress.adventure.count(quest))/3 • Details", size: 13, point: CGPoint(x: 0, y: -17), parent: card)
        }
        if FestivalHost.all.indices.contains(mapArea) {
        let station = SKNode(); station.position = CGPoint(x: 80, y: 414); overlay.addChild(station)
        station.name = "meet-host"
        let footing = SKShapeNode(ellipseOf: CGSize(width: 82, height: 14)); footing.fillColor = .brown.withAlphaComponent(0.5); footing.strokeColor = .clear; footing.position.y = -46
        station.addChild(footing)
        let host = SKSpriteNode(texture: atlasTexture("festival-hosts", index: mapArea), size: CGSize(width: 148, height: 148))
        host.position = CGPoint(x: 0, y: 23)
        station.addChild(host)
        label("Meet \(FestivalHost.all[mapArea].name)", size: 19, point: CGPoint(x: 0, y: -69), parent: station)
        label("Stories & favors", size: 12, point: CGPoint(x: 0, y: -89), parent: station)
        station.alpha = progress.hostIsAvailable(FestivalHost.all[mapArea]) ? 1 : 0.55
        if progress.hostIsAvailable(FestivalHost.all[mapArea]) && !progress.hasMet(FestivalHost.all[mapArea]) {
            station.run(.repeatForever(.sequence([.scale(to: 1.025, duration: 1.1), .scale(to: 1, duration: 1.1)])))
        }
        addQuestDecorations(to: station)
        host.run(.repeatForever(.sequence([.moveBy(x: 0, y: 3, duration: 1.6), .moveBy(x: 0, y: -3, duration: 1.6)])))
        } else if let neighbor = FestivalNeighbor.all.first(where: { $0.area == mapArea }) {
            let station = SKNode(); station.position = CGPoint(x: 65, y: 414); overlay.addChild(station)
            let available = progress.neighborIsAvailable(neighbor)
            station.name = available ? "neighbor-\(neighbor.id)" : "locked"
            station.alpha = available ? 1 : 0.55
            let portrait = SKSpriteNode(texture: neighborTexture(neighbor), size: CGSize(width: 120, height: 120))
            portrait.position.y = 20; station.addChild(portrait)
            // The waist-up portrait stands behind a supported festival counter.
            for x in [CGFloat(-31), CGFloat(31)] {
                let leg = SKShapeNode(rectOf: CGSize(width: 8, height: 29), cornerRadius: 2)
                leg.position = CGPoint(x: x, y: -47); leg.fillColor = .brown; leg.strokeColor = .clear
                station.addChild(leg)
            }
            let counter = SKShapeNode(rectOf: CGSize(width: 92, height: 16), cornerRadius: 3)
            counter.position.y = -34; counter.zPosition = 1
            counter.fillColor = UIColor(red: 0.69, green: 0.43, blue: 0.23, alpha: 1); counter.strokeColor = .white
            station.addChild(counter)
            label("Meet \(neighbor.name)", size: 17, point: CGPoint(x: 0, y: -83), parent: station)
            label(available ? "Say hello" : "Clear earlier levels", size: 10, point: CGPoint(x: 0, y: -99), parent: station)
        }
        let wheelStop = panel(width: 128, height: 52, point: CGPoint(x: 80, y: 270), parent: overlay)
        wheelStop.name = "open-wheel"
        if neighborsAvailable(in: mapArea) {
            menuButton("Neighbors", name: "neighbors", point: CGPoint(x: 80, y: 584), parent: overlay, width: 128, height: 40)
        }
        let gift = questIcon("gift.fill", size: 20, color: .systemYellow); gift.position = CGPoint(x: -48, y: 0); wheelStop.addChild(gift)
        label("Prize Wheel", size: 15, point: CGPoint(x: 10, y: 3), parent: wheelStop)
        label("Free spins: \(progress.adventure.availableSpins)", size: 14, point: CGPoint(x: 0, y: -15), parent: wheelStop)
        menuButton("\(progress.checkpoint == nil ? "Start level" : "Continue level") \(current + 1)", name: "continue-stop", point: CGPoint(x: 195, y: 133), parent: overlay, width: 270, height: 52)
        menuButton("Start Menu", name: "home", point: CGPoint(x: 109, y: 65), parent: overlay, width: 150, height: 44)
        decorateMenuIcon("house.fill", name: "home", parent: overlay, x: -57)
        menuButton("Buddies", name: "friends", point: CGPoint(x: 281, y: 65), parent: overlay, width: 150, height: 44)
        decorateMenuIcon("pawprint.fill", name: "friends", parent: overlay, x: -57)
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
        next.name = "swap-bubble"
        next.setScale(0.85)
        let queueRing = SKShapeNode(circleOfRadius: 25)
        queueRing.fillColor = UIColor.white.withAlphaComponent(0.85); queueRing.strokeColor = .systemYellow
        queueRing.lineWidth = 2; queueRing.zPosition = -1; next.addChild(queueRing)
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
        if aimGesture.shouldCancel { return }
        let angle = aimGesture.angle
        aim = CGVector(dx: sin(angle), dy: cos(angle))
        gameRoot.childNode(withName: "cannon")?.zRotation = -CGFloat(angle)
        gameRoot.childNode(withName: "handwheel")?.zRotation = -CGFloat(angle) * 2.5
        synchronizeOperatorRig()
        guide.removeAllChildren()
        guard progress.enabled(.guide) else { return }
        let flight = BubbleGeometry.flight(angle: angle, board: board, ceilingOffset: ceilingOffset)
        for point in BubbleGeometry.bouncePoints(flight) {
            let bounce = SKShapeNode(circleOfRadius: 7)
            bounce.position = CGPoint(x: point.x, y: point.y)
            bounce.fillColor = .systemYellow; bounce.strokeColor = .white; bounce.lineWidth = 2
            guide.addChild(bounce)
        }
        if let landing = flight.landing {
            var preview = board
            let result = preview.place(armed ?? .color(currentColor), at: landing)
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
            dot.alpha = progress.enabled(.contrast) ? 1 : 0.82
            dot.position = CGPoint(x: point.x, y: point.y)
            guide.addChild(dot)
        }
        if let landing = flight.landing {
            let hint = SKShapeNode(circleOfRadius: radius)
            hint.strokeColor = .systemYellow
            hint.fillColor = palette[currentColor].withAlphaComponent(0.24)
            hint.lineWidth = 3
            hint.position = point(landing)
            hint.alpha = 0.9
            guide.addChild(hint)
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        gameRoot.removeAction(forKey: "control-help")
        guard !suspended, !aiming, let touch = touches.first else { return }
        let location = touch.location(in: self)
        let names = interactionNames(at: location)
        if levelMenu != nil { handleMenu(names); return }
        if let control = names.first(where: { ["rainbow", "bomb"].contains($0) }) {
            gameRoot.run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in self?.showControlHelp(control) }]), withKey: "control-help")
        }
        if names.contains("quest-objective") { showObjectives(); return }
        if names.contains("game-menu") { showGameMenu(); return }
        if finished {
            guard names.contains("result-next") else { return }
            if let buddy = progress.pendingBuddy { showBuddyWelcome(buddy); return }
            if let completedQuest { showQuest(completedQuest); return }
            if challengeMode && won { challengeMode = false; showQuests(area: level / 10); return }
            if won && level == LevelCatalog.levelCount - 1 { showEnding(); return }
            if won { level += 1 }
            beginSelectedLevel()
            return
        }
        guard projectile == nil, !loadingBubble, !ceilingMoving else { return }
        if names.contains("rainbow") && rainbowLeft > 0 { armed = armed == .rainbow ? nil : .rainbow; reload(); refreshHUD(); return }
        if names.contains("bomb") && bombLeft > 0 { armed = armed == .bomb ? nil : .bomb; reload(); refreshHUD(); return }
        if names.contains("swap-bubble") { armed = nil; swap(&currentColor, &nextColor); reload(); refreshHUD(); return }
        guard location.y > 350 && location.y < 710 else { return }
        aiming = true
        aimTouch = touch
        aimGesture.begin(at: BubblePoint(x: Double(location.x), y: Double(location.y)))
        updateAim(location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard aiming, let touch = aimTouch, touches.contains(touch) else { return }
        updateAim(touch.location(in: self))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = aimTouch, touches.contains(touch) else { return }
        synchronizeOperatorRig()
        gameRoot.removeAction(forKey: "control-help")
        aiming = false
        aimGesture.cancel()
        aimTouch = nil
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        guide.removeAllChildren()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        gameRoot.removeAction(forKey: "control-help")
        guard aiming, let touch = aimTouch, touches.contains(touch), !finished, projectile == nil, !loadingBubble, levelMenu == nil else { return }
        aimTouch = nil
        aiming = false
        guide.removeAllChildren()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        synchronizeOperatorRig()
        let lift = touch.location(in: self)
        guard let angle = aimGesture.end(at: BubblePoint(x: Double(lift.x), y: Double(lift.y))) else { return }
        launchShot(angle: angle)
    }

    internal func launchShot(angle: Double) {
        guard hasStartedPuzzle, !suspended, angle.isFinite, abs(angle) <= BubbleGeometry.maxAngle, !finished, projectile == nil, !loadingBubble, !ceilingMoving, levelMenu == nil, let shot = loaded else { return }
        if !attemptCounted && !challengeMode && !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) {
            progress.recordAttempt(level)
            attemptCounted = true
        }
        let kind = armed ?? .color(currentColor)
        let flight = BubbleGeometry.flight(angle: angle, board: board, ceilingOffset: ceilingOffset)
        shotsFired += 1
        questPlay.bounces += BubbleGeometry.bouncePoints(flight).count
        projectile = shot
        pendingFlight = (flight.landing, kind)
        shot.name = "flying-bubble"
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
        guard projectile === shot else { return }
        pendingFlight = nil
        shot.name = nil
        if let pendingGift { progress.adventure.consumeGift(pendingGift); self.pendingGift = nil }
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
            cheers.position = CGPoint(x: 195, y: 267)
            cheers.zPosition = 12
            gameRoot.addChild(cheers)
            cheers.run(.sequence([.group([.moveBy(x: 0, y: 35, duration: 0.9), .sequence([.wait(forDuration: 0.55), .fadeOut(withDuration: 0.35)])]), .removeFromParent()]))
        }
        characterReaction(result.matched.isEmpty ? "We can do it!" : result.dropped.count > 3 ? "Great shot!" : "Nice!", quiet: quiet)
        if !result.matched.isEmpty {
            for index in 0..<1 {
                gameRoot.childNode(withName: "companion-\(index)")?.run(.sequence([.moveBy(x: 0, y: 7, duration: 0.12), .moveBy(x: 0, y: -7, duration: 0.12)]))
            }
            if progress.enabled(.vibration) { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
            audio.effect(kind == .bomb ? "bomb" : "pop", enabled: progress.enabled(.effects), volume: progress.effectsVolume)
        }
        if board.bubbles.isEmpty { finish(success: true); return }
        let newOffset = LevelCatalog.level(level).ceilingOffset(after: shotsFired, seed: pressureSeed)
        if newOffset > ceilingOffset {
            ceilingOffset = newOffset
            positionCeiling(animated: true)
        }
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
        aimTouch = nil
        aimGesture.cancel()
        for name in ["rainbow", "bomb"] { gameRoot.childNode(withName: name)?.isHidden = true }
        aiming = false
        guide.removeAllChildren()
        loaded?.removeFromParent()
        nextNode?.removeFromParent()
        animateCompanion(.animal, frames: success ? [3, 0, 3, 0] : [0])
        animateCompanion(.human, frames: success ? [3, 0, 3, 0] : [0])
        if success {
            if challengeMode && LevelCatalog.level(level).stars(shotsRemaining: shots) == 3 { progress.recordChallenge(level / 10) }
            score += shots * 25
            status.text = level % 3 == 0 && FestivalHost.all.indices.contains(level / 10) ? FestivalHost.all[level / 10].encouragement : "Beautiful popping!"
            let unlocked = progress.recordVictory(index: level, score: score,
                                                   stars: LevelCatalog.level(level).stars(shotsRemaining: shots))
            let newQuests = progress.adventure.recordWin(level: level, play: questPlay, completedLevels: progress.completedCount)
            completedQuest = newQuests.first
            if let completedQuest { status.text = "Story complete: \(completedQuest.title)" }
            if !unlocked.isEmpty && completedQuest == nil { status.text = "New buddy: \(unlocked.map { $0.name }.joined(separator: ", "))" }
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
            for index in 0..<1 {
                gameRoot.childNode(withName: "companion-\(index)")?.run(.repeat(.sequence([.moveBy(x: 0, y: 10, duration: 0.15), .moveBy(x: 0, y: -10, duration: 0.15)]), count: 3))
            }
        } else {
            for index in 0..<1 {
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
        if success { label("\(shots) shots saved", size: 15, point: CGPoint(x: 0, y: 5), parent: panel) }
        let message = SKLabelNode(fontNamed: "AvenirNext-Medium")
        message.text = success ? status.text : "Try a wall bounce or swap your next bubble."
        message.fontSize = 14
        message.numberOfLines = 2
        message.preferredMaxLayoutWidth = 278
        message.verticalAlignmentMode = .center
        message.position = CGPoint(x: 0, y: -35)
        panel.addChild(message)
        menuButton(success ? (completedQuest != nil ? "Collect reward" : level == LevelCatalog.levelCount - 1 ? "Celebrate!" : "Next level") : "Try again", name: "result-next", point: CGPoint(x: 0, y: -99), parent: panel, width: 270, height: 56)
        shotsLabel.text = "\(shots)"
    }
}

private extension FestivalScene {
    internal func interactionNames(at location: CGPoint) -> [String] {
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
        if levelMenu == nil, !finished, let next = nextNode,
           CGRect(x: next.position.x - minimum / 2, y: next.position.y - minimum / 2,
                  width: minimum, height: minimum).contains(point) {
            return names + ["swap-bubble"]
        }
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
        if neighborsAvailable(in: area) {
            menuButton("Meet the neighbors", name: "neighbors", point: CGPoint(x: 195, y: 201), parent: overlay, height: 44)
        }
        menuButton("Back to the map", name: "quest-back", point: CGPoint(x: 195, y: 130), parent: overlay)
    }

    private func neighborsAvailable(in area: Int) -> Bool {
        area * LevelCatalog.levelsPerArea <= progress.unlockedLevel && FestivalNeighbor.all.contains { $0.area == area }
    }

    func showNeighbors() {
        guard neighborsAvailable(in: questArea) else { showLevels(); return }
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
        if FestivalQuest.all.contains(where: { $0.area == questArea }) {
            menuButton("Festival favors", name: "quest-list", point: CGPoint(x: 195, y: 140), parent: overlay)
        } else {
            menuButton("Back to the map", name: "quest-back", point: CGPoint(x: 195, y: 140), parent: overlay)
        }
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
        menuButton("Neighbors", name: "neighbors", point: CGPoint(x: 195, y: 163), parent: overlay, height: 44)
        menuButton("Back to the map", name: "quest-back", point: CGPoint(x: 195, y: 92), parent: overlay, height: 44)
    }

    func neighborTexture(_ neighbor: FestivalNeighbor) -> SKTexture {
        if neighbor.portraitIndex >= 8 {
            let index = neighbor.portraitIndex - 8
            return SKTexture(rect: CGRect(x: CGFloat(index % 3) / 3, y: CGFloat(1 - index / 3) / 2,
                                          width: 1.0 / 3, height: 0.5),
                             in: SKTexture(imageNamed: "festival-summer-neighbors"))
        }
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
                label("\(friend.name) has joined your buddies!", size: 17, point: CGPoint(x: 195, y: 357), parent: overlay)
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
        panel(width: 342, height: 74, point: CGPoint(x: 195, y: 729), parent: overlay)
        label("A buddy joined the festival!", size: 25, point: CGPoint(x: 195, y: 727), parent: overlay)
        if !UIAccessibility.isReduceMotionEnabled {
            for index in 0..<16 {
                let piece = SKShapeNode(rectOf: CGSize(width: 5, height: 8))
                piece.fillColor = palette[index % palette.count]; piece.strokeColor = .clear
                piece.position = CGPoint(x: 30 + CGFloat(index) * 22, y: 805)
                overlay.addChild(piece)
                piece.run(.sequence([.group([.moveBy(x: index % 2 == 0 ? 20 : -20, y: -450, duration: 2), .rotate(byAngle: .pi * 2, duration: 2), .fadeOut(withDuration: 2)]), .removeFromParent()]))
            }
        }
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
        paragraph(prize == .rainbow || prize == .bomb ? "Saved to your booster supply. Use it from the bottom controls during a puzzle." : "Saved to your collection. Choose pins in Buddies on the festival map; bunting appears at your stations.", y: 400, parent: overlay)
        label("\(progress.adventure.rainbowGifts) extra rainbow • \(progress.adventure.bombGifts) extra bomb", size: 15, point: CGPoint(x: 195, y: 299), parent: overlay)
        menuButton("Back to the wheel", name: "wheel-return", point: CGPoint(x: 195, y: 185), parent: overlay, height: 48)
        menuButton("Festival map", name: "quest-back", point: CGPoint(x: 195, y: 115), parent: overlay, height: 48)
    }

    internal func showGameMenu() {
        menuKind = "game-menu"; returnMenu = "game"
        let overlay = makeMenu(background: LevelCatalog.level(level).background)
        panel(width: 330, height: 340, point: CGPoint(x: 195, y: 440), parent: overlay)
        label("Puzzle menu", size: 28, point: CGPoint(x: 195, y: 562), parent: overlay)
        menuButton("Keep playing", name: "game-resume", point: CGPoint(x: 195, y: 492), parent: overlay, height: 50)
        menuButton("Restart puzzle", name: "game-restart", point: CGPoint(x: 195, y: 424), parent: overlay, height: 50)
        menuButton("Settings", name: "settings", point: CGPoint(x: 195, y: 356), parent: overlay, height: 44)
        menuButton("Start Menu", name: "home", point: CGPoint(x: 195, y: 292), parent: overlay, height: 44)
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
        text.text = control == "rainbow" ? "Rainbow pops the largest neighboring color group." : "Bomb pops bubbles nearby. The guide previews its reach."
        text.fontSize = 16; text.numberOfLines = 3; text.preferredMaxLayoutWidth = 285
        text.verticalAlignmentMode = .center; tip.addChild(text)
        tip.run(.sequence([.wait(forDuration: 3), .fadeOut(withDuration: 0.3), .removeFromParent()]))
    }

    func showPracticeHint() {
        guard hasStartedPuzzle, !finished, levelMenu == nil, level == 0, !progress.practiceDone, progress.stars(0) == 0 else { return }
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
        // Finish an already committed shot before pausing or leaving the puzzle.
        if let shot = projectile, let flight = pendingFlight {
            shot.removeAllActions()
            settle(shot, landing: flight.landing, kind: flight.kind)
        }
        guard hasStartedPuzzle, !finished, projectile == nil, !board.bubbles.isEmpty, !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) else { return }
        progress.save(GameCheckpoint(level: level, board: board, shots: shots, score: score,
                                     current: currentColor, next: nextColor, bag: colorBag,
                                     rainbow: rainbowLeft, bomb: bombLeft, play: questPlay, challenge: challengeMode,
                                     freeRainbow: freeRainbow, freeBomb: freeBomb, ceilingOffset: ceilingOffset, shotsFired: shotsFired, pressureSeed: pressureSeed))
        profiles.persistActive()
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
        let positions: [(String, CGFloat)] = leftHand ? [("game-menu", 342), ("rainbow", 48), ("bomb", 132)] : [("game-menu", 48), ("rainbow", 132), ("bomb", 258)]
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
        menuButton("Buddies", name: "accessory-back", point: CGPoint(x: 195, y: 120), parent: overlay, height: 44)
    }

    func companionTexture(_ friend: Companion, frame: Int, glance: Bool = false) -> SKTexture {
        if friend.kind == .animal && friend.atlasIndex >= 12 {
            let row = friend.atlasIndex - 12
            let columns: [CGFloat] = [0, 362, 736, 1086, 1448]
            let column = min(3, max(0, frame))
            let rowSplits: [CGFloat] = [394, 398, 394, 398]
            let boundaries: [CGFloat] = [0, rowSplits[column], 755, 1086]
            return SKTexture(rect: CGRect(x: columns[column] / 1448,
                                          y: (1086 - boundaries[row + 1]) / 1086,
                                          width: (columns[column + 1] - columns[column]) / 1448,
                                          height: (boundaries[row + 1] - boundaries[row]) / 1086),
                             in: SKTexture(imageNamed: "festival-summer-buddy-motion"))
        }
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
        if kind == .human { return } // The articulated arm owns the operator motion.
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
        cannon.fillColor = colors[(level / 10) % colors.count]
        cannon.strokeColor = .systemYellow
        cannon.removeAllChildren()
        let emblem = questIcon(symbols[(level / 10) % symbols.count], size: 18, color: .white)
        emblem.position.y = -31; cannon.addChild(emblem)
        gameRoot.childNode(withName: "machine-trim")?.removeFromParent()
        let trim = SKNode(); trim.name = "machine-trim"; trim.zPosition = -0.1
        gameRoot.addChild(trim)
        for side in [-1, 1] {
            let ornament: SKShapeNode
            switch (level / 10) % LevelCatalog.originalAreas.count {
            case 1: ornament = SKShapeNode(ellipseOf: CGSize(width: 12, height: 34))
            case 2: ornament = SKShapeNode(rectOf: CGSize(width: 15, height: 24), cornerRadius: 6)
            case 3: ornament = SKShapeNode(ellipseOf: CGSize(width: 26, height: 10))
            case 4: ornament = SKShapeNode(rectOf: CGSize(width: 15, height: 15), cornerRadius: 2); ornament.zRotation = .pi / 4
            default: ornament = SKShapeNode(rectOf: CGSize(width: 12, height: 22), cornerRadius: 3)
            }
            ornament.position = CGPoint(x: 195 + CGFloat(side) * 36, y: 151)
            ornament.fillColor = colors[(level / 10) % colors.count]; ornament.strokeColor = .systemYellow
            trim.addChild(ornament)
        }
        synchronizeOperatorRig()
    }

    internal func synchronizeOperatorRig() {
        guard let buddy = gameRoot.childNode(withName: "companion-1") as? SKSpriteNode,
              let wheel = gameRoot.childNode(withName: "handwheel") else { return }
        let friend = operatorFriend ?? progress.selected(.human)
        operatorFriend = friend
        buddy.removeAction(forKey: "operating"); buddy.removeAction(forKey: "breathing"); buddy.yScale = 1
        buddy.texture = operatorTexture(friend, part: 0)
        let row = friend.atlasIndex - 4
        let boundaries: [CGFloat] = [0, 223, 435, 654, 876, 1099, 1326, 1550, 1774]
        let sockets: [CGPoint] = [CGPoint(x: 192, y: 128), CGPoint(x: 183, y: 344), CGPoint(x: 188, y: 562), CGPoint(x: 194, y: 785), CGPoint(x: 197, y: 1009), CGPoint(x: 194, y: 1232), CGPoint(x: 195, y: 1456), CGPoint(x: 194, y: 1680)]
        // Overlap the sleeve at its shoulder seam, above the old cuff socket.
        let socket = CGPoint(x: ((sockets[row].x - 9 - 35) / 215 - 0.5) * buddy.size.width,
                             y: (boundaries[row + 1] - sockets[row].y + 12) / (boundaries[row + 1] - boundaries[row]) * buddy.size.height)
        if operatorBuddyID != friend.id || buddy.childNode(withName: "operator-arm") == nil {
            operatorBuddyID = friend.id
            gameRoot.childNode(withName: "operator-arm")?.removeFromParent()
            buddy.childNode(withName: "operator-arm")?.removeFromParent()
            let arm = SKNode(); arm.name = "operator-arm"; arm.zPosition = 12; arm.xScale = -1
            for part in 1...2 {
                let sprite = SKSpriteNode(texture: operatorTexture(friend, part: part)); sprite.name = "part-\(part)"
                // Pivots sit on the painted joint, excluding the transparent crop margins.
                sprite.anchorPoint = part == 1 ? CGPoint(x: 15.0 / 153, y: 92.0 / 123) : CGPoint(x: 21.0 / 133, y: 31.0 / 62)
                let length = part == 1 ? OperatorArmPose.upperLength : OperatorArmPose.forearmLength
                let scale = CGFloat(length) / (part == 1 ? hypot(121, 22) : hypot(102, 5))
                sprite.size = part == 1 ? CGSize(width: 153 * scale, height: 123 * scale) : CGSize(width: 133 * scale, height: 62 * scale)
                sprite.zPosition = CGFloat(part); arm.addChild(sprite)
            }
            buddy.addChild(arm)
            // Every joint, including the hand, belongs to the same character.
            let grip = SKSpriteNode(texture: operatorTexture(friend, part: 3))
            grip.name = "operator-grip"
            grip.anchorPoint = CGPoint(x: 8.0 / 72, y: 31.0 / 59)
            grip.size = CGSize(width: 19, height: 16)
            grip.zPosition = 12
            arm.addChild(grip)
        }
        guard let arm = buddy.childNode(withName: "operator-arm") else { return }
        let shoulder = buddy.convert(socket, to: gameRoot)
        // A short rim stroke follows steering without forcing a full crank rotation.
        let stroke = -CGFloat(0.65) + max(-CGFloat(0.2), min(CGFloat(0.2), wheel.zRotation * 0.08))
        let contact = CGPoint(x: wheel.position.x + cos(stroke) * 21,
                              y: wheel.position.y + sin(stroke) * 21)
        let pose = OperatorArmPose.gripping(shoulder: BubblePoint(x: shoulder.x, y: shoulder.y), hand: BubblePoint(x: contact.x, y: contact.y), palmLength: OperatorArmPose.palmLength)
        let a = arm.convert(CGPoint(x: pose.shoulder.x, y: pose.shoulder.y), from: gameRoot)
        let b = arm.convert(CGPoint(x: pose.elbow.x, y: pose.elbow.y), from: gameRoot)
        let c = arm.convert(CGPoint(x: pose.hand.x, y: pose.hand.y), from: gameRoot)
        arm.childNode(withName: "part-1")?.position = a
        arm.childNode(withName: "part-1")?.zRotation = atan2(b.y - a.y, b.x - a.x) - atan2(-22, 121)
        arm.childNode(withName: "part-2")?.position = b
        let direction = atan2(c.y - b.y, c.x - b.x)
        arm.childNode(withName: "part-2")?.zRotation = direction - atan2(5, 102)
        arm.childNode(withName: "operator-grip")?.position = c
        arm.childNode(withName: "operator-grip")?.zRotation = direction
    }

    func operatorTexture(_ friend: Companion, part: Int) -> SKTexture {
        let key = "\(friend.id)-\(part)"
        if let cached = operatorTextures[key] { return cached }
        let row = friend.atlasIndex - 4
        let boundaries: [CGFloat] = [0, 223, 435, 654, 876, 1099, 1326, 1550, 1774]
        let sleeveY: [CGFloat] = [54, 262, 474, 702, 919, 1139, 1371, 1595]
        let forearmY: [CGFloat] = [86, 294, 507, 734, 950, 1172, 1402, 1627]
        let handY: [CGFloat] = [81, 289, 503, 731, 948, 1169, 1398, 1624]
        let box: CGRect
        switch part {
        case 1: box = CGRect(x: 319, y: sleeveY[row] - 3, width: 153, height: 123)
        case 2: box = CGRect(x: 525, y: forearmY[row] - 3, width: 133, height: 62)
        case 3: box = CGRect(x: 744, y: handY[row] - 3, width: 72, height: 59)
        default: box = CGRect(x: 35, y: boundaries[row], width: 215, height: boundaries[row + 1] - boundaries[row])
        }
        let texture = SKTexture(rect: CGRect(x: box.minX / 887, y: (1774 - box.maxY) / 1774, width: box.width / 887, height: box.height / 1774), in: SKTexture(imageNamed: "festival-operator-rig"))
        operatorTextures[key] = texture
        return texture
    }

    func characterReaction(_ text: String, quiet: Bool) {
        gameRoot.childNode(withName: "character-reaction")?.removeFromParent()
        let note = panel(width: 119, height: 27, point: CGPoint(x: 301, y: 267), parent: gameRoot)
        note.name = "character-reaction"; note.zPosition = 14
        label(text, size: 12, point: CGPoint(x: 0, y: -4), parent: note)
        note.run(.sequence([.wait(forDuration: quiet ? 0.65 : 0.9), .fadeOut(withDuration: 0.2), .removeFromParent()]))
    }

    func popEffect(at location: CGPoint, color: UIColor, special: SpecialBubble?, quiet: Bool) {
        let ring = SKShapeNode(circleOfRadius: 19)
        ring.position = location; ring.zPosition = 12; ring.strokeColor = special == nil ? color : .systemYellow
        ring.lineWidth = special == nil ? 3 : 5; ring.fillColor = .clear
        gameRoot.addChild(ring)
        ring.run(.sequence([.group([.scale(to: quiet ? 1 : special == nil ? 1.65 : 2.15, duration: 0.25), .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        guard !quiet else { return }
        for index in 0..<(special == nil ? 5 : 8) {
            let fragment = SKShapeNode(rectOf: CGSize(width: index % 2 == 0 ? 4 : 2, height: index % 2 == 0 ? 8 : 4), cornerRadius: 1)
            fragment.zRotation = CGFloat(index) * .pi / 4
            fragment.fillColor = index % 2 == 0 ? color : .white; fragment.strokeColor = .clear
            fragment.position = location; fragment.zPosition = 13
            gameRoot.addChild(fragment)
            let angle = CGFloat(index) * .pi * 2 / CGFloat(special == nil ? 5 : 8)
            fragment.run(.sequence([.group([.moveBy(x: cos(angle) * 44, y: sin(angle) * 44, duration: 0.3), .fadeOut(withDuration: 0.3), .scale(to: 0.2, duration: 0.3)]), .removeFromParent()]))
        }
    }

    func dropTrail(at location: CGPoint, color: UIColor) {
        for index in 0..<5 {
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
        box.fillColor = UIColor(white: 0.96, alpha: 1)
        box.name = name
        if let image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 24, weight: .semibold))?.withTintColor(UIColor(white: 0.55, alpha: 1), renderingMode: .alwaysOriginal) {
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
        let assembly = SKNode(); assembly.name = "ceiling-rail"; gameRoot.addChild(assembly)
        let rail = SKShapeNode(rectOf: CGSize(width: 336, height: 15), cornerRadius: 5)
        rail.position = CGPoint(x: 195, y: 717)
        rail.fillColor = UIColor(red: 0.55, green: 0.31, blue: 0.16, alpha: 1)
        rail.strokeColor = UIColor(red: 1, green: 0.82, blue: 0.51, alpha: 1)
        rail.lineWidth = 2
        assembly.addChild(rail)
        for (index, x) in [CGFloat(34), CGFloat(356)].enumerated() {
            let hanger = SKShapeNode(rectOf: CGSize(width: 7, height: 26), cornerRadius: 3)
            hanger.name = "ceiling-support-\(index)"
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
            assembly.addChild(hook)
        }
        let line = CGMutablePath(); line.move(to: CGPoint(x: 28, y: 338)); line.addLine(to: CGPoint(x: 362, y: 338))
        let danger = SKShapeNode(path: line); danger.strokeColor = .systemOrange; danger.lineWidth = 2; danger.alpha = 0.7
        gameRoot.addChild(danger)
    }

    func positionCeiling(animated: Bool) {
        let duration = animated && !UIAccessibility.isReduceMotionEnabled ? 0.3 : 0
        for (cell, node) in nodes {
            node.removeAction(forKey: "ceiling-position")
            if duration > 0 { node.run(.move(to: point(cell), duration: duration), withKey: "ceiling-position") }
            else { node.position = point(cell) }
        }
        let rail = gameRoot.childNode(withName: "ceiling-rail")
        rail?.removeAllActions()
        if duration > 0 { rail?.run(.moveTo(y: -CGFloat(ceilingOffset), duration: duration)) }
        else { rail?.position.y = -CGFloat(ceilingOffset) }
        for index in 0..<2 {
            if let support = gameRoot.childNode(withName: "ceiling-support-\(index)") as? SKShapeNode {
                support.path = CGPath(roundedRect: CGRect(x: -3.5, y: -13 - CGFloat(ceilingOffset) / 2, width: 7, height: 26 + CGFloat(ceilingOffset)), cornerWidth: 3, cornerHeight: 3, transform: nil)
                support.position.y = 738 - CGFloat(ceilingOffset) / 2
            }
        }
        if duration > 0 {
            ceilingMoving = true
            gameRoot.run(.sequence([.wait(forDuration: duration), .run { [weak self] in self?.ceilingMoving = false }]), withKey: "ceiling-move")
        }
    }

    internal func closeMenu() {
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
        case "festival": showFestival()
        case "players": showPlayers()
        case "map": showLevels()
        case "settings": showSettings()
        case "game-menu": showGameMenu()
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
        menuButton(returnMenu == "game-menu" ? "Back to puzzle menu" : "Start Menu", name: returnMenu == "game-menu" ? "back" : "home", point: CGPoint(x: 195, y: 78), parent: overlay, width: 270, height: 50)
    }

    func showTutorial() {
        menuKind = "tutorial"
        let overlay = makeMenu(background: "festival-courtyard")
        let titles = ["Aim and pop", "Try a wall bounce", "A little extra help", "Festival surprises"]
        let bodies = ["Drag above the launcher to aim. Release to shoot. Drag back down toward the launcher to cancel. Match three bubbles with the same color and symbol.",
                      "Use the walls to reach tricky spots. Pop a supporting group to drop the bubbles below it. Clear the board to win! Tap the bubble your buddy holds to swap it with the loaded bubble.",
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
        else if returnMenu == "game", FestivalHost.all.indices.contains(level / 10), !progress.hasMet(FestivalHost.all[level / 10]) {
            menuKind = "game"
            showHost(FestivalHost.all[level / 10])
        } else { restoreMenu() }
    }

    func showMapBuddies() {
        showLevels()
        menuKind = "map-buddies"
        guard let overlay = levelMenu else { return }
        panel(width: 360, height: 342, point: CGPoint(x: 195, y: 258), parent: overlay)
        label("Choose your buddies", size: 24, point: CGPoint(x: 195, y: 397), parent: overlay)
        let pages = (Companion.all.count + 5) / 6
        friendsPage = min(max(0, friendsPage), pages - 1)
        for (index, friend) in Companion.all.dropFirst(friendsPage * 6).prefix(6).enumerated() {
            let x = CGFloat(81 + (index % 3) * 114), y = CGFloat(327 - (index / 3) * 103)
            let tile = panel(width: 102, height: 96, point: CGPoint(x: x, y: y), parent: overlay)
            tile.name = "friend-\(friend.id)"
            let available = progress.unlocked(friend)
            let portrait = SKSpriteNode(texture: companionTexture(friend, frame: 0), size: CGSize(width: 56, height: 56))
            portrait.position.y = 17; portrait.alpha = available ? 1 : 0.35; tile.addChild(portrait)
            label(friend.name, size: 12, point: CGPoint(x: 0, y: -22), parent: tile)
            label(available ? progress.selected(friend.kind).id == friend.id ? "Selected ✓" : "Tap to choose" : "Locked", size: 10, point: CGPoint(x: 0, y: -39), parent: tile)
        }
        menuButton("More \(friendsPage + 1)/\(pages)", name: "friends-page", point: CGPoint(x: 81, y: 136), parent: overlay, width: 102, height: 40)
        menuButton("Pins", name: "accessories", point: CGPoint(x: 195, y: 136), parent: overlay, width: 102, height: 40)
        menuButton("Done", name: "map-buddies-close", point: CGPoint(x: 309, y: 136), parent: overlay, width: 102, height: 40)
    }

    func showEnding() {
        menuKind = "ending"
        let overlay = makeMenu(background: "festival-dusk")
        panel(width: 342, height: 98, point: CGPoint(x: 195, y: 707), parent: overlay)
        label("Festival complete!", size: 30, point: CGPoint(x: 195, y: 717), parent: overlay)
        label("\(LevelCatalog.levelCount) stops • \(progress.totalStars)/\(LevelCatalog.maximumStars) stars", size: 18, point: CGPoint(x: 195, y: 682), parent: overlay)
        let cast = SKSpriteNode(imageNamed: "festival-title-cast")
        cast.size = CGSize(width: 372, height: 372)
        cast.position = CGPoint(x: 195, y: 458)
        overlay.addChild(cast)
        panel(width: 342, height: 100, point: CGPoint(x: 195, y: 243), parent: overlay)
        paragraph("Thanks for bringing the festival to life! Visit your favorite stops and collect every star.", y: 247, parent: overlay)
        menuButton("Explore again", name: "start-adventure", point: CGPoint(x: 195, y: 145), parent: overlay)
        menuButton("Start Menu", name: "home", point: CGPoint(x: 195, y: 77), parent: overlay, width: 150)
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

    internal func handleMenu(_ incomingNames: [String]) {
        let names = menuKind == "map-buddies" ? FestivalMenuTargets.buddies(incomingNames) : incomingNames
        if wheelSpinning { return }
        if names.contains("game-resume") { closeMenu(); return }
        if names.contains("game-restart") { showRetryPrompt(); return }
        if menuKind == "map-buddies" {
            if names.contains("home") { showTitle(); return }
            if names.contains("map-buddies-close") { showLevels(); return }
            if !names.contains("friends-page") && !names.contains("accessories") && !names.contains(where: { $0.hasPrefix("friend-") }) { showLevels(); return }
        }
        if names.contains("players") { showPlayers(); return }
        if names.contains("players-prev") { playersPage = max(0, playersPage - 1); showPlayers(); return }
        if names.contains("players-next") { playersPage += 1; showPlayers(); return }
        if names.contains("player-create") { namePlayer(rename: false); return }
        if names.contains("player-rename") { namePlayer(rename: true); return }
        if let name = names.first(where: { $0.hasPrefix("player-") }) { enterPlayer(String(name.dropFirst(7))); return }
        if names.contains("map-objective") { showQuests(area: mapArea); return }
        if names.contains("festival-menu") { showFestival(); return }
        if names.contains("quick-sound") {
            progress.toggleSound()
            audio.update(area: level / 10, enabled: progress.enabled(.music), volume: progress.musicVolume)
            showSettings(); return
        }
        if names.contains("wheel-return") { showWheel(); return }
        if names.contains("new-buddy"), let buddy = progress.pendingBuddy { showBuddyWelcome(buddy); return }
        if names.contains("buddy-choose") || names.contains("buddy-later") {
            if let buddy = progress.pendingBuddy { if names.contains("buddy-choose") { progress.select(buddy) }; progress.welcome(buddy) }
            if finished && won && level < LevelCatalog.levelCount - 1 && !challengeMode { level += 1; beginSelectedLevel() }
            else if finished { closeMenu() }
            else { showLevels() }
            return
        }
        if names.contains("saved-progress") { showSavedProgress(); return }
        if names.contains("save-now") { saveCheckpoint(); progress.markSaved(); showSavedProgress(); return }
        if names.contains("objective-close") { closeMenu(); return }
        if names.contains("neighbors") { if menuKind == "map" { questArea = mapArea }; showNeighbors(); return }
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
        if names.contains("accessory-back") { showMapBuddies(); return }
        if names.contains("friends-page") { friendsPage = (friendsPage + 1) % ((Companion.all.count + 5) / 6); showMapBuddies(); return }
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
        if names.contains("continue-stop") {
            level = progress.currentLevel
            if progress.checkpoint != nil { closeMenu(); startLevel(restoring: true) }
            else { challengeMode = false; beginSelectedLevel() }
            return
        }
        if names.contains("quest-accept"), let selectedQuest {
            progress.adventure.accept(selectedQuest, unlockedLevel: progress.unlockedLevel)
            if let next = progress.adventure.nextLevel(selectedQuest, unlockedLevel: progress.unlockedLevel) { level = next; challengeMode = false; beginSelectedLevel() }
            return
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
        if names.contains("start-adventure") { mapArea = progress.currentLevel / 10; showLevels() }
        else if names.contains("home") { showTitle() }
        else if names.contains("area-prev") { mapArea = max(0, mapArea - 1); showLevels() }
        else if names.contains("area-next") { mapArea = min(LevelCatalog.areas.count - 1, mapArea + 1); showLevels() }
        else if names.contains("meet-host"), FestivalHost.all.indices.contains(mapArea) {
            let host = FestivalHost.all[mapArea]
            if progress.hostIsAvailable(host) { progress.markMet(host); showQuests(area: mapArea) }
            else if let overlay = levelMenu {
                overlay.childNode(withName: "unlock-message")?.removeFromParent()
                let message = panel(width: 280, height: 32, point: CGPoint(x: 195, y: 139), parent: overlay)
                message.name = "unlock-message"
                label("Reach level \(host.area * 10 + 1) to meet \(host.name)", size: 12, point: CGPoint(x: 0, y: -4), parent: message)
            }
        }
        else if names.contains("settings") { returnMenu = menuKind; showSettings() }
        else if names.contains("friends") { showMapBuddies() }
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
            if friend.kind == .human { operatorFriend = progress.selected(.human); synchronizeOperatorRig() }
            showMapBuddies()
        }
        else if let name = names.first(where: { $0.hasPrefix("level-") }), let selected = Int(name.dropFirst(6)), selected <= progress.unlockedLevel {
            level = selected
            challengeMode = false
            beginSelectedLevel()
        }
    }
}
