import SpriteKit
import UIKit

enum GameplayHUDLayout {
    static let goalCenter = CGPoint(x: 195, y: 750)
    static let settingsCenter = CGPoint(x: 34, y: goalCenter.y)
    static let goalSize = CGSize(width: 390, height: 48)
    static let rescueDestination = CGPoint(x: goalCenter.x - 99, y: goalCenter.y)
}

final class FestivalScene: SKScene {
    private let palette: [UIColor] = [UIColor(red: 1, green: 0.36, blue: 0.53, alpha: 1), .systemYellow, .systemBlue, .systemGreen, .systemPurple]
    private let radius: CGFloat = 21
    private let left: CGFloat = 48
    private let ceiling: CGFloat = 688
    private let origin = CGPoint(x: 195, y: 176)
    private var board = BubbleBoard()
    private var puzzleGoal = PuzzleGoal()
    private var shotBankCount = 0
    private var bankMatches = 0
    private var boosterShots = 0
    private var warnedLowBoard = false
    private var resultsArea = 0
    private var albumTab = "souvenirs"
    private var albumPage = 0
    private var albumArea = 0
    private var albumSelection = 0
    private var replayFilter = ReplayFilter.stars
    private var mapConversationArea: Int?
    private var earnedMedals: Set<ChallengeMedal> = []
    private var earnedCourtyardSouvenir = false
    private var revealedArea: Int?
    private var courtyardWelcomeArea: Int?
    private var previewReturnMenu = "map"
    private var welcomedCompanion: Companion?
    private var announcedWelcomeArea: Int?
    private var courtyardWelcomeAction = "map"
    private var residentMilestone: String?
    private var nodes: [Cell: SKNode] = [:]
    private var companionTextures: [String: SKTexture] = [:]
    private var symbolTextures: [String: SKTexture] = [:]
    private let profiles: GameProfiles
    private lazy var progress = profiles.makeProgress()
    var requestPlayerName: ((String, @escaping (String?) -> Void) -> Void)?
    private var playersPage = 0
    private let audio = FestivalAudio()
    private let gameRoot = SKNode()
    private var mapArea = 0
    private var mapTouch: UITouch?
    private var mapTouchStart = CGPoint.zero
    private var mapTouchOffset: CGFloat = 0
    private var mapDragged = false
    private var pressureBalanceVersion = LevelPlayResults.balanceVersion
    private var menuKind = "title" { didSet { updateMusic() } }
    private var lastMapInteraction: TimeInterval = -10
    private var musicMenu = "title"
    private var returnMenu = "game"
    private var friendsPage = 0
    private var attemptCounted = false
    private var lastCharacterReactionTime: TimeInterval = -10
    private var lastLivesRefresh: TimeInterval = -10
    private var aimTouch: UITouch?
    private var pendingFlight: (landing: Cell?, kind: BubbleShot)?
    private var armed: BubbleShot?
    private var rainbowLeft = 1
    private var bombLeft = 1
    private var colorBag: [Int] = []
    private var introHost: FestivalHost?
    private var dialoguePage = 0
    private var neighborFromMap = false
    private var questReturnMenu = "map"
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
    private var attemptShotBudget = 24
    private var pressureSeed: UInt64 = 0
    private var shotsFired = 0
    private var layoutSeed: UInt64?
    private var generatedLevel: GameLevel?
    private var activeLevel: GameLevel { generatedLevel ?? LevelCatalog.level(level) }
    private var ceilingOffset = 0.0
    private var ceilingMoving = false
    private var timedPressure = TimedCeilingPressure()
    private var lastPressureFrame: TimeInterval?
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
    private var playingChallenge = false
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
        shotsLabel.fontSize = 20
        shotsLabel.numberOfLines = 1
        shotsLabel.preferredMaxLayoutWidth = 74
        shotsLabel.name = "shots-remaining"
        shotsLabel.verticalAlignmentMode = .center
        shotsLabel.position = CGPoint(x: 0, y: 4)
        shotsLabel.zPosition = 8
        gameRoot.childNode(withName: "shots-counter")?.addChild(shotsLabel)
        iconButton("gearshape.fill", name: "game-menu", point: GameplayHUDLayout.settingsCenter)
        boosterButton(.rainbow, name: "rainbow", point: CGPoint(x: 263, y: 84))
        boosterButton(.bomb, name: "bomb", point: CGPoint(x: 330, y: 84))
        level = progress.unlockedLevel
        hasStartedPuzzle = progress.checkpoint != nil
        if ProcessInfo.processInfo.arguments.contains("--dusk-preview") { level = 89 }
        if ProcessInfo.processInfo.arguments.contains("--courtyard-preview") { level = 20 }
        if ProcessInfo.processInfo.arguments.contains("--water-preview") { level = 5 }
        if ProcessInfo.processInfo.arguments.contains("--tea-preview") { level = 34 }
        if ProcessInfo.processInfo.arguments.contains("--aki-preview") { level = 40 }
        if ProcessInfo.processInfo.arguments.contains("--lantern-preview") { level = 42 }
        if ProcessInfo.processInfo.arguments.contains("--pearl-preview") { level = 62 }
        if ProcessInfo.processInfo.arguments.contains("--spark-preview") { level = 82 }
        if ProcessInfo.processInfo.arguments.contains("--beach-preview") { level = 140 }
        if ProcessInfo.processInfo.arguments.contains("--hill-preview") { level = 180 }
        if ProcessInfo.processInfo.arguments.contains("--polish-title-preview") { showTitle() }
        else if ProcessInfo.processInfo.arguments.contains("--polish-menu-preview") { hasStartedPuzzle = true; showGameMenu() }
        else if ProcessInfo.processInfo.arguments.contains("--polish-reward-preview") {
            progress.adventure.synchronize(completedLevels: 1000)
            var random = LayoutRandom(state: 42)
            if let prize = progress.adventure.draw(using: &random) { showWheelReward(prize) }
        }
        else if ProcessInfo.processInfo.arguments.contains("--polish-victory-preview") { hasStartedPuzzle = true; finish(success: true) }
        else if ProcessInfo.processInfo.arguments.contains("--summer-neighbor-preview") { level = 120 }
        if ProcessInfo.processInfo.arguments.contains("--summer-buddies-preview") { level = 120 }
        if ProcessInfo.processInfo.arguments.contains("--summer-map-preview") { level = 140 }
        let summerPreview = ["--beach-preview", "--hill-preview", "--summer-neighbor-preview", "--summer-buddies-preview", "--summer-map-preview"].contains(where: ProcessInfo.processInfo.arguments.contains)
        if summerPreview {
            for index in 0..<LevelCatalog.levelCount { progress.recordVictory(index: index, score: 200, stars: 1) }
            if let otter = Companion.all.first(where: { $0.id == "river-otter" }) { progress.select(otter) }
        }
        mapArea = level / LevelCatalog.levelsPerArea
        if ProcessInfo.processInfo.arguments.contains("--buddy-preview") {
            for index in 0..<20 { progress.recordVictory(index: index, score: 200, stars: 1) }
        }
        if ProcessInfo.processInfo.arguments.contains("--purple-preview") {
            for index in 0..<81 { progress.recordVictory(index: index, score: 200, stars: 1) }
            let quest = FestivalQuest.all[1]
            progress.adventure.accept(quest, unlockedLevel: progress.unlockedLevel)
            for index in 20..<23 { progress.adventure.recordWin(level: index, play: QuestPlay(bounces: 1, dropped: 1), completedLevels: progress.completedCount) }
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
            shotsFired = activeLevel.ceilingInterval * 2
            ceilingOffset = activeLevel.ceilingOffset(after: shotsFired, seed: pressureSeed)
            positionCeiling(animated: false); refreshHUD(); updateAim(CGPoint(x: 290, y: 500))
        }
        else if ProcessInfo.processInfo.arguments.contains("--friends-preview") { friendsPage = 1; showMapBuddies() }
        else if ProcessInfo.processInfo.arguments.contains("--quest-preview") { showQuests(area: 2) }
        else if ProcessInfo.processInfo.arguments.contains("--quest-detail-preview") { showQuest(FestivalQuest.all[2]) }
        else if ProcessInfo.processInfo.arguments.contains("--quest-reward-preview") {
            for index in 0..<43 { progress.recordVictory(index: index, score: 200, stars: 1) }
            let quest = FestivalQuest.all[2]
            progress.adventure.accept(quest, unlockedLevel: progress.unlockedLevel)
            for index in 40..<43 { progress.adventure.recordWin(level: index, play: QuestPlay(collected: [quest.id]), completedLevels: progress.completedCount) }
            showQuest(quest)
        }
        else if ProcessInfo.processInfo.arguments.contains("--wheel-preview") { progress.adventure.synchronize(completedLevels: 5); showWheel() }
        else if ProcessInfo.processInfo.arguments.contains("--ending-preview") { showEnding() }
        else if ProcessInfo.processInfo.arguments.contains("--settings-preview") { returnMenu = "title"; showSettings() }
        else if ProcessInfo.processInfo.arguments.contains("--map-preview") { showLevels() }
        else if ProcessInfo.processInfo.arguments.contains("--host-preview") {
            if let host = FestivalHost.all.first(where: { $0.area == mapArea }) { showHost(host) }
            else if let neighbor = FestivalNeighbor.all.first(where: { $0.area == mapArea }) { showNeighbor(neighbor) }
        }
        else if ProcessInfo.processInfo.arguments.contains("--cancel-preview") { updateAim(CGPoint(x: 195, y: 220)) }
        else if ProcessInfo.processInfo.arguments.contains("--gameplay-preview") || ProcessInfo.processInfo.arguments.contains("--beach-preview") || ProcessInfo.processInfo.arguments.contains("--hill-preview") { updateAim(CGPoint(x: 242, y: 600)) }
        else { showTitle() }
    }

    func setActive(_ active: Bool) {
        if !active { saveCheckpoint(); profiles.persistActive(); updateOperatorAppearance() }
        lastPressureFrame = nil
        suspended = !active
        mapTouch = nil
        gameRoot.removeAction(forKey: "control-help")
        isPaused = !active
        aiming = false
        aimGesture.cancel()
        aimTouch = nil
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        guide.removeAllChildren()
        audio.suspend(!active)
        if active { updateControlLayout() }
        updateMusic()
    }

    private func updateMusic() {
        if !progress.enabled(.effects) || progress.effectsVolume == 0 { audio.stopEffects() }
        // Settings and pause sheets keep the current musical context.
        if !["settings", "sound-levels", "play-results", "game-menu", "retry-prompt", "objectives", "special-help"].contains(menuKind) { musicMenu = menuKind }
        audio.update(name: FestivalAudio.track(menu: musicMenu, area: musicMenu == "map" ? mapArea : level / LevelCatalog.levelsPerArea, challenge: challengeMode), enabled: progress.enabled(.music), volume: progress.musicVolume)
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
        let veil = SKShapeNode(rectOf: CGSize(width: 390, height: 360), cornerRadius: 14)
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
            lantern.name = "ambient-lantern-\(Int(x))"
            lantern.position = CGPoint(x: x, y: 481)
            lantern.zPosition = -2
            gameRoot.addChild(lantern)
            lantern.run(.repeatForever(.sequence([.group([.moveBy(x: 0, y: 4, duration: 1.8), .rotate(byAngle: 0.08, duration: 1.8)]), .group([.moveBy(x: 0, y: -4, duration: 1.8), .rotate(byAngle: -0.08, duration: 1.8)])])))
        }
        let counter = panel(width: 84, height: 38, point: CGPoint(x: 195, y: 126), parent: gameRoot)
        counter.name = "shots-counter"; counter.zPosition = 7
        counter.path = CGPath(roundedRect: CGRect(x: -42, y: -19, width: 84, height: 38), cornerWidth: 7, cornerHeight: 7, transform: nil)
        counter.lineWidth = 2
        let counterCaption = SKLabelNode(fontNamed: "AvenirNext-Bold")
        counterCaption.name = "shots-caption"; counterCaption.text = "SHOTS LEFT"; counterCaption.fontSize = 9
        counterCaption.fontColor = .white; counterCaption.verticalAlignmentMode = .center
        counterCaption.position = CGPoint(x: 0, y: -11); counter.addChild(counterCaption)
        decorateRail()
        for (index, x) in [CGFloat(74), CGFloat(331)].enumerated() {
            let friend = progress.selected(index == 0 ? .animal : .human)
            let companion = SKSpriteNode(texture: companionTexture(friend, frame: 0), size: CGSize(width: 125, height: 125))
            companion.anchorPoint = CGPoint(x: 0.5, y: 0)
            companion.position = CGPoint(x: x, y: 134)
            companion.name = "companion-\(index)"
            gameRoot.addChild(companion)
        }
        let base = SKShapeNode(rectOf: CGSize(width: 354, height: 14), cornerRadius: 5)
        base.name = "character-platform"
        base.position = CGPoint(x: origin.x, y: 50)
        base.zPosition = -1
        base.fillColor = UIColor(red: 0.43, green: 0.23, blue: 0.13, alpha: 1)
        base.strokeColor = UIColor(red: 1, green: 0.77, blue: 0.42, alpha: 1)
        FestivalStyle.finish(base, as: .wood)
        gameRoot.addChild(base)
        let surface = SKShapeNode(rectOf: CGSize(width: 350, height: 88), cornerRadius: 4)
        surface.name = "light-wood-platform"
        surface.position = CGPoint(x: origin.x, y: 101)
        surface.zPosition = -0.5
        surface.fillColor = UIColor(red: 0.76, green: 0.48, blue: 0.26, alpha: 1)
        surface.strokeColor = UIColor(red: 1, green: 0.79, blue: 0.43, alpha: 1)
        FestivalStyle.finish(surface, as: .wood)
        gameRoot.addChild(surface)
        // Booster controls sit directly in the expanded lighter wooden surface.
        let dock = SKNode()
        dock.name = "control-dock"; dock.position = CGPoint(x: 195, y: 67)
        gameRoot.addChild(dock)
        let boosterTray = panel(width: 130, height: 58, point: CGPoint(x: 296.5, y: 84), parent: gameRoot)
        boosterTray.name = "booster-tray"; boosterTray.zPosition = -0.5
        boosterTray.fillColor = .clear; boosterTray.strokeColor = .clear
        for x in [CGFloat(74), 331] {
            let shadow = SKShapeNode(ellipseOf: CGSize(width: 70, height: 8))
            shadow.position = CGPoint(x: x, y: 139)
            shadow.zPosition = -0.25
            shadow.fillColor = UIColor.brown.withAlphaComponent(0.45)
            shadow.strokeColor = .clear
            gameRoot.addChild(shadow)
        }
        let barrelPath = CGMutablePath()
        barrelPath.move(to: CGPoint(x: -19, y: -38))
        barrelPath.addLine(to: CGPoint(x: -27, y: 30))
        barrelPath.addQuadCurve(to: CGPoint(x: 27, y: 30), control: CGPoint(x: 0, y: 38))
        barrelPath.addLine(to: CGPoint(x: 19, y: -38))
        barrelPath.closeSubpath()
        let cannon = SKShapeNode(path: barrelPath)
        cannon.position = origin
        cannon.name = "cannon"
        cannon.fillColor = UIColor(red: 0.60, green: 0.33, blue: 0.16, alpha: 1)
        cannon.strokeColor = UIColor(red: 1, green: 0.79, blue: 0.43, alpha: 1)
        cannon.lineWidth = 3
        gameRoot.addChild(cannon)
        let nextStand = panel(width: 40, height: 28, point: CGPoint(x: 113, y: 151), parent: gameRoot)
        nextStand.fillColor = UIColor(red: 0.45, green: 0.27, blue: 0.16, alpha: 0.65)
        decorateMechanism()
    }

    @discardableResult
    private func panel(width: CGFloat, height: CGFloat, point: CGPoint, parent: SKNode) -> SKShapeNode {
        let node = SKShapeNode(rectOf: CGSize(width: width, height: height), cornerRadius: min(20, height / 2))
        node.position = point
        node.fillColor = FestivalStyle.ink.withAlphaComponent(0.94)
        node.strokeColor = UIColor(red: 1, green: 0.90, blue: 0.73, alpha: 0.8)
        FestivalStyle.finish(node, as: .panel)
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

    override func update(_ currentTime: TimeInterval) {
        let delta = lastPressureFrame.map { currentTime - $0 } ?? 0
        lastPressureFrame = currentTime
        let canCount = !suspended && hasStartedPuzzle && attemptCounted && !finished && levelMenu == nil &&
            gameRoot.childNode(withName: "puzzle-coach") == nil && gameRoot.childNode(withName: "control-tip") == nil &&
            gameRoot.childNode(withName: "level-arrival") == nil &&
            !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") })
        if canCount && timedPressure.advance(by: delta, level: activeLevel, canDescend: !aiming && projectile == nil && !loadingBubble && !ceilingMoving) {
            ceilingOffset = min(240, ceilingOffset + activeLevel.timedCeilingStep)
            positionCeiling(animated: true)
            if board.bubbles.keys.contains(where: { point($0).y < CGFloat(BubbleGeometry.lossLine) }) { finish(success: false) }
            else { saveCheckpoint() }
        }

        guard !suspended, currentTime - lastLivesRefresh >= 1 else { return }
        lastLivesRefresh = currentTime
        if menuKind == "lives" { refreshLivesScreen() }
        if menuKind == "map", let label = levelMenu?.childNode(withName: "//map-tries") as? SKLabelNode {
            label.text = "♥ \(progress.lives(for: progress.unlockedLevel).available)"
        }
        if finished, let label = gameRoot.childNode(withName: "//result-tries") as? SKLabelNode {
            let state = progress.lives(for: level, challenge: challengeMode)
            label.text = "\(state.available)/5 tries" + (state.available < 5 ? " • +1 in " + state.countdown(at: Date()) : "")
            if !won, let button = gameRoot.childNode(withName: "//result-next"),
               let title = button.children.compactMap({ $0 as? SKLabelNode }).first {
                title.text = state.available > 0 ? "Try again" : "Wait for a try"
            }
        }
    }

    private func startLevel(restoring: Bool = false) {
        let saved = restoring ? progress.checkpoint : nil
        if let saved { level = saved.level; challengeMode = saved.challenge ?? false }
        playingChallenge = challengeMode
        if let saved {
            layoutSeed = saved.layoutSeed
            generatedLevel = saved.layoutSeed.map { LevelCatalog.level(level).randomized(seed: $0) } ?? LevelCatalog.level(level)
        } else {
            let fresh = progress.freshLayout(for: level)
            generatedLevel = fresh.level; layoutSeed = fresh.seed
        }
        pressureSeed = saved.map { $0.pressureSeed ?? 0 } ?? UInt64.random(in: 1...UInt64.max)
        pressureBalanceVersion = saved.map { $0.balanceVersion ?? 3 } ?? LevelPlayResults.balanceVersion
        shotsFired = saved?.shotsFired ?? 0
        ceilingOffset = saved?.ceilingOffset ?? 0
        timedPressure = TimedCeilingPressure(elapsed: saved?.timedCeilingElapsed ?? 0, drops: saved?.timedCeilingDrops ?? 0)
        lastPressureFrame = nil
        ceilingMoving = false
        gameRoot.removeAction(forKey: "ceiling-move")
        positionCeiling(animated: false)
        pendingGift = nil
        pendingFlight = nil
        for name in ["practice-caption", "control-tip", "character-reaction", "puzzle-coach"] { gameRoot.childNode(withName: name)?.removeFromParent() }
        gameRoot.childNode(withName: "result")?.removeFromParent()
        projectile?.removeFromParent()
        projectile = nil
        guide.removeAllChildren()
        playfield.removeAllChildren()
        nodes.removeAll()
        board = activeLevel.board
        puzzleGoal = activeLevel.goal
        shotBankCount = 0; bankMatches = 0; boosterShots = 0; warnedLowBoard = false
        earnedMedals = []; earnedCourtyardSouvenir = false; revealedArea = nil
        shots = activeLevel.shots
        rainbowLeft = 1 + progress.adventure.rainbowGifts
        bombLeft = 1 + progress.adventure.bombGifts
        freeRainbow = !challengeMode; freeBomb = !challengeMode
        if challengeMode { shots = max(12, shots * 3 / 4); rainbowLeft = 0; bombLeft = 0 }
        attemptShotBudget = saved.map { $0.shotBudget ?? max($0.shots, activeLevel.shots) } ?? shots
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
            let sprite = gameRoot.childNode(withName: "companion-\(index)") as? SKSpriteNode
            sprite?.removeAllActions()
            sprite?.texture = companionTexture(friend, frame: 0)
            sprite?.position.y = 134
            sprite?.zRotation = 0
            sprite?.zPosition = 0
            sprite?.xScale = index == 1 ? -1 : 1
            if index == 0 && !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled { sprite?.run(.repeatForever(.sequence([.scaleY(to: 1.015, duration: 1.5), .scaleY(to: 1, duration: 1.5)])), withKey: "breathing") }
        }
        score = 0
        questPlay = QuestPlay()
        attemptCounted = false
        gameRoot.childNode(withName: "handwheel")?.zRotation = 0
        gameRoot.childNode(withName: "cannon")?.removeAction(forKey: "cannon-recoil")
        gameRoot.childNode(withName: "cannon")?.position = origin
        gameRoot.childNode(withName: "cannon")?.zRotation = 0
        for name in ["level-arrival", "target-feedback", "victory-confetti"] { gameRoot.childNode(withName: name)?.removeFromParent() }
        completedQuest = nil
        finished = false
        aiming = false
        updateMachineStyle()
        let area = LevelCatalog.areas[level / LevelCatalog.levelsPerArea]
        backdrop?.texture = SKTexture(imageNamed: activeLevel.background)
        backdrop?.color = UIColor(red: 0.25, green: 0.27, blue: 0.55, alpha: 1)
        backdrop?.colorBlendFactor = area.nightTint ? 0.18 : 0
        updateMusic()
        if let saved, let restoredBoard = saved.board {
            board = restoredBoard; shots = saved.shots; score = saved.score
            currentColor = saved.currentColor; nextColor = saved.nextColor; colorBag = saved.bag
            freeRainbow = saved.freeRainbow ?? (saved.rainbow > 0)
            freeBomb = saved.freeBomb ?? (saved.bomb > 0)
            rainbowLeft = challengeMode ? 0 : (freeRainbow ? 1 : 0) + progress.adventure.rainbowGifts
            bombLeft = challengeMode ? 0 : (freeBomb ? 1 : 0) + progress.adventure.bombGifts
            questPlay = saved.play
            attemptCounted = saved.hasStartedTry
            // A pre-objective checkpoint keeps its original clear-board win condition.
            puzzleGoal = saved.goal ?? PuzzleGoal()
            bankMatches = saved.bankMatches ?? 0; boosterShots = saved.boosterShots ?? 0
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
        decoratePuzzleBubbles()
        applyCompanionPins()
        updateControlLayout()
        saveCheckpoint()
        showPracticeHint()
        showObstacleIntroduction()
        if saved == nil { showLevelArrival() }
    }

    private func makeMenu(background: String) -> SKNode {
        saveCheckpoint()
        profiles.persistActive()
        levelMenu?.removeFromParent()
        gameRoot.childNode(withName: "puzzle-coach")?.removeFromParent()
        gameRoot.childNode(withName: "level-arrival")?.removeFromParent()
        gameRoot.childNode(withName: "target-feedback")?.removeFromParent()
        gameRoot.childNode(withName: "victory-confetti")?.removeFromParent()
        mapTouch = nil
        aiming = false
        aimGesture.cancel()
        aimTouch = nil
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        guide.removeAllChildren()
        gameRoot.isPaused = true
        gameRoot.removeAction(forKey: "control-help")
        view?.preferredFramesPerSecond = 30
        let overlay = SKNode()
        overlay.zPosition = 40
        addChild(overlay)
        levelMenu = overlay
        FestivalStyle.reveal(overlay)
        updateMusic()
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
        let secondary = name == "home" || name.contains("back") || name.hasSuffix("-close") ||
            ["buddy-later", "game-map", "game-restart", "settings", "players", "game-music"].contains(name)
        button.fillColor = secondary ? UIColor(red: 0.22, green: 0.42, blue: 0.46, alpha: 1) : FestivalStyle.coral
        FestivalStyle.finish(button, as: .lacquer)
        parent.addChild(button)
        label(title, size: min(23, (width - 28) / max(1, CGFloat(title.count) * 0.58)), point: CGPoint(x: 0, y: -8), parent: button)
        if let text = button.children.first as? SKLabelNode { fitLabel(text, width: width - 28) }
        let symbols = ["Explore Map": "map.fill", "Back to the map": "map.fill", "Back to the wheel": "gift.fill", "Spin": "sparkles", "Festival map": "map.fill", "Neighbors": "person.2.fill", "Prize Wheel": "gift.fill", "Pins": "star.circle.fill"]
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
        let logo = SKSpriteNode(imageNamed: "icon-shiba-source")
        logo.name = "title-brand-mark"; logo.size = CGSize(width: 112, height: 112)
        let frame = SKCropNode(); frame.position = CGPoint(x: 195, y: 718)
        let mask = SKShapeNode(rectOf: CGSize(width: 112, height: 112), cornerRadius: 24)
        mask.fillColor = .white; mask.strokeColor = .clear; frame.maskNode = mask
        frame.addChild(logo); overlay.addChild(frame)
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.name = "title-wordmark"; title.text = "Bubble Quest"; title.fontSize = 32
        title.attributedText = NSAttributedString(string: "Bubble Quest", attributes: [
            .font: UIFont(name: "AvenirNext-Bold", size: 32) ?? UIFont.boldSystemFont(ofSize: 32),
            .foregroundColor: FestivalStyle.ink, .strokeColor: FestivalStyle.cream, .strokeWidth: -3
        ])
        title.position = CGPoint(x: 195, y: 618); overlay.addChild(title)
        label("Festival Pop", size: 17, point: CGPoint(x: 195, y: 590), parent: overlay)
        (overlay.children.last as? SKLabelNode)?.fontColor = FestivalStyle.ink
        label("Start Menu", size: 26, point: CGPoint(x: 195, y: 553), parent: overlay)
        (overlay.children.last as? SKLabelNode)?.fontColor = FestivalStyle.ink
        panel(width: 342, height: 392, point: CGPoint(x: 195, y: 345), parent: overlay)
        let welcome = SKLabelNode(fontNamed: "AvenirNext-Bold")
        welcome.name = "welcome-player"; welcome.text = "Welcome, \(profiles.active.name)"
        welcome.fontSize = 18; welcome.numberOfLines = 2; welcome.preferredMaxLayoutWidth = 300
        welcome.lineBreakMode = .byCharWrapping; welcome.verticalAlignmentMode = .center
        welcome.position = CGPoint(x: 195, y: 498); overlay.addChild(welcome)
        navigationCard("Continue Playing", detail: progress.checkpoint == nil ? "Explore your courtyard map" : "Resume level \(progress.currentLevel + 1)", symbol: "play.fill", name: "start-continue", y: 385, parent: overlay, primary: true)
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
        announcedWelcomeArea = nil
        welcomedCompanion = nil
        saveCheckpoint()
        guard profiles.select(id) else { return }
        progress = profiles.makeProgress()
        hasStartedPuzzle = false
        challengeMode = false
        level = progress.currentLevel
        mapArea = level / LevelCatalog.levelsPerArea
        gameRoot.removeAllActions()
        if progress.checkpoint != nil { resumeSavedPuzzle() }
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

    private func showFestival() { mapArea = progress.currentLevel / LevelCatalog.levelsPerArea; showLevels(allowWelcome: true) }

    private func showSavedProgress(message: String? = nil) {
        menuKind = "saved-progress"
        let overlay = makeMenu(background: "festival-courtyard")
        panel(width: 342, height: 468, point: CGPoint(x: 195, y: 441), parent: overlay)
        label("Saved progress", size: 28, point: CGPoint(x: 195, y: 630), parent: overlay)
        paragraph("\(profiles.active.name)'s levels, stars, buddies, quests and prizes save separately on this iPhone.", y: 554, parent: overlay)
        label("\(progress.completedCount)/\(LevelCatalog.levelCount) stops • \(progress.totalStars)/\(LevelCatalog.maximumStars) stars", size: 19, point: CGPoint(x: 195, y: 468), parent: overlay)
        label(progress.checkpoint.map { "Puzzle \($0.level + 1) ready to resume" } ?? "No unfinished puzzle", size: 17, point: CGPoint(x: 195, y: 428), parent: overlay)
        let stamp = progress.lastSaved.map { DateFormatter.localizedString(from: $0, dateStyle: .short, timeStyle: .short) } ?? "Ready for your first adventure"
        label(stamp, size: 14, point: CGPoint(x: 195, y: 385), parent: overlay)
        if let message {
            let feedback = paragraph(message, y: 350, parent: overlay)
            feedback.name = "save-feedback"; feedback.fontSize = 12; feedback.fontColor = .systemYellow
        }
        menuButton("Save now", name: "save-now", point: CGPoint(x: 195, y: 306), parent: overlay, height: 50)
        label(profiles.active.fileName, size: 12, point: CGPoint(x: 195, y: 246), parent: overlay)
        if let fileName = overlay.children.last as? SKLabelNode { fitLabel(fileName, width: 306) }
        menuButton("Festival map", name: "festival-menu", point: CGPoint(x: 195, y: 136), parent: overlay, height: 50)
    }

    private func shouldWelcomeCourtyard(_ area: Int) -> Bool {
        area > 0 && LevelCatalog.areas.indices.contains(area) &&
            area <= progress.unlockedLevel / LevelCatalog.levelsPerArea &&
            !progress.hasWelcomedCourtyard(area) &&
            !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") })
    }

    private func showCourtyardWelcome(area: Int, action: String) {
        courtyardWelcomeArea = area
        courtyardWelcomeAction = action
        menuKind = "courtyard-welcome"
        let place = LevelCatalog.areas[area]
        let overlay = makeMenu(background: place.background)
        overlay.name = "courtyard-welcome"
        let title = panel(width: 348, height: 172, point: CGPoint(x: 195, y: 708), parent: overlay)
        title.name = "courtyard-welcome-introduction"
        title.strokeColor = .systemYellow
        if announcedWelcomeArea != area {
            announcedWelcomeArea = area
            audio.effect("map-chime", enabled: progress.enabled(.effects), volume: progress.effectsVolume * 0.5)
        }
        label("NEW AREA UNLOCKED", size: 12, point: CGPoint(x: 195, y: 771), parent: overlay)
        (overlay.children.last as? SKLabelNode)?.fontColor = .systemYellow
        label(place.name, size: 25, point: CGPoint(x: 195, y: 738), parent: overlay)
        overlay.children.last?.name = "courtyard-area-name"
        if let areaName = overlay.children.last as? SKLabelNode { fitLabel(areaName, width: 320) }
        let host = FestivalHost.all.first { $0.area == area }
        let neighbor = FestivalNeighbor.all.first { $0.area == area }
        let name = host?.name ?? neighbor?.name ?? "Your festival friends"
        let texture = host.map { atlasTexture("festival-hosts", index: $0.portraitIndex) }
            ?? neighbor.map { neighborTexture($0) }
        let divider = SKShapeNode(rectOf: CGSize(width: 268, height: 1))
        divider.name = "courtyard-introduction-divider"; divider.position = CGPoint(x: 195, y: 711)
        divider.fillColor = UIColor.white.withAlphaComponent(0.3); divider.strokeColor = .clear; overlay.addChild(divider)
        label("Meet \(name)", size: 24, point: CGPoint(x: 195, y: 675), parent: overlay)
        overlay.children.last?.name = "courtyard-resident-name"
        label(host?.role ?? neighbor?.role ?? "Your courtyard neighbor", size: 14, point: CGPoint(x: 195, y: 648), parent: overlay)
        if let role = overlay.children.last as? SKLabelNode {
            role.name = "courtyard-resident-role"; role.fontColor = UIColor(white: 0.92, alpha: 1)
            fitLabel(role, width: 310)
        }
        if let texture {
            // Bust artwork has a painted lower edge. Contain it inside a portrait
            // medallion rather than leaving that edge floating over the scenery.
            let frame = SKShapeNode(circleOfRadius: 116)
            frame.name = "courtyard-portrait-frame"; frame.position = CGPoint(x: 195, y: 478)
            frame.fillColor = UIColor(red: 1, green: 0.94, blue: 0.81, alpha: 1)
            frame.strokeColor = .systemYellow; frame.lineWidth = 3; overlay.addChild(frame)
            let crop = SKCropNode()
            let mask = SKShapeNode(circleOfRadius: 112)
            mask.fillColor = .white; mask.strokeColor = .clear; crop.maskNode = mask; frame.addChild(crop)
            let portrait = SKSpriteNode(texture: texture, size: CGSize(width: 232, height: 232))
            portrait.name = "courtyard-resident-portrait"; crop.addChild(portrait)
            if !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled {
                portrait.alpha = 0
                portrait.run(.fadeIn(withDuration: 0.3))
            }
        }
        addCourtyardRewardPreview(area: area, to: overlay)
        let continueTitle = action == "play" ? "Play level \(level + 1)" : action == "resume" ? "Resume level \(level + 1)" : "Explore Map"
        menuButton(continueTitle, name: "courtyard-welcome-explore", point: CGPoint(x: 195, y: 166), parent: overlay, width: 340, height: 54)
        menuButton("Start Menu", name: "courtyard-welcome-back", point: CGPoint(x: 195, y: 87), parent: overlay, width: 176, height: 44)
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        for index in 0..<(quiet ? 3 : 12) {
            let charm = questIcon(index % 2 == 0 ? "sparkles" : "star.fill", size: 15, color: index % 2 == 0 ? .systemYellow : .systemPink)
            charm.position = CGPoint(x: 34 + CGFloat(index) * (quiet ? 160 : 29), y: 598)
            overlay.addChild(charm)
            if !quiet {
                charm.run(.sequence([.group([.moveBy(x: 0, y: -75, duration: 1.2), .fadeOut(withDuration: 1.2)]), .removeFromParent()]))
            }
        }
    }

    private func addCourtyardRewardPreview(area: Int, to overlay: SKNode) {
        let rewards = Companion.all.filter { $0.unlockAfter == (area + 1) * LevelCatalog.levelsPerArea }
        let strip = panel(width: 344, height: 100, point: CGPoint(x: 195, y: 288), parent: overlay)
        strip.name = "courtyard-reward-preview"
        label(rewards.isEmpty ? "Area keepsake" : "Characters you can unlock", size: 13, point: CGPoint(x: 0, y: 29), parent: strip)
        strip.children.last?.name = "courtyard-reward-heading"
        if rewards.isEmpty {
            let style = FestivalCelebration.forArea(area)
            let icon = questIcon(style.symbol, size: 28, color: .systemYellow)
            icon.position = CGPoint(x: -143, y: -5); strip.addChild(icon)
            label("Clear all 20 levels: " + style.souvenir, size: 12, point: CGPoint(x: 14, y: -5), parent: strip)
            if let words = strip.children.last as? SKLabelNode { fitLabel(words, width: 280) }
        } else {
            for (index, reward) in rewards.prefix(2).enumerated() {
                let x = rewards.count == 1 ? CGFloat(0) : CGFloat(index == 0 ? -83 : 83)
                let portrait = SKSpriteNode(texture: companionTexture(reward, frame: 0), size: CGSize(width: 37, height: 37))
                portrait.position = CGPoint(x: x - 55, y: -3); strip.addChild(portrait)
                label(reward.name + (reward.kind == .animal ? " • Buddy" : " • Shooter"), size: 11, point: CGPoint(x: x + 17, y: 7), parent: strip)
                if let words = strip.children.last as? SKLabelNode { fitLabel(words, width: 108) }
                label(progress.unlockLevelProgress(reward), size: 9, point: CGPoint(x: x + 17, y: -9), parent: strip)
                if let requirementText = progress.unlockQuestProgress(reward) {
                    label(requirementText, size: 9, point: CGPoint(x: x + 17, y: -23), parent: strip)
                    if let requirement = strip.children.last as? SKLabelNode { fitLabel(requirement, width: 108) }
                }
                let preview = SKShapeNode(rectOf: CGSize(width: 164, height: 59), cornerRadius: 8)
                preview.name = "preview-companion-" + reward.id; preview.position = CGPoint(x: x, y: -3)
                preview.fillColor = .clear; preview.strokeColor = .clear; strip.addChild(preview)
            }
        }
        label("20 new levels • Side quests are optional", size: 10, point: CGPoint(x: 0, y: -42), parent: strip)
    }

    private func showLevels(allowWelcome: Bool = false) {
        if allowWelcome && shouldWelcomeCourtyard(mapArea) { showCourtyardWelcome(area: mapArea, action: "map"); return }
        menuKind = "map"
        let unlockedArea = progress.unlockedLevel / LevelCatalog.levelsPerArea
        mapArea = min(LevelCatalog.areas.count - 1, max(0, min(mapArea, unlockedArea + 1)))
        let mystery = mapArea > unlockedArea
        let area = LevelCatalog.areas[mapArea]
        let scenery = mystery ? nil : SummerScenery.forArea(mapArea)
        let overlay = makeMenu(background: mystery ? "festival-day" : scenery?.mapArtwork ?? (!area.nightTint && mapArea % 5 < 2 ? "festival-map-day" : "festival-map"))
        if let scenery, let art = overlay.children.first as? SKSpriteNode {
            art.texture = SKTexture(rect: scenery.mapRegion, in: SKTexture(imageNamed: scenery.mapArtwork))
        }
        let areaHeader = panel(width: 358, height: 116, point: CGPoint(x: 195, y: 736), parent: overlay)
        areaHeader.name = "map-area-header"
        label(mystery ? "Mystery Courtyard" : area.name, size: 23, point: CGPoint(x: 195, y: 766), parent: overlay)
        if let heading = overlay.children.last as? SKLabelNode { fitLabel(heading, width: 326) }
        let first = mapArea * LevelCatalog.levelsPerArea
        let cleared = (first..<first + LevelCatalog.levelsPerArea).filter { progress.stars($0) > 0 }.count
        label("Area \(mapArea + 1)/\(LevelCatalog.areas.count) • \(cleared)/\(LevelCatalog.levelsPerArea) levels cleared", size: 12, point: CGPoint(x: 195, y: 742), parent: overlay)
        menuButton(mapArea > 0 ? "← Previous" : "First area", name: mapArea > 0 ? "area-prev" : "area-unavailable", point: CGPoint(x: 99, y: 706), parent: overlay, width: 154, height: 44)
        if let button = overlay.childNode(withName: mapArea > 0 ? "area-prev" : "area-unavailable") as? SKShapeNode { button.fillColor = .systemTeal; button.strokeColor = .white }
        if mapArea < LevelCatalog.areas.count - 1 && !mystery {
            menuButton(mapArea >= unlockedArea ? "Mystery →" : "Next area →", name: "area-next", point: CGPoint(x: 291, y: 706), parent: overlay, width: 154, height: 44)
        }
        if mystery {
            let surprise = panel(width: 310, height: 340, point: CGPoint(x: 195, y: 458), parent: overlay)
            surprise.addChild(questIcon("lock.fill", size: 70, color: .systemYellow))
            label("A new place is waiting", size: 22, point: CGPoint(x: 195, y: 565), parent: overlay)
            label("Clear level \(first) to discover it", size: 18, point: CGPoint(x: 195, y: 355), parent: overlay)
        } else {
            let crop = SKCropNode(); crop.name = "map-viewport"
            let mask = SKShapeNode(rect: FestivalMapLayout.viewport)
            mask.fillColor = .white; mask.strokeColor = .clear; crop.maskNode = mask; overlay.addChild(crop)
            let route = SKNode(); route.name = "map-route"; crop.addChild(route)
            let positions = (0..<LevelCatalog.levelsPerArea).map(FestivalMapLayout.position)
            let path = CGMutablePath(); path.move(to: positions[0])
            for pair in zip(positions, positions.dropFirst()) {
                path.addCurve(to: pair.1, control1: CGPoint(x: pair.0.x, y: pair.0.y + 33), control2: CGPoint(x: pair.1.x, y: pair.1.y - 33))
            }
            let edge = SKShapeNode(path: path); edge.strokeColor = .brown.withAlphaComponent(0.65)
            edge.lineWidth = 20; edge.lineCap = .round; route.addChild(edge)
            let road = SKShapeNode(path: path); road.strokeColor = UIColor(red: 1, green: 0.89, blue: 0.62, alpha: 0.95)
            let roadColors: [UIColor] = [.init(red: 1, green: 0.89, blue: 0.62, alpha: 1), .init(red: 0.83, green: 0.94, blue: 0.72, alpha: 1), .init(red: 1, green: 0.79, blue: 0.63, alpha: 1)]
            road.strokeColor = roadColors[mapArea % roadColors.count]
            road.lineWidth = 13; road.lineCap = .round; route.addChild(road)
            for (x, y) in [(CGFloat(34), CGFloat(610)), (CGFloat(356), CGFloat(408))] {
                let decoration = questIcon(FestivalCelebration.forArea(mapArea).symbol, size: 22, color: .systemYellow)
                decoration.name = "map-area-decoration"; decoration.position = CGPoint(x: x, y: y); overlay.addChild(decoration)
            }
            for (local, point) in positions.enumerated() {
                let index = first + local
                let current = index == progress.unlockedLevel
                let stop = SKShapeNode(circleOfRadius: current ? 26 : 21)
                stop.position = point; stop.name = index <= progress.unlockedLevel ? "level-\(index)" : "locked"
                stop.fillColor = current ? .systemPink : progress.stars(index) > 0 ? .systemOrange : .systemGray
                stop.strokeColor = current ? .systemYellow : .white; stop.lineWidth = current ? 4 : 2
                stop.zPosition = current ? 3 : 1; route.addChild(stop)
                label("\(index + 1)", size: current ? 22 : 17, point: CGPoint(x: 0, y: -6), parent: stop)
                if index <= progress.unlockedLevel, LevelCatalog.level(index).objective != .clear {
                    let badge = SKShapeNode(circleOfRadius: 10)
                    badge.name = "map-objective-\(index)"; badge.fillColor = .white; badge.strokeColor = .systemOrange; badge.lineWidth = 1.5
                    badge.position = CGPoint(x: current ? 18 : 15, y: current ? 20 : 17); badge.zPosition = 4
                    badge.addChild(questIcon(LevelCatalog.level(index).objective.symbol, size: 12, color: .systemOrange)); stop.addChild(badge)
                }
                if current {
                    let avatar = SKSpriteNode(texture: companionTexture(progress.selected(.human), frame: 0), size: CGSize(width: 42, height: 42))
                    let side: CGFloat = point.x < 110 ? 1 : -1
                    avatar.position.x = side * 52; stop.addChild(avatar)
                    let tries = SKLabelNode(fontNamed: "AvenirNext-Bold")
                    tries.name = "map-tries"; tries.text = "♥ \(progress.lives(for: index).available)"
                    tries.fontSize = 11; tries.fontColor = .white; tries.position = CGPoint(x: -side * 48, y: -4); stop.addChild(tries)
                }
            }
            scrollMap(to: FestivalMapLayout.focusedOffset(local: progress.unlockedLevel - first))
            label("Swipe the path to see all 20 levels", size: 11, point: CGPoint(x: 195, y: 334), parent: overlay)
            overlay.children.last?.name = "map-scroll-hint"
            addCourtyardResident(to: overlay)
            let activities = panel(width: 358, height: 66, point: CGPoint(x: 195, y: 164), parent: overlay)
            activities.name = "map-activities"
            for (title, name, x, symbol) in [("Team", "friends", CGFloat(-117), "person.2.fill"), ("Album", "album-open", CGFloat(0), "book.closed.fill"), ("Prizes", "open-wheel", CGFloat(117), "gift.fill")] {
                menuButton(title, name: name, point: CGPoint(x: x, y: 0), parent: activities, width: 104, height: 44)
                guard let button = activities.childNode(withName: name) else { continue }
                if let words = button.children.first as? SKLabelNode {
                    words.fontSize = 16; words.position = CGPoint(x: 12, y: -6)
                    fitLabel(words, width: 65)
                }
                let icon = questIcon(symbol, size: 17, color: name == "open-wheel" ? .systemYellow : .white)
                icon.name = "map-activity-icon"; icon.position = CGPoint(x: -33, y: 0); button.addChild(icon)
                if name == "open-wheel", progress.adventure.availableSpins > 0 {
                    let badge = SKShapeNode(circleOfRadius: 9); badge.fillColor = .systemYellow; badge.strokeColor = .white
                    badge.name = "map-prize-count"; badge.position = CGPoint(x: 38, y: 15); button.addChild(badge)
                    label("\(progress.adventure.availableSpins)", size: 10, point: CGPoint(x: 0, y: -4), parent: badge)
                }
            }
            let rewards = Companion.all.filter { $0.unlockAfter == (mapArea + 1) * LevelCatalog.levelsPerArea }
            let preview = rewards.isEmpty ? "Area reward: " + FestivalCelebration.forArea(mapArea).souvenir : "Area rewards: " + rewards.map { $0.name + ($0.unlockQuest == nil ? "" : " (side quest)") }.joined(separator: " + ")
            label(preview, size: 10, point: CGPoint(x: 195, y: 112), parent: overlay)
            if let words = overlay.children.last as? SKLabelNode { words.name = "map-reward-preview"; fitLabel(words, width: 352) }
            if let saved = progress.checkpoint {
                menuButton("Resume \(saved.level + 1)", name: "map-resume", point: CGPoint(x: 99, y: 65), parent: overlay, width: 166, height: 44)
            }
        }
        menuButton("Start Menu", name: "home", point: CGPoint(x: progress.checkpoint != nil && !mystery ? 291 : 195, y: 65), parent: overlay, width: 166, height: 44)
    }

    func scrollMap(to offset: CGFloat) {
        guard let route = levelMenu?.childNode(withName: "//map-route") else { return }
        route.position.y = FestivalMapLayout.scrollOffset(offset)
        // Keep complete markers visible at the scroll edges; clipped numbers can
        // otherwise look like they belong underneath the area navigation.
        for stop in route.children where stop.name == "locked" || stop.name?.hasPrefix("level-") == true {
            let centerY = stop.position.y + route.position.y
            stop.isHidden = centerY - 32 < FestivalMapLayout.viewport.minY || centerY + 32 > FestivalMapLayout.viewport.maxY
        }
        levelMenu?.childNode(withName: "map-current-level")?.removeFromParent()
        let local = progress.unlockedLevel - mapArea * LevelCatalog.levelsPerArea
        if (0..<LevelCatalog.levelsPerArea).contains(local),
           let current = route.childNode(withName: "level-\(progress.unlockedLevel)"), current.isHidden,
           let overlay = levelMenu {
            menuButton("Current level", name: "map-current-level", point: CGPoint(x: 195, y: 379), parent: overlay, width: 170, height: 44)
            overlay.childNode(withName: "map-current-level")?.zPosition = 8
        }
    }

    private func addCourtyardResident(to overlay: SKNode) {
        let card = panel(width: 358, height: 104, point: CGPoint(x: 195, y: 267), parent: overlay)
        card.name = "courtyard-resident"
        let name: String
        let portrait: SKTexture
        if let host = FestivalHost.all.first(where: { $0.area == mapArea }) {
            name = host.name; portrait = atlasTexture("festival-hosts", index: host.portraitIndex)
        } else if let neighbor = FestivalNeighbor.all.first(where: { $0.area == mapArea }) {
            name = neighbor.name; portrait = neighborTexture(neighbor)
        } else { return }
        let avatar = SKSpriteNode(texture: portrait, size: CGSize(width: 62, height: 62))
        avatar.name = "courtyard-greeting"; avatar.position = CGPoint(x: -132, y: 9); card.addChild(avatar)
        label(name, size: 15, point: CGPoint(x: -132, y: -39), parent: card)
        let quests = FestivalQuest.all.filter { $0.area == mapArea && progress.adventure.available($0, unlockedLevel: progress.unlockedLevel) }
        let introduction = progress.adventure.takeMapIntroduction(unlockedLevel: progress.unlockedLevel, area: mapArea)
        if quests.isEmpty {
            label(mapArea == 0 && progress.unlockedLevel < 3 ? "Side quests after level 3" : "Your courtyard neighbor", size: 13, point: CGPoint(x: 44, y: 16), parent: card)
            menuButton("Say hello", name: "courtyard-greeting", point: CGPoint(x: 44, y: -17), parent: card, width: 206, height: 44)
        }
        for (index, quest) in quests.prefix(2).enumerated() {
            let button = panel(width: 214, height: 44, point: CGPoint(x: 49, y: 25 - CGFloat(index) * 50), parent: card)
            button.name = "quest-" + quest.id
            if introduction?.id == quest.id { button.strokeColor = .systemYellow; button.lineWidth = 3 }
            let complete = progress.adventure.completed(quest)
            label(quest.title, size: 13, point: CGPoint(x: complete ? 10 : 0, y: 3), parent: button)
            if let title = button.children.last as? SKLabelNode {
                title.name = "map-quest-title"; fitLabel(title, width: complete ? 170 : 194)
            }
            label(complete ? "Complete • view reward" : progress.adventure.accepted(quest) ? "Side quest • \(progress.adventure.count(quest))/\(quest.steps.count)" : "Optional side quest", size: 10, point: CGPoint(x: 0, y: -14), parent: button)
            if progress.adventure.completed(quest) {
                let reward = questIcon(quest.symbol, size: 16, color: [.systemPink, .systemYellow, .systemTeal][progress.adventure.style(quest)])
                reward.name = "quest-display-" + quest.id; reward.position = CGPoint(x: -94, y: 3); button.addChild(reward)
            }
        }
    }

    private func addMapDiscoveries(to overlay: SKNode) {
        let chime = SKShapeNode(circleOfRadius: 25)
        chime.fillColor = .clear; chime.strokeColor = .clear
        chime.name = "map-chime"; chime.position = CGPoint(x: 360, y: 665)
        chime.addChild(questIcon("bell.fill", size: 23, color: .systemYellow))
        overlay.addChild(chime)
        let buddy = SKSpriteNode(texture: companionTexture(progress.selected(.animal), frame: 0), size: CGSize(width: 48, height: 48))
        buddy.name = "map-buddy-hello"; buddy.position = CGPoint(x: 340, y: 240)
        overlay.addChild(buddy)
        // A familiar unlocked neighbor occasionally visits; no timer or reward to chase.
        if progress.completedCount >= 10 && (progress.completedCount + mapArea) % 7 == 0,
           let visitor = FestivalNeighbor.all.first(where: { progress.neighborIsAvailable($0) }) {
            let portrait = SKSpriteNode(texture: neighborTexture(visitor), size: CGSize(width: 52, height: 52))
            portrait.name = "map-visitor"; portrait.position = CGPoint(x: 340, y: 310)
            overlay.addChild(portrait)
        }
    }

    private func handleMapDiscovery(names: [String], location: CGPoint) -> Bool {
        let target = names.first { ["map-chime", "map-buddy-hello", "map-visitor"].contains($0) }
        // Only empty scenery responds to water taps, leaving every map control first priority.
        let water = target == nil && names.isEmpty && location.x > 305 && location.y > 350 && location.y < 550 && (SummerScenery.forArea(mapArea).map { [SummerScenery.river, .beach, .lake].contains($0) } ?? false)
        guard target != nil || water else { return false }
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastMapInteraction > 1.1, let overlay = levelMenu else { return true }
        lastMapInteraction = now
        overlay.childNode(withName: "map-discovery-feedback")?.removeFromParent()
        let feedback = SKNode(); feedback.name = "map-discovery-feedback"; overlay.addChild(feedback)
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        let cue = water ? "map-water" : target == "map-chime" ? "map-chime" : "buddy-hello"
        audio.effect(cue, enabled: progress.enabled(.effects), volume: progress.effectsVolume)
        if water {
            for index in 0..<3 {
                let ring = SKShapeNode(ellipseOf: CGSize(width: CGFloat(15 + index * 12), height: CGFloat(6 + index * 5)))
                ring.position = location; ring.strokeColor = .white.withAlphaComponent(0.75); ring.lineWidth = 1.5
                feedback.addChild(ring)
                if !quiet { ring.run(.scale(to: 1.5, duration: 0.7)) }
            }
        } else {
            let text = target == "map-visitor" ? "Lovely to see you here!" : target == "map-chime" ? "A little summer breeze" : "Happy to be here!"
            label(text, size: 14, point: CGPoint(x: 260, y: target == "map-chime" ? 635 : 337), parent: feedback)
            if let node = overlay.childNode(withName: target ?? ""), !quiet {
                node.run(.sequence([.rotate(toAngle: -0.08, duration: 0.1), .rotate(toAngle: 0.08, duration: 0.16), .rotate(toAngle: 0, duration: 0.1)]))
            }
        }
        feedback.run(.sequence([.wait(forDuration: 1.0), .fadeOut(withDuration: 0.3), .removeFromParent()]))
        return true
    }

    private func availableColor() -> Int {
        var random = SystemRandomNumberGenerator()
        return BubbleColorQueue.draw(board: board, bag: &colorBag, using: &random)
    }

    private func reload(animateLoading: Bool = false) {
        loaded?.removeFromParent()
        nextNode?.removeFromParent()
        let node = shotNode(armed ?? .color(currentColor))
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        node.position = animateLoading && !quiet ? CGPoint(x: 113, y: 151) : origin
        node.zPosition = animateLoading && !quiet ? 5 : 1
        gameRoot.addChild(node)
        loaded = node
        if animateLoading {
            loadingBubble = true
            audio.effect("load", enabled: progress.enabled(.effects), volume: progress.effectsVolume)
            animateCompanion(.animal, frames: BuddyPersonality.loadingFrames(id: progress.selected(.animal).id))
            let toss = CGMutablePath()
            toss.move(to: CGPoint(x: 113, y: 151))
            toss.addQuadCurve(to: origin, control: CGPoint(x: 152, y: 244))
            let transfer: SKAction = quiet ? .wait(forDuration: 0.08) : .sequence([
                .wait(forDuration: 0.16), .follow(toss, asOffset: false, orientToPath: false, duration: 0.4)
            ])
            node.run(.sequence([transfer, .run { [weak self, weak node] in
                node?.zPosition = 1
                self?.nextNode?.isHidden = false
                self?.loadingBubble = false
            }]), withKey: "buddy-toss")
        }
        let next = bubble(nextColor)
        next.name = "swap-bubble"
        next.setScale(0.85)
        let queueRing = SKShapeNode(circleOfRadius: 25)
        queueRing.fillColor = UIColor.white.withAlphaComponent(0.85); queueRing.strokeColor = .systemYellow
        queueRing.lineWidth = 2; queueRing.zPosition = -1; next.addChild(queueRing)
        next.position = CGPoint(x: 113, y: 151)
        next.isHidden = animateLoading && !quiet
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
            box?.strokeColor = selected ? .systemYellow : .clear
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
        animateCompanion(.human, frames: [1, 2])
        guide.removeAllChildren()
        guard progress.enabled(.guide) else { return }
        gameRoot.childNode(withName: "character-reaction")?.removeFromParent()
        gameRoot.childNode(withName: "drop-feedback")?.removeFromParent()
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
            let removed = result.matched.union(result.dropped)
            let rescuedCount = puzzleGoal.remaining.intersection(removed).count
            let text = rescuedCount > 0 ? "Free \(rescuedCount) \(rescuedCount == 1 ? "objective" : "objectives")" : removed.isEmpty ? "Attach here" : "Clear \(removed.count) bubbles"
            let outcome = SKShapeNode(rectOf: CGSize(width: 190, height: 27), cornerRadius: 13)
            outcome.name = "aim-outcome"; outcome.position = CGPoint(x: 195, y: 345)
            outcome.fillColor = UIColor(white: 0.12, alpha: 0.82); outcome.strokeColor = .white
            feedbackText(text, size: 12, at: .zero, parent: outcome, color: .white)
            guide.addChild(outcome)
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
        if levelMenu != nil {
            if menuKind == "map", !names.contains("map-current-level"), FestivalMapLayout.viewport.contains(location),
               let route = levelMenu?.childNode(withName: "//map-route") {
                mapTouch = touch; mapTouchStart = location; mapTouchOffset = route.position.y; mapDragged = false
                return
            }
            if menuKind == "map", handleMapDiscovery(names: names, location: location) { return }
            handleMenu(names); return
        }
        if let control = names.first(where: { ["rainbow", "bomb"].contains($0) }) {
            gameRoot.run(.sequence([.wait(forDuration: 0.55), .run { [weak self] in self?.showControlHelp(control) }]), withKey: "control-help")
        }
        if names.contains("game-menu") { showGameMenu(); return }
        if names.contains("quest-objective") { showObjectives(); return }

        if finished {
            if !names.contains("result-next") { dismissCelebrationEffects(); return }
            guard names.contains("result-next") else { return }
            continueAfterResult()
            return
        }
        guard projectile == nil, !loadingBubble, !ceilingMoving else { return }
        if names.contains("rainbow") && rainbowLeft > 0 { armed = armed == .rainbow ? nil : .rainbow; reload(); refreshHUD(); return }
        if names.contains("bomb") && bombLeft > 0 { armed = armed == .bomb ? nil : .bomb; reload(); refreshHUD(); return }
        if names.contains("swap-bubble") { armed = nil; swap(&currentColor, &nextColor); reload(); refreshHUD(); return }
        guard location.y > 350 && location.y < 710 else { return }
        aiming = true
        acknowledgeObstacleTip()
        gameRoot.childNode(withName: "control-tip")?.removeFromParent()
        aimTouch = touch
        aimGesture.begin(at: BubblePoint(x: Double(location.x), y: Double(location.y)))
        updateAim(location)
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        if let touch = mapTouch, touches.contains(touch), menuKind == "map" {
            let point = touch.location(in: self)
            if hypot(point.x - mapTouchStart.x, point.y - mapTouchStart.y) > 10 { mapDragged = true }
            if mapDragged { scrollMap(to: mapTouchOffset + point.y - mapTouchStart.y) }
            return
        }
        guard aiming, let touch = aimTouch, touches.contains(touch) else { return }
        updateAim(touch.location(in: self))
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        mapTouch = nil
        gameRoot.removeAction(forKey: "control-help")
        guard let touch = aimTouch, touches.contains(touch) else { return }
        aiming = false
        aimGesture.cancel()
        aimTouch = nil
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        guide.removeAllChildren()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        gameRoot.removeAction(forKey: "control-help")
        if let touch = mapTouch, touches.contains(touch) {
            mapTouch = nil
            let location = touch.location(in: self)
            if !mapDragged, menuKind == "map", FestivalMapLayout.viewport.contains(location) { handleMenu(interactionNames(at: location)) }
            return
        }
        guard aiming, let touch = aimTouch, touches.contains(touch), !finished, projectile == nil, !loadingBubble, levelMenu == nil else { return }
        aimTouch = nil
        aiming = false
        guide.removeAllChildren()
        gameRoot.childNode(withName: "cancel-cue")?.isHidden = true
        let lift = touch.location(in: self)
        guard let angle = aimGesture.end(at: BubblePoint(x: Double(lift.x), y: Double(lift.y))) else { return }
        launchShot(angle: angle)
    }

    internal func continueAfterResult(showBuddy: Bool = true) {
        guard finished else { return }
        dismissCelebrationEffects()
        // The result button promises the quest reward before any separate unlock notice.
        if let completedQuest { showQuest(completedQuest); return }
        if won && showBuddy, let buddy = progress.pendingBuddy { showBuddyWelcome(buddy); return }
        if challengeMode && won { challengeMode = false; mapArea = level / LevelCatalog.levelsPerArea; showLevels(); return }
        if won && level == LevelCatalog.levelCount - 1 { showEnding(); return }
        if won { level += 1 }
        beginSelectedLevel()
    }

    internal func launchShot(angle: Double) {
        guard hasStartedPuzzle, !suspended, angle.isFinite, abs(angle) <= BubbleGeometry.maxAngle, !finished, projectile == nil, !loadingBubble, !ceilingMoving, levelMenu == nil, let shot = loaded else { return }
        if !attemptCounted && !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) {
            guard progress.takeTry(for: level, challenge: challengeMode) else { showLives(); return }
            if !challengeMode { progress.recordAttempt(level) }
            attemptCounted = true
            profiles.persistActive()
        }
        acknowledgeObstacleTip()
        acknowledgePuzzleCoach()
        for name in ["level-arrival", "target-feedback", "character-reaction", "drop-feedback"] {
            gameRoot.childNode(withName: name)?.removeFromParent()
        }
        let kind = armed ?? .color(currentColor)
        let flight = BubbleGeometry.flight(angle: angle, board: board, ceilingOffset: ceilingOffset)
        shotsFired += 1
        shotBankCount = BubbleGeometry.bouncePoints(flight).count
        questPlay.bounces += shotBankCount
        if kind == .rainbow || kind == .bomb { boosterShots += 1 }
        projectile = shot
        pendingFlight = (flight.landing, kind)
        shot.name = "flying-bubble"
        loaded = nil
        if kind == .rainbow { if freeRainbow { freeRainbow = false } else { pendingGift = .rainbow }; rainbowLeft -= 1 }
        if kind == .bomb { if freeBomb { freeBomb = false } else { pendingGift = .bomb }; bombLeft -= 1 }
        armed = nil
        shots -= 1
        cannonFeedback()
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
        let oldArmor = board.armor
        let result = board.place(kind, at: cell)
        let rescued = puzzleGoal.remaining.intersection(result.matched.union(result.dropped))
        let completingObjective = !puzzleGoal.remaining.isEmpty && rescued == puzzleGoal.remaining
        for (index, target) in rescued.sorted(by: { $0.row == $1.row ? $0.column < $1.column : $0.row < $1.row }).prefix(8).enumerated() {
            rescueEffect(at: point(target), order: index, completing: completingObjective)
        }
        puzzleGoal.collect(result.matched.union(result.dropped))
        if !rescued.isEmpty && !puzzleGoal.completed(on: board) { showTargetFeedback() }
        for cracked in oldArmor.subtracting(board.armor) where board.bubbles[cracked] != nil {
            nodes[cracked]?.childNode(withName: "puzzle-armor")?.removeFromParent()
            armorCrackEffect(at: point(cracked))
        }
        let bankBonus = PuzzleRewards.bankBonus(bounces: shotBankCount, removed: result.matched.count + result.dropped.count)
        if bankBonus > 0 { bankMatches += 1; score += bankBonus }
        questPlay.collected.formUnion(result.matched.union(result.dropped).compactMap { questMarkers[$0] })
        if level == 0 && !result.matched.isEmpty {
            progress.practiceDone = true; gameRoot.childNode(withName: "practice-caption")?.removeFromParent()
        }
        questPlay.dropped += result.dropped.count
        questPlay.colors.formUnion(result.matched.union(result.dropped).compactMap { oldColors[$0] })
        let refunds = result.matched.filter { oldSpecials[$0] == .riverPearl }.count
        shots = min(attemptShotBudget, shots + refunds)
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
        if !result.dropped.isEmpty && rescued.isEmpty {
            let cheers = SKLabelNode(fontNamed: "AvenirNext-Bold")
            cheers.name = "drop-feedback"
            cheers.text = "Nice drop! +\(result.dropped.count * 20)"
            cheers.fontSize = 23
            cheers.fontColor = .systemYellow
            cheers.position = CGPoint(x: 195, y: 345)
            cheers.zPosition = 12
            gameRoot.addChild(cheers)
            let drift = quiet ? SKAction.wait(forDuration: 0.9) : .moveBy(x: 0, y: 35, duration: 0.9)
            cheers.run(.sequence([.group([drift, .sequence([.wait(forDuration: 0.55), .fadeOut(withDuration: 0.35)])]), .removeFromParent()]))
        }
        // One short message per shot keeps rescues, drops and buddy reactions legible.
        if result.dropped.isEmpty && rescued.isEmpty {
            if bankBonus > 0 { characterReaction(BuddyPersonality.cheer(id: progress.selected(.animal).id, event: .bank), quiet: quiet) }
            else if !warnedLowBoard && (shots <= 5 || board.bubbles.keys.contains(where: { point($0).y < 425 })) {
                warnedLowBoard = true
                characterReaction(BuddyPersonality.cheer(id: progress.selected(.animal).id, event: .low), quiet: quiet)
            }
        }
        if !result.matched.isEmpty {
            for index in 0..<(quiet ? 0 : 1) {
                gameRoot.childNode(withName: "companion-\(index)")?.run(.sequence([.moveBy(x: 0, y: 7, duration: 0.12), .moveBy(x: 0, y: -7, duration: 0.12)]))
            }
            if progress.enabled(.vibration) { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        }
        let cracked = !oldArmor.subtracting(board.armor).isEmpty
        let cue = !rescued.isEmpty ? "rescue" : result.dropped.count >= 5 ? "big-drop" : cracked ? "armor-crack" : kind == .bomb ? "bomb" : !result.matched.isEmpty ? "pop" : "stick"
        audio.effect(cue, enabled: progress.enabled(.effects), volume: progress.effectsVolume)
        if result.matched.isEmpty && result.dropped.isEmpty && !cracked {
            stickFeedback(on: shot, quiet: quiet)
        }
        if puzzleGoal.completed(on: board) { finish(success: true); return }
        let newOffset = min(240, activeLevel.ceilingOffset(after: shotsFired, seed: pressureSeed, balanceVersion: pressureBalanceVersion) + Double(timedPressure.drops) * activeLevel.timedCeilingStep)
        if newOffset > ceilingOffset {
            ceilingOffset = newOffset
            positionCeiling(animated: true)
        }
        if shots <= 0 || board.bubbles.keys.contains(where: { point($0).y < CGFloat(BubbleGeometry.lossLine) }) { finish(success: false); return }
        currentColor = board.playableColors.contains(nextColor) ? nextColor : availableColor()
        nextColor = availableColor()
        reload(animateLoading: true)
        refreshHUD()
        saveCheckpoint()
    }

    private func finish(success: Bool) {
        guard !finished else { return }
        let previousBest = progress.bestScore(level)
        residentMilestone = nil
        if success && !challengeMode && progress.stars(level) == 0, let stop = activeLevel.residentMilestone {
            let area = level / LevelCatalog.levelsPerArea
            let name = FestivalHost.all.first { $0.area == area }?.name ?? FestivalNeighbor.all.first { $0.area == area }?.name ?? "Your neighbor"
            let cheer = stop == 20 ? "A whole courtyard of wonderful popping!" : "\(stop) levels cleared! The festival is coming alive!"
            residentMilestone = "\(name): \(cheer)"
        }
        let previousArea = progress.unlockedLevel / LevelCatalog.levelsPerArea
        let hadSouvenir = progress.hasSouvenir(area: level / LevelCatalog.levelsPerArea)
        for name in ["level-arrival", "target-feedback", "control-tip", "puzzle-coach"] { gameRoot.childNode(withName: name)?.removeFromParent() }
        progress.clearCheckpoint()
        if !challengeMode && !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) {
            progress.recordOutcome(index: level, won: success, shotsRemaining: shots, shotsFired: shotsFired, bankMatches: bankMatches, boosterShots: boosterShots)
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
            if !challengeMode && !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) {
                earnedMedals = progress.recordCollection(level: level, stars: PuzzleRating.stars(shotsRemaining: shots, budget: attemptShotBudget), boosters: boosterShots, banks: bankMatches)
            }
            if challengeMode && PuzzleRating.stars(shotsRemaining: shots, budget: attemptShotBudget) == PuzzleRating.maximumStars { progress.recordChallenge(level / LevelCatalog.levelsPerArea) }
            score += shots * 25
            status.text = level % 3 == 0 && FestivalHost.all.indices.contains(level / LevelCatalog.levelsPerArea) ? FestivalHost.all[level / LevelCatalog.levelsPerArea].encouragement : "Beautiful popping!"
            let unlocked = challengeMode ? [] : progress.recordVictory(index: level, score: score,
                                                   stars: PuzzleRating.stars(shotsRemaining: shots, budget: attemptShotBudget))
            earnedCourtyardSouvenir = !challengeMode && !hadSouvenir && progress.hasSouvenir(area: level / LevelCatalog.levelsPerArea)
            if !challengeMode, progress.unlockedLevel / LevelCatalog.levelsPerArea > previousArea { revealedArea = progress.unlockedLevel / LevelCatalog.levelsPerArea }
            let newQuests = challengeMode ? [] : progress.adventure.recordWin(level: level, play: questPlay, completedLevels: progress.completedCount)
            completedQuest = newQuests.first
            if let completedQuest { status.text = "Side quest complete: \(completedQuest.title)" }
            else if !challengeMode, let quest = FestivalQuest.all.first(where: {
                $0.area == level / LevelCatalog.levelsPerArea && progress.adventure.accepted($0) && !progress.adventure.completed($0)
            }) {
                status.text = "\(quest.title): \(progress.adventure.count(quest))/\(quest.steps.count)"
            }
            if !unlocked.isEmpty && completedQuest == nil { status.text = "New team member: \(unlocked.map { $0.name }.joined(separator: ", "))" }
            if progress.enabled(.vibration) { UINotificationFeedbackGenerator().notificationOccurred(.success) }
            audio.effect(activeLevel.isMilestone ? "milestone" : "victory", enabled: progress.enabled(.effects), volume: progress.effectsVolume)
            if activeLevel.isMilestone { celebrateArea() }
            for index in 0..<(UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled ? 0 : 1) {
                gameRoot.childNode(withName: "companion-\(index)")?.run(.repeat(.sequence([.moveBy(x: 0, y: 10, duration: 0.15), .moveBy(x: 0, y: -10, duration: 0.15)]), count: 3))
            }
        } else {
            for index in 0..<(UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled ? 0 : 1) {
                gameRoot.childNode(withName: "companion-\(index)")?.run(.sequence([.rotate(byAngle: 0.08, duration: 0.15), .rotate(byAngle: -0.08, duration: 0.15)]))
            }
        }
        showPuzzleResult(success: success, newBest: success && !challengeMode && score > previousBest)
        shotsLabel.text = "\(shots)"
        refreshQuestBadge()
        profiles.persistActive()
    }
}

private extension FestivalScene {
    internal func interactionNames(at location: CGPoint) -> [String] {
        let parent = levelMenu ?? gameRoot
        let point = convert(location, to: parent)
        let hits = parent.nodes(at: point)
        let names = hits.flatMap { node -> [String] in
            if menuKind == "map", !FestivalMapLayout.viewport.contains(point) {
                var ancestor: SKNode? = node
                while let value = ancestor {
                    if value.name == "map-route" { return [] }
                    ancestor = value.parent
                }
            }
            var result: [String] = []; var current: SKNode? = node
            while let value = current { if let name = value.name { result.append(name) }; current = value.parent }
            return result
        }
        // Keep controls at least 44 physical points tall on compact iPhones.
        let scale = min((view?.bounds.width ?? size.width) / size.width, (view?.bounds.height ?? size.height) / size.height)
        let minimum = 44 / max(0.1, scale)
        // The goal bar is decorative behind the gear's padded touch target.
        // Give that target priority on compact phones instead of opening goal help.
        if levelMenu == nil, let gear = gameRoot.childNode(withName: "game-menu"), !gear.isHidden,
           CGRect(x: gear.position.x - max(48, minimum) / 2, y: gear.position.y - max(44, minimum) / 2,
                  width: max(48, minimum), height: max(44, minimum)).contains(point) {
            return ["game-menu"] + names.filter { $0 != "quest-objective" }
        }
        if levelMenu == nil, !finished, let next = nextNode,
           CGRect(x: next.position.x - minimum / 2, y: next.position.y - minimum / 2,
                  width: minimum, height: minimum).contains(point) {
            return names + ["swap-bubble"]
        }
        let decorationNames: Set<String> = ["board-veil", "result", "control-tip", "courtyard-resident",
                                            "map-area-header", "map-activities", "courtyard-welcome-introduction",
                                            "courtyard-portrait-frame", "courtyard-reward-preview", "companion-preview-card", "reward-medallion"]
        var targets: [SKNode] = []
        func collectTargets(_ container: SKNode) {
            for node in container.children where !node.isHidden && node.alpha > 0 && node.zPosition >= 0 {
                if node.name == "map-route" && !FestivalMapLayout.viewport.contains(point) { continue }
                if node is SKShapeNode, let name = node.name, !decorationNames.contains(name) { targets.append(node) }
                if levelMenu != nil { collectTargets(node) }
            }
        }
        collectTargets(parent)
        func frame(of node: SKNode) -> CGRect {
            guard let container = node.parent else { return .zero }
            let rect = node.calculateAccumulatedFrame()
            let corners = [CGPoint(x: rect.minX, y: rect.minY), CGPoint(x: rect.maxX, y: rect.minY),
                           CGPoint(x: rect.minX, y: rect.maxY), CGPoint(x: rect.maxX, y: rect.maxY)]
                .map { container.convert($0, to: parent) }
            let xs = corners.map(\.x), ys = corners.map(\.y)
            return CGRect(x: xs.min()!, y: ys.min()!, width: xs.max()! - xs.min()!, height: ys.max()! - ys.min()!)
        }
        if targets.contains(where: { names.contains($0.name!) }) { return names }
        let nearby = targets.filter { node in
            let rect = frame(of: node)
            return rect.insetBy(dx: -max(0, (minimum - rect.width) / 2), dy: -max(0, (minimum - rect.height) / 2)).contains(point)
        }.min { a, b in
            let x = frame(of: a), y = frame(of: b)
            return hypot(x.midX - point.x, x.midY - point.y) < hypot(y.midX - point.x, y.midY - point.y)
        }
        return nearby?.name.map { names + [$0] } ?? names
    }

    func questIcon(_ name: String, size: CGFloat, color: UIColor = .white) -> SKSpriteNode {
        let resolvedColor = color.resolvedColor(with: view?.traitCollection ?? UITraitCollection.current)
        let key = "\(name)|\(size)|\(resolvedColor.cgColor)"
        let canvas = CGSize(width: size, height: size)
        if let texture = symbolTextures[key] { return SKSpriteNode(texture: texture, size: canvas) }
        let image = (UIImage(systemName: name) ?? UIImage(systemName: "star.fill")!)
            .withTintColor(resolvedColor, renderingMode: .alwaysOriginal)
        // Rasterize symbol tint before SpriteKit uploads the texture. Keeping a
        // template symbol image can lose its tint and show black on device.
        let format = UIGraphicsImageRendererFormat()
        format.scale = 3
        let raster = UIGraphicsImageRenderer(size: canvas, format: format).image { _ in
            let scale = min(size / image.size.width, size / image.size.height)
            let width = image.size.width * scale, height = image.size.height * scale
            image.draw(in: CGRect(x: (size - width) / 2, y: (size - height) / 2, width: width, height: height))
        }
        let texture = SKTexture(image: raster)
        if symbolTextures.count >= 128 { symbolTextures.removeAll() }
        symbolTextures[key] = texture
        return SKSpriteNode(texture: texture, size: canvas)
    }

    func showQuests(area: Int) {
        questArea = area
        menuKind = "quests"
        let overlay = makeMenu(background: LevelCatalog.areas[area].background)
        panel(width: 342, height: 150, point: CGPoint(x: 195, y: 702), parent: overlay)
        label("Side quests", size: 30, point: CGPoint(x: 195, y: 744), parent: overlay)
        paragraph("Optional: play regular levels to help neighbors and earn extra rewards.", y: 675, parent: overlay)
        let quests = FestivalQuest.all.filter { $0.area == area && progress.adventure.available($0, unlockedLevel: progress.unlockedLevel) }
        if quests.isEmpty {
            let message = area == 0 && progress.unlockedLevel < 3 ? "Enjoy the first three levels. Your first side quest appears afterward." : "No side quests in this courtyard yet. Enjoy the puzzle path!"
            paragraph(message, y: 520, parent: overlay)
        }
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
        if (area * LevelCatalog.levelsPerArea..<area * LevelCatalog.levelsPerArea + LevelCatalog.levelsPerArea).allSatisfy({ progress.stars($0) > 0 }) {
            menuButton("Extra challenge", name: "open-challenge", point: CGPoint(x: 195, y: 272), parent: overlay)
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
        if FestivalQuest.all.contains(where: { $0.area == questArea && progress.adventure.available($0, unlockedLevel: progress.unlockedLevel) }) {
            menuButton("Side quests", name: "quest-list", point: CGPoint(x: 195, y: 140), parent: overlay)
            menuButton("Back", name: "quest-back", point: CGPoint(x: 195, y: 70), parent: overlay, height: 44)
        } else {
            menuButton("Back to the map", name: "quest-back", point: CGPoint(x: 195, y: 140), parent: overlay)
        }
    }

    internal func showNeighbor(_ neighbor: FestivalNeighbor) {
        guard progress.neighborIsAvailable(neighbor) else { return }
        if menuKind != "neighbor-detail" { neighborFromMap = menuKind == "map" }
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
        menuButton("Back", name: "neighbor-back", point: CGPoint(x: 195, y: 92), parent: overlay, height: 44)
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

    internal func showQuest(_ quest: FestivalQuest) {
        guard progress.adventure.available(quest, unlockedLevel: progress.unlockedLevel) else { return }
        if menuKind != "quest-detail" { questReturnMenu = menuKind }
        selectedQuest = quest; questArea = quest.area; menuKind = "quest-detail"
        let overlay = makeMenu(background: LevelCatalog.areas[quest.area].background)
        panel(width: 342, height: 62, point: CGPoint(x: 195, y: 742), parent: overlay)
        label(quest.title, size: 24, point: CGPoint(x: 195, y: 745), parent: overlay)
        label("Optional Side Quest", size: 15, point: CGPoint(x: 195, y: 710), parent: overlay)
        let portrait = SKSpriteNode(texture: atlasTexture("festival-hosts", index: quest.area))
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
        paragraph(completed ? quest.thanks : progress.adventure.accepted(quest) ? quest.conversation(step: progress.adventure.count(quest)) : quest.objectiveSummary, y: 430, parent: overlay)
        if completed {
            if let friend = Companion.all.first(where: { $0.unlockQuest == quest.id }) {
                label(progress.unlocked(friend) ? "\(friend.name) has joined your team!" : "\(friend.name) joins after area \(friend.unlockAfter / LevelCatalog.levelsPerArea)", size: 15, point: CGPoint(x: 195, y: 357), parent: overlay)
            }
            let reward = SKShapeNode(rectOf: CGSize(width: 310, height: 48), cornerRadius: 16)
            reward.name = "quest-earned-reward"; reward.position = CGPoint(x: 195, y: 300)
            reward.fillColor = UIColor(red: 1, green: 0.88, blue: 0.46, alpha: 1)
            FestivalStyle.finish(reward, as: .reward); overlay.addChild(reward)
            let gift = questIcon(quest.rewardSymbol, size: 26, color: .systemOrange)
            gift.position.x = -128; reward.addChild(gift)
            feedbackText("Reward earned", size: 12, at: CGPoint(x: 12, y: 8), parent: reward)
            feedbackText(quest.rewardSummary, size: 13, at: CGPoint(x: 12, y: -10), parent: reward)
            label("Choose a display color", size: 16, point: CGPoint(x: 195, y: 256), parent: overlay)
            for (index, color) in [UIColor.systemPink, .systemYellow, .systemTeal].enumerated() {
                let option = SKShapeNode(circleOfRadius: 25)
                option.position = CGPoint(x: 125 + CGFloat(index) * 70, y: 227)
                option.name = "quest-style-\(index)"; option.fillColor = color
                option.strokeColor = .white; option.lineWidth = progress.adventure.style(quest) == index ? 5 : 1.5
                overlay.addChild(option)
            }
            menuButton("Visit the display", name: "quest-back", point: CGPoint(x: 195, y: 172), parent: overlay, height: 44)
        } else {
            let step = progress.adventure.count(quest)
            label("\(step)/3 • \(quest.steps[step])", size: 15, point: CGPoint(x: 195, y: 343), parent: overlay)
            let buddy = Companion.all.first { $0.unlockQuest == quest.id }
            label(buddy.map { "\($0.name) after area \($0.unlockAfter / LevelCatalog.levelsPerArea) • decor + spin" } ?? "Reward: " + quest.rewardSummary, size: 14, point: CGPoint(x: 195, y: 302), parent: overlay)
            menuButton(progress.adventure.accepted(quest) ? "Play regular levels" : "Accept Side Quest", name: progress.adventure.accepted(quest) ? "quest-play" : "quest-accept", point: CGPoint(x: 195, y: 222), parent: overlay)
        }
        menuButton(progress.adventure.accepted(quest) ? "Back" : "Maybe later", name: "quest-dialogue-back", point: CGPoint(x: 195, y: 104), parent: overlay, width: 160, height: 44)
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
        for (index, prize) in FestivalPrize.allCases.enumerated() where progress.adventure.wheelWeight(prize) > 0 {
            let sector = progress.adventure.wheelSector(for: prize)
            let start = CGFloat(sector.lowerBound), end = CGFloat(sector.upperBound)
            let center = (start + end) / 2
            let path = CGMutablePath(); path.move(to: .zero)
            path.addArc(center: .zero, radius: 139, startAngle: start, endAngle: end, clockwise: false)
            path.closeSubpath()
            let wedge = SKShapeNode(path: path); wedge.fillColor = colors[index]; wedge.strokeColor = .white; wedge.lineWidth = 2
            wheel.addChild(wedge)
            let icon: SKNode = prize == .rainbow ? shotNode(.rainbow) : prize == .bomb ? shotNode(.bomb) : questIcon(prize.symbol, size: 22)
            icon.position = CGPoint(x: cos(center) * 93, y: sin(center) * 93)
            wheel.addChild(icon)
        }
        let pointer = SKShapeNode(path: { let p = CGMutablePath(); p.move(to: CGPoint(x: -13, y: 14)); p.addLine(to: CGPoint(x: 13, y: 14)); p.addLine(to: CGPoint(x: 0, y: -9)); p.closeSubpath(); return p }())
        pointer.position = CGPoint(x: 195, y: 624); pointer.fillColor = .white; pointer.strokeColor = .systemYellow; overlay.addChild(pointer)
        let result = SKLabelNode(fontNamed: "AvenirNext-Bold")
        result.name = "wheel-result"; result.fontSize = 23
        result.text = progress.adventure.lastPrize.map { "Last gift: \($0.title)" } ?? "A little festival surprise"
        result.position = CGPoint(x: 195, y: 280); overlay.addChild(result)
        label("Earn a spin every five new levels", size: 14, point: CGPoint(x: 195, y: 240), parent: overlay)
        label(progress.adventure.wheelPrizes.count == 2 ? "All keepsakes collected • booster prizes" : "Mostly boosters • keepsakes too", size: 13, point: CGPoint(x: 195, y: 260), parent: overlay)
        label("and for each completed side quest.", size: 14, point: CGPoint(x: 195, y: 219), parent: overlay)
        label("Saved boosters: \(progress.adventure.rainbowGifts) rainbow • \(progress.adventure.bombGifts) bomb", size: 13, point: CGPoint(x: 195, y: 196), parent: overlay)
        menuButton("Spin", name: "wheel-spin", point: CGPoint(x: 195, y: 158), parent: overlay, height: 44)
        overlay.childNode(withName: "wheel-spin")?.alpha = progress.adventure.availableSpins > 0 ? 1 : 0.4
        menuButton("Back to the map", name: "quest-back", point: CGPoint(x: 195, y: 92), parent: overlay, height: 44)
    }

    func spinWheel() {
        guard !wheelSpinning, let overlay = levelMenu, let wheel = overlay.childNode(withName: "prize-wheel") else { return }
        var random = SystemRandomNumberGenerator()
        // Capture sectors before draw changes ownership and therefore future odds.
        let sectors = Dictionary(uniqueKeysWithValues: FestivalPrize.allCases.map { ($0, progress.adventure.wheelSector(for: $0)) })
        guard let prize = progress.adventure.draw(using: &random), let sector = sectors[prize] else { return }
        wheelSpinning = true
        (overlay.childNode(withName: "wheel-credits") as? SKLabelNode)?.text = "Free spins: \(progress.adventure.availableSpins)"
        overlay.childNode(withName: "wheel-spin")?.alpha = 0.4
        var angle = CGFloat.pi / 2 - CGFloat((sector.lowerBound + sector.upperBound) / 2) - wheel.zRotation.truncatingRemainder(dividingBy: .pi * 2)
        while angle < 0 { angle += .pi * 2 }
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        let spin = SKAction.rotate(byAngle: quiet ? angle : .pi * 8 + angle, duration: quiet ? 0.3 : 2.8); spin.timingMode = .easeOut
        wheel.run(.sequence([spin, .run { [weak self, weak overlay] in
            guard let self else { return }
            self.wheelSpinning = false
            (overlay?.childNode(withName: "wheel-result") as? SKLabelNode)?.text = "You won: \(prize.title)!"
            overlay?.childNode(withName: "wheel-spin")?.alpha = self.progress.adventure.availableSpins > 0 ? 1 : 0.4
            self.showWheelReward(prize)
            self.audio.effect("victory", enabled: self.progress.enabled(.effects), volume: self.progress.effectsVolume)
        }]))
    }

    func showCompanionPreview(_ companion: Companion) {
        menuKind = "companion-preview"
        let area = previewReturnMenu == "courtyard-welcome" ? courtyardWelcomeArea ?? mapArea : mapArea
        let overlay = makeMenu(background: LevelCatalog.areas[area].background)
        let card = panel(width: 344, height: 560, point: CGPoint(x: 195, y: 455), parent: overlay)
        card.name = "companion-preview-card"
        label(companion.name, size: 28, point: CGPoint(x: 195, y: 682), parent: overlay)
        label(companion.kind == .animal ? "Buddy • loads bubbles" : "Shooter • operates the cannon", size: 15, point: CGPoint(x: 195, y: 648), parent: overlay)
        let portrait = SKSpriteNode(texture: companionTexture(companion, frame: 0), size: CGSize(width: 210, height: 210))
        portrait.name = "companion-preview-portrait"; portrait.position = CGPoint(x: 195, y: 513); overlay.addChild(portrait)
        label(progress.unlockLevelProgress(companion), size: 19, point: CGPoint(x: 195, y: 361), parent: overlay)
        if let requirement = progress.unlockQuestProgress(companion) {
            label(requirement, size: 15, point: CGPoint(x: 195, y: 328), parent: overlay)
            if let words = overlay.children.last as? SKLabelNode { fitLabel(words, width: 302) }
        }
        label(progress.unlocked(companion) ? "Choose from Team on the map" : companion.unlockDescription, size: 14, point: CGPoint(x: 195, y: 273), parent: overlay)
        if let words = overlay.children.last as? SKLabelNode { fitLabel(words, width: 302) }
        menuButton("Back", name: "preview-back", point: CGPoint(x: 195, y: 131), parent: overlay, height: 48)
    }

    func dismissCelebrationEffects() {
        for name in ["victory-confetti", "rescue-flight", "area-celebration", "reward-delivery"] { gameRoot.enumerateChildNodes(withName: "//" + name) { node, _ in node.removeFromParent() } }
        levelMenu?.enumerateChildNodes(withName: "//unlock-confetti") { node, _ in node.removeFromParent() }
        levelMenu?.enumerateChildNodes(withName: "//reward-delivery") { node, _ in node.removeFromParent() }
        gameRoot.enumerateChildNodes(withName: "//result-star-*") { node, _ in node.removeAllActions(); node.setScale(1) }
        if let counter = gameRoot.childNode(withName: "//result-score") as? SKLabelNode { counter.removeAllActions(); counter.text = "Score \(score)" }
    }

    func showBuddyWelcome(_ buddy: Companion) {
        welcomedCompanion = buddy
        menuKind = "buddy-welcome"
        let overlay = makeMenu(background: LevelCatalog.areas[level / LevelCatalog.levelsPerArea].background)
        panel(width: 342, height: 74, point: CGPoint(x: 195, y: 729), parent: overlay)
        label(buddy.kind == .human ? "New shooter unlocked!" : "New buddy unlocked!", size: 25, point: CGPoint(x: 195, y: 727), parent: overlay)
        if !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled {
            for index in 0..<16 {
                let piece = SKShapeNode(rectOf: CGSize(width: 5, height: 8))
                piece.fillColor = palette[index % palette.count]; piece.strokeColor = .clear
                piece.position = CGPoint(x: 30 + CGFloat(index) * 22, y: 805)
                piece.name = "unlock-confetti"; overlay.addChild(piece)
                piece.run(.sequence([.group([.moveBy(x: index % 2 == 0 ? 20 : -20, y: -450, duration: 2), .rotate(byAngle: .pi * 2, duration: 2), .fadeOut(withDuration: 2)]), .removeFromParent()]))
            }
        }
        let portrait = SKSpriteNode(texture: companionTexture(buddy, frame: 0), size: CGSize(width: 280, height: 280))
        portrait.position = CGPoint(x: 195, y: 549); overlay.addChild(portrait)
        panel(width: 342, height: 147, point: CGPoint(x: 195, y: 351), parent: overlay)
        label(buddy.name, size: 28, point: CGPoint(x: 195, y: 389), parent: overlay)
        paragraph(buddy.kind == .human ? "Your shooter aims and fires the cannon. Add \(buddy.name) to your team for the next puzzle!" : "Your buddy loads bubbles into the cannon. Add \(buddy.name) to your team for the next puzzle!", y: 341, parent: overlay)
        menuButton("Add to team", name: "buddy-choose", point: CGPoint(x: 195, y: 201), parent: overlay, height: 52)
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
        let rewardName = SKLabelNode(fontNamed: "AvenirNext-Bold")
        rewardName.name = "wheel-reward-quantity"; rewardName.text = prize.title + " ×1"
        rewardName.fontSize = 25; rewardName.position = CGPoint(x: 195, y: 470)
        fitLabel(rewardName, width: 304); overlay.addChild(rewardName)
        let medallion = SKShapeNode(circleOfRadius: 55)
        medallion.name = "reward-medallion"; medallion.position = CGPoint(x: 195, y: 548)
        medallion.zPosition = 0.1; icon.zPosition = 0.2; medallion.fillColor = FestivalStyle.cream
        FestivalStyle.finish(medallion, as: .reward); overlay.addChild(medallion)
        deliverRewardArtwork(icon, on: overlay, to: CGPoint(x: 195, y: 299))
        paragraph(prize == .rainbow || prize == .bomb ? "Saved to your booster supply. Use it from the bottom controls during a puzzle." : "Saved to your collection. Choose pins under Team on the map; bunting decorates each courtyard.", y: 400, parent: overlay)
        label("\(progress.adventure.rainbowGifts) extra rainbow • \(progress.adventure.bombGifts) extra bomb", size: 15, point: CGPoint(x: 195, y: 299), parent: overlay)
        menuButton("Back to the wheel", name: "wheel-return", point: CGPoint(x: 195, y: 185), parent: overlay, height: 48)
        menuButton("Festival map", name: "quest-back", point: CGPoint(x: 195, y: 115), parent: overlay, height: 48)
    }

    internal func showGameMenu() {
        menuKind = "game-menu"; returnMenu = "game"
        let overlay = makeMenu(background: activeLevel.background)
        panel(width: 330, height: 470, point: CGPoint(x: 195, y: 440), parent: overlay)
        label("Puzzle menu", size: 28, point: CGPoint(x: 195, y: 624), parent: overlay)
        menuButton("Keep playing", name: "game-resume", point: CGPoint(x: 195, y: 560), parent: overlay, height: 50)
        let musicPlaying = progress.enabled(.music) && progress.musicVolume > 0
        menuButton(musicPlaying ? "Mute music" : "Turn music on", name: "game-music", point: CGPoint(x: 195, y: 498), parent: overlay, height: 44)
        decorateMenuIcon(musicPlaying ? "speaker.wave.2.fill" : "speaker.slash.fill", name: "game-music", parent: overlay, x: -108)
        menuButton("Explore Map", name: "game-map", point: CGPoint(x: 195, y: 436), parent: overlay, height: 44)
        menuButton("Restart puzzle", name: "game-restart", point: CGPoint(x: 195, y: 374), parent: overlay, height: 44)
        menuButton("Settings", name: "settings", point: CGPoint(x: 195, y: 312), parent: overlay, height: 44)
        menuButton("Start Menu", name: "home", point: CGPoint(x: 195, y: 250), parent: overlay, height: 44)
    }

    func showRetryPrompt() {
        menuKind = "retry-prompt"; returnMenu = "game"
        let overlay = makeMenu(background: activeLevel.background)
        panel(width: 340, height: 260, point: CGPoint(x: 195, y: 434), parent: overlay)
        label("Restart this puzzle?", size: 24, point: CGPoint(x: 195, y: 515), parent: overlay)
        let detail = attemptCounted ? "This try is already used. Your first shot after restarting uses another try." : "Your first shot uses one try. Each level has five tries. One returns every five minutes."
        let explanation = paragraph(detail, y: 456, parent: overlay)
        explanation.fontSize = 15
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
        let overlay = makeMenu(background: activeLevel.background)
        panel(width: 342, height: 360, point: CGPoint(x: 195, y: 434), parent: overlay)
        label("A new festival bubble", size: 25, point: CGPoint(x: 195, y: 568), parent: overlay)
        let sample = specialBubble(kind); sample.setScale(2); sample.position = CGPoint(x: 195, y: 496); overlay.addChild(sample)
        paragraph(kind.explanation, y: 400, parent: overlay)
        menuButton("Let's try it", name: "special-ready", point: CGPoint(x: 195, y: 310), parent: overlay, height: 44)
    }

    func showChallenge() {
        guard (questArea * LevelCatalog.levelsPerArea..<questArea * LevelCatalog.levelsPerArea + LevelCatalog.levelsPerArea).allSatisfy({ progress.stars($0) > 0 }) else { return }
        menuKind = "challenge"
        let overlay = makeMenu(background: LevelCatalog.areas[questArea].background)
        panel(width: 342, height: 62, point: CGPoint(x: 195, y: 723), parent: overlay)
        label("A little extra challenge", size: 25, point: CGPoint(x: 195, y: 720), parent: overlay)
        panel(width: 342, height: 300, point: CGPoint(x: 195, y: 470), parent: overlay)
        paragraph("Replay this station's opening puzzle with fewer shots and no boosters. Can you earn five stars?", y: 510, parent: overlay)
        label(progress.challengeWon(questArea) ? "Challenge completed ✓" : "An optional festival challenge", size: 17, point: CGPoint(x: 195, y: 375), parent: overlay)
        menuButton("Try the challenge", name: "challenge-play", point: CGPoint(x: 195, y: 248), parent: overlay)
        menuButton("Side quests", name: "quest-list", point: CGPoint(x: 195, y: 160), parent: overlay, height: 44)
    }

    func saveCheckpoint() {
        // A blocked selection must not save the previous board as the selected level.
        guard generatedLevel?.index == level, playingChallenge == challengeMode else { return }
        // Finish an already committed shot before pausing or leaving the puzzle.
        if let shot = projectile, let flight = pendingFlight {
            shot.removeAllActions()
            settle(shot, landing: flight.landing, kind: flight.kind)
        }
        guard hasStartedPuzzle, !finished, projectile == nil, !board.bubbles.isEmpty, !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) else { return }
        progress.save(GameCheckpoint(level: level, board: board, shots: shots, score: score,
                                     current: currentColor, next: nextColor, bag: colorBag,
                                     rainbow: rainbowLeft, bomb: bombLeft, play: questPlay, challenge: challengeMode,
                                     freeRainbow: freeRainbow, freeBomb: freeBomb, ceilingOffset: ceilingOffset, shotsFired: shotsFired, pressureSeed: pressureSeed, layoutSeed: layoutSeed, goal: puzzleGoal, bankMatches: bankMatches, boosterShots: boosterShots, balanceVersion: pressureBalanceVersion, shotBudget: attemptShotBudget, tryStarted: attemptCounted, timedCeilingElapsed: timedPressure.elapsed, timedCeilingDrops: timedPressure.drops))
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
        let quests = FestivalQuest.all.filter { $0.area == level / LevelCatalog.levelsPerArea && progress.adventure.accepted($0) && !progress.adventure.completed($0) && !questPlay.collected.contains($0.id) }
        let cells = board.bubbles.keys.filter { board.specials[$0] == nil && !board.blockers.contains($0) && !puzzleGoal.remaining.contains($0) }
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
        gameRoot.childNode(withName: "game-menu")?.position = GameplayHUDLayout.settingsCenter
        gameRoot.childNode(withName: "shots-counter")?.position = CGPoint(x: 195, y: 126)
        gameRoot.childNode(withName: "quest-objective")?.position = GameplayHUDLayout.goalCenter
        let boosterNames = ["rainbow", "bomb"]
        // Anchor the last slot at the right edge; each additional slot grows leftward.
        for (index, name) in boosterNames.enumerated() {
            let x = CGFloat(330 - (boosterNames.count - 1 - index) * 67)
            gameRoot.childNode(withName: name)?.position = CGPoint(x: x, y: 84)
        }
        gameRoot.childNode(withName: "booster-tray")?.position.x = 296.5
        gameRoot.childNode(withName: "control-dock")?.position.x = 195
        gameRoot.childNode(withName: "board-veil")?.alpha = progress.enabled(.contrast) ? 0.34 : 0.17
        view?.preferredFramesPerSecond = levelMenu != nil || ProcessInfo.processInfo.isLowPowerModeEnabled ? 30 : 60
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        updateCompanionMotion(quiet: quiet)
        gameRoot.childNode(withName: "ambient")?.isHidden = quiet
        gameRoot.childNode(withName: "ambient")?.isPaused = quiet
        for x in [17, 373] { gameRoot.childNode(withName: "ambient-lantern-\(x)")?.isPaused = quiet }
        for node in Array(nodes.values) + [loaded, nextNode].compactMap({ $0 }) {
            let rim = node.childNode(withName: "bubble-rim") as? SKShapeNode
            rim?.strokeColor = UIColor.white.withAlphaComponent(progress.enabled(.contrast) ? 1 : 0.5)
            rim?.lineWidth = progress.enabled(.contrast) ? 2 : 1
        }
    }

    internal func updateCompanionMotion(quiet: Bool) {
        if quiet, let animal = gameRoot.childNode(withName: "companion-0") as? SKSpriteNode {
            animal.removeAllActions(); animal.position.y = 134; animal.setScale(1)
            animal.texture = companionTexture(progress.selected(.animal), frame: 0)
        } else if !quiet, let animal = gameRoot.childNode(withName: "companion-0"), animal.action(forKey: "breathing") == nil {
            animal.run(.repeatForever(.sequence([.scaleY(to: 1.015, duration: 1.5), .scaleY(to: 1, duration: 1.5)])), withKey: "breathing")
        }
        if let animal = gameRoot.childNode(withName: "companion-0") as? SKSpriteNode {
            animal.removeAction(forKey: "idle-expression")
            if !quiet {
                animal.run(.repeatForever(.sequence([
                    .wait(forDuration: 6.5, withRange: 2),
                    .run { [weak self, weak animal] in
                        guard let self, animal?.action(forKey: "loading") == nil else { return }
                        animal?.texture = self.idleExpressionTexture(self.progress.selected(.animal))
                    },
                    .wait(forDuration: 0.22),
                    .run { [weak self, weak animal] in
                        guard let self, animal?.action(forKey: "loading") == nil else { return }
                        animal?.texture = self.companionTexture(self.progress.selected(.animal), frame: 0)
                    }
                ])), withKey: "idle-expression")
            }
        }
        updateOperatorAppearance(quietMotion: quiet)
    }

    func showSoundLevels() {
        menuKind = "sound-levels"
        let overlay = makeMenu(background: activeLevel.background)
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
        label("Team pins", size: 30, point: CGPoint(x: 195, y: 728), parent: overlay)
        paragraph("Little gifts from the festival prize wheel and our friends.", y: 651, parent: overlay)
        menuButton("No pin", name: "pin-none", point: CGPoint(x: 195, y: 550), parent: overlay)
        for (index, prize) in progress.adventure.unlockedPins.enumerated() {
            menuButton(prize.title + (progress.adventure.equippedPin == prize ? " ✓" : ""), name: "pin-\(prize.rawValue)", point: CGPoint(x: 195, y: 478 - CGFloat(index) * 72), parent: overlay)
        }
        menuButton("Back to Team", name: "accessory-back", point: CGPoint(x: 195, y: 120), parent: overlay, height: 44)
    }

    func companionTexture(_ friend: Companion, frame: Int, glance: Bool = false) -> SKTexture {
        let frame = min(3, max(0, frame))
        let key = "\(friend.id):\(frame):\(glance)"
        if let cached = companionTextures[key] { return cached }
        let texture = makeCompanionTexture(friend, frame: frame, glance: glance)
        companionTextures[key] = texture
        return texture
    }

    func makeCompanionTexture(_ friend: Companion, frame: Int, glance: Bool) -> SKTexture {
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

    internal func animateCompanion(_ kind: Companion.Kind, frames: [Int], repeating: Bool = false) {
        let index = kind == .animal ? 0 : 1
        guard let sprite = gameRoot.childNode(withName: "companion-\(index)") as? SKSpriteNode else { return }
        let key = kind == .animal ? "loading" : "operating"
        guard !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled else {
            sprite.removeAction(forKey: key)
            sprite.removeAction(forKey: "expression")
            sprite.texture = companionTexture(progress.selected(kind), frame: 0); return
        }
        if frames == [1, 2], sprite.action(forKey: key) != nil { return }
        sprite.removeAction(forKey: key)
        let friend = progress.selected(kind)
        let animation = SKAction.animate(with: frames.map { companionTexture(friend, frame: $0, glance: kind == .human && frames == [1, 2]) }, timePerFrame: 0.16, resize: false, restore: true)
        sprite.run(repeating ? .repeatForever(animation) : animation, withKey: key)
    }

    func updateMachineStyle() {
        guard let cannon = gameRoot.childNode(withName: "cannon") as? SKShapeNode else { return }
        let colors: [UIColor] = [
            UIColor(red: 0.62, green: 0.16, blue: 0.13, alpha: 1),
            UIColor(red: 0.18, green: 0.38, blue: 0.30, alpha: 1),
            UIColor(red: 0.63, green: 0.30, blue: 0.13, alpha: 1),
            UIColor(red: 0.18, green: 0.30, blue: 0.48, alpha: 1),
            UIColor(red: 0.39, green: 0.23, blue: 0.43, alpha: 1)
        ]
        let brass = UIColor(red: 0.93, green: 0.73, blue: 0.38, alpha: 1)
        let lacquer = colors[(level / LevelCatalog.levelsPerArea) % colors.count]
        // Keep the counter in the fixed lower housing, independent of barrel aiming/recoil.
        if let housing = gameRoot.childNode(withName: "shots-counter") as? SKShapeNode {
            housing.fillColor = lacquer; FestivalStyle.finish(housing, as: .lacquer)
        }
        cannon.fillColor = UIColor(red: 0.70, green: 0.91, blue: 0.96, alpha: 0.14)
        cannon.strokeColor = brass
        cannon.removeAllChildren()
        // The bubble sits behind a faint glass wall; the framing stays outside its symbol.
        let glass = SKShapeNode(); glass.path = cannon.path
        glass.name = "cannon-glass"; glass.zPosition = 2
        glass.fillColor = UIColor(red: 0.78, green: 0.95, blue: 1, alpha: 0.10)
        glass.strokeColor = UIColor.white.withAlphaComponent(0.32); glass.lineWidth = 1
        cannon.addChild(glass)
        let shine = SKShapeNode(rectOf: CGSize(width: 3, height: 47), cornerRadius: 1.5)
        shine.position = CGPoint(x: -22, y: 3); shine.zPosition = 3
        shine.fillColor = UIColor.white.withAlphaComponent(0.40)
        shine.strokeColor = .clear; cannon.addChild(shine)
        let base = SKShapeNode(rectOf: CGSize(width: 42, height: 15), cornerRadius: 3)
        base.position.y = -30; base.fillColor = lacquer; base.strokeColor = brass
        FestivalStyle.finish(base, as: .lacquer)
        cannon.addChild(base)
        let crest = questIcon("sun.max.fill", size: 10, color: FestivalStyle.cream)
        crest.position.y = -30; crest.zPosition = 1; cannon.addChild(crest)
        for y in [CGFloat(-37), -22] {
            let band = SKShapeNode(rectOf: CGSize(width: y == -37 ? 41 : 45, height: 6), cornerRadius: 2)
            band.name = "barrel-band"; band.position.y = y
            band.fillColor = brass; band.strokeColor = UIColor(red: 0.47, green: 0.30, blue: 0.12, alpha: 1)
            FestivalStyle.finish(band, as: .brass)
            cannon.addChild(band)
        }
        let muzzle = SKShapeNode(ellipseOf: CGSize(width: 60, height: 13))
        muzzle.name = "fireworks-muzzle"; muzzle.position.y = 30
        muzzle.fillColor = UIColor(red: 0.70, green: 0.91, blue: 0.96, alpha: 0.12)
        muzzle.strokeColor = brass; muzzle.lineWidth = 4; cannon.addChild(muzzle)
        let fusePath = CGMutablePath()
        fusePath.move(to: CGPoint(x: -20, y: -28))
        fusePath.addCurve(to: CGPoint(x: -35, y: -17), control1: CGPoint(x: -40, y: -33), control2: CGPoint(x: -42, y: -24))
        let fuse = SKShapeNode(path: fusePath)
        fuse.name = "festival-fuse"; fuse.strokeColor = UIColor(red: 0.89, green: 0.80, blue: 0.58, alpha: 1)
        fuse.lineWidth = 3; cannon.addChild(fuse)
        gameRoot.childNode(withName: "machine-trim")?.removeFromParent()
        let stand = SKNode(); stand.name = "machine-trim"; stand.zPosition = -0.1
        gameRoot.addChild(stand)
        let neck = SKShapeNode(rectOf: CGSize(width: 62, height: 14), cornerRadius: 3)
        neck.name = "cannon-housing-neck"; neck.position = CGPoint(x: 195, y: 149)
        neck.fillColor = lacquer; neck.strokeColor = brass; neck.lineWidth = 2
        FestivalStyle.finish(neck, as: .lacquer)
        stand.addChild(neck)
        for x in [CGFloat(167), 223] {
            let foot = SKShapeNode(rectOf: CGSize(width: 13, height: 27), cornerRadius: 3)
            foot.position = CGPoint(x: x, y: 147); foot.fillColor = UIColor(red: 0.39, green: 0.23, blue: 0.13, alpha: 1)
            FestivalStyle.finish(foot, as: .wood); stand.addChild(foot)
        }
        let cradle = SKShapeNode(rectOf: CGSize(width: 78, height: 11), cornerRadius: 4)
        cradle.position = CGPoint(x: 195, y: 139); cradle.fillColor = .brown; cradle.strokeColor = brass
        FestivalStyle.finish(cradle, as: .wood); stand.addChild(cradle)
    }

    internal func idleExpressionTexture(_ friend: Companion) -> SKTexture {
        // Newer sheets have no glance atlas. Use their connected, open-eyed gesture
        // instead of asking for a glance texture that would silently stay unchanged.
        friend.atlasIndex >= 6 ? companionTexture(friend, frame: 1) : companionTexture(friend, frame: 0, glance: true)
    }

    func updateOperatorAppearance(quietMotion: Bool? = nil) {
        guard let buddy = gameRoot.childNode(withName: "companion-1") as? SKSpriteNode else { return }
        buddy.removeAction(forKey: "operating"); buddy.removeAction(forKey: "breathing")
        buddy.yScale = 1
        // One complete painted pose keeps the arms attached; the wheel covers the hands.
        buddy.texture = companionTexture(progress.selected(.human), frame: 0)
        buddy.removeAction(forKey: "expression")
        let quiet = quietMotion ?? (UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled)
        guard !quiet else { return }
        buddy.run(.repeatForever(.sequence([.scaleY(to: 1.006, duration: 2.1), .scaleY(to: 1, duration: 2.1)])), withKey: "breathing")
        // Swap complete painted poses, never detach or stretch an individual limb.
        buddy.run(.repeatForever(.sequence([
            .wait(forDuration: 4.8, withRange: 2.0),
            .run { [weak self, weak buddy] in
                guard let self, buddy?.action(forKey: "operating") == nil else { return }
                buddy?.texture = self.idleExpressionTexture(self.progress.selected(.human))
            },
            .wait(forDuration: 0.3),
            .run { [weak self, weak buddy] in
                guard let self, buddy?.action(forKey: "operating") == nil else { return }
                buddy?.texture = self.companionTexture(self.progress.selected(.human), frame: 0)
            }
        ])), withKey: "expression")
    }

    func characterReaction(_ text: String, quiet: Bool) {
        let now = ProcessInfo.processInfo.systemUptime
        guard now - lastCharacterReactionTime >= 3 else { return }
        lastCharacterReactionTime = now
        gameRoot.childNode(withName: "character-reaction")?.removeFromParent()
        let note = panel(width: 119, height: 27, point: CGPoint(x: 309, y: 267), parent: gameRoot)
        note.name = "character-reaction"; note.zPosition = 14
        label(text, size: 12, point: CGPoint(x: 0, y: -4), parent: note)
        note.run(.sequence([.wait(forDuration: quiet ? 1.6 : 1.2), .fadeOut(withDuration: 0.2), .removeFromParent()]))
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
        // Reserve 70 scene points above this compact bar for the status bar and
        // Dynamic Island, while keeping its lower edge above the ceiling rail.
        let badge = panel(width: GameplayHUDLayout.goalSize.width, height: GameplayHUDLayout.goalSize.height, point: GameplayHUDLayout.goalCenter, parent: gameRoot)
        badge.name = "quest-objective"; badge.zPosition = 8
        badge.path = CGPath(rect: CGRect(x: -195, y: -24, width: 390, height: 48), transform: nil)
        badge.fillColor = UIColor(red: 0.10, green: 0.19, blue: 0.29, alpha: 0.96)
        badge.strokeColor = .clear
        let edge = SKShapeNode(rectOf: CGSize(width: 390, height: 2))
        edge.position.y = -24; edge.fillColor = UIColor(red: 0.93, green: 0.73, blue: 0.38, alpha: 1)
        edge.strokeColor = .clear; badge.addChild(edge)
        let icon = rescueObject(kind: puzzleGoal.kind)
        icon.position.x = -99; icon.setScale(1.15); badge.addChild(icon)
        let info = questIcon("info.circle", size: 13, color: .white)
        info.position = CGPoint(x: 182, y: 14); badge.addChild(info)
        let heading = SKLabelNode(fontNamed: "AvenirNext-Bold")
        heading.text = "LEVEL \(level + 1) • GOAL"; heading.fontSize = 14; heading.fontColor = .white
        heading.horizontalAlignmentMode = .left; heading.position = CGPoint(x: -76, y: 7)
        badge.addChild(heading)
        let title = SKLabelNode(fontNamed: "AvenirNext-Bold")
        title.text = puzzleGoal.kind.hudTitle
        title.fontSize = 14; title.fontColor = .white; title.verticalAlignmentMode = .center
        title.horizontalAlignmentMode = .left; title.position = CGPoint(x: -76, y: -11)
        fitLabel(title, width: 178); badge.addChild(title)
        let count = feedbackText(puzzleGoal.kind == .clear ? "\(board.bubbles.count)" : "\(puzzleGoal.total - puzzleGoal.remaining.count)/\(puzzleGoal.total)", size: 22, at: CGPoint(x: 141, y: 3), parent: badge, color: .white)
        count.name = "objective-progress"
        label(puzzleGoal.kind == .clear ? "bubbles left" : "complete", size: 9, point: CGPoint(x: 141, y: -17), parent: badge)
    }

    internal func showObjectives() {
        menuKind = "objectives"
        let overlay = makeMenu(background: activeLevel.background)
        panel(width: 342, height: 550, point: CGPoint(x: 195, y: 443), parent: overlay)
        label(puzzleGoal.kind.title, size: 25, point: CGPoint(x: 195, y: 675), parent: overlay)
        let instructions = paragraph(activeLevel.objectiveHelp(board: board, goal: puzzleGoal), y: 640, parent: overlay)
        instructions.text = (instructions.text ?? "") + " " + PuzzleRating.fiveStarHint(budget: attemptShotBudget)
        instructions.verticalAlignmentMode = .top
        instructions.name = "objective-instructions"
        var cursor = instructions.frame.minY - 30
        let quests = FestivalQuest.all.filter { $0.area == level / LevelCatalog.levelsPerArea && progress.adventure.accepted($0) && !progress.adventure.completed($0) }
        if !quests.isEmpty {
            label("Optional side quests", size: 16, point: CGPoint(x: 195, y: cursor), parent: overlay)
            cursor -= 32
        }
        for quest in quests {
            label(quest.title, size: 19, point: CGPoint(x: 195, y: cursor), parent: overlay)
            let detail = paragraph(quest.steps[progress.adventure.count(quest)], y: cursor - 20, parent: overlay)
            detail.verticalAlignmentMode = .top
            cursor = detail.frame.minY - 30
        }
        menuButton("Keep playing", name: "objective-close", point: CGPoint(x: 195, y: 110), parent: overlay, height: 50)
    }

    func acknowledgeObstacleTip() {
        guard let tip = gameRoot.childNode(withName: "control-tip"), let lesson = tip.userData?["lesson"] as? String else { return }
        progress.learnObstacle(lesson)
        tip.removeFromParent()
        profiles.persistActive()
    }

    func showObstacleIntroduction() {
        guard !finished, levelMenu == nil, gameRoot.childNode(withName: "control-tip") == nil else { return }
        let lesson: (String, String)?
        if !board.armor.isEmpty && !progress.hasLearnedObstacle("armor") { lesson = ("armor", "Silver rings need two matching hits") }
        else if !board.blockers.isEmpty && !progress.hasLearnedObstacle("wood") { lesson = ("wood", "Drop wooden blocks by clearing their supports") }
        else if activeLevel.isPrecision && !progress.hasLearnedObstacle("precision") { lesson = ("precision", "Small board, fewer shots. Plan each match") }
        else { lesson = nil }
        guard let (key, text) = lesson else { return }
        let tip = panel(width: 294, height: 46, point: CGPoint(x: 195, y: 283), parent: gameRoot)
        tip.name = "control-tip"; tip.zPosition = 14
        tip.userData = ["lesson": key] as NSMutableDictionary
        let words = SKLabelNode(fontNamed: "AvenirNext-Medium")
        words.text = text; words.fontSize = 14; words.numberOfLines = 2
        words.preferredMaxLayoutWidth = 270; words.verticalAlignmentMode = .center; tip.addChild(words)
        tip.run(.sequence([.wait(forDuration: 3.5), .fadeOut(withDuration: 0.25), .run { [weak self, weak tip] in
            guard let self, let tip, self.levelMenu == nil, self.gameRoot.childNode(withName: "control-tip") === tip else { return }
            self.acknowledgeObstacleTip()
        }]))
    }

    func cannonFeedback() {
        guard !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled,
              let cannon = gameRoot.childNode(withName: "cannon") else { return }
        cannon.run(.sequence([.moveBy(x: 0, y: -3, duration: 0.05), .moveBy(x: 0, y: 3, duration: 0.13)]), withKey: "cannon-recoil")
        let glow = SKShapeNode(circleOfRadius: 18)
        glow.position = cannon.convert(CGPoint(x: 0, y: 30), to: gameRoot)
        glow.strokeColor = .systemYellow; glow.fillColor = .clear; glow.lineWidth = 3; glow.alpha = 0.55
        glow.zPosition = 5; gameRoot.addChild(glow)
        glow.run(.sequence([.group([.scale(to: 1.25, duration: 0.18), .fadeOut(withDuration: 0.18)]), .removeFromParent()]))
    }

    func stickFeedback(on node: SKNode, quiet: Bool) {
        let ring = SKShapeNode(circleOfRadius: 23)
        ring.strokeColor = .white; ring.lineWidth = 2; ring.fillColor = .clear
        ring.zPosition = 5; node.addChild(ring)
        ring.run(.sequence([.fadeOut(withDuration: 0.45), .removeFromParent()]))
        if !quiet { node.run(.sequence([.scale(to: 0.92, duration: 0.07), .scale(to: 1, duration: 0.12)])) }
    }

    func armorCrackEffect(at location: CGPoint) {
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        for index in 0..<(quiet ? 1 : 4) {
            let shard = SKShapeNode(rectOf: CGSize(width: 3, height: 10), cornerRadius: 1)
            shard.fillColor = .systemGray3; shard.strokeColor = .white; shard.position = location; shard.zPosition = 13
            gameRoot.addChild(shard)
            let drift = quiet ? SKAction.wait(forDuration: 0.2) : .moveBy(x: index % 2 == 0 ? -16 : 16, y: index < 2 ? 13 : -13, duration: 0.25)
            shard.run(.sequence([.group([drift, .fadeOut(withDuration: 0.25)]), .removeFromParent()]))
        }
    }

    @discardableResult
    func feedbackText(_ text: String, size: CGFloat, at point: CGPoint, parent: SKNode, color: UIColor = UIColor(red: 0.29, green: 0.20, blue: 0.15, alpha: 1)) -> SKLabelNode {
        let words = SKLabelNode(fontNamed: "AvenirNext-Bold")
        words.text = text; words.fontSize = size; words.fontColor = color
        words.position = point; words.verticalAlignmentMode = .center
        words.numberOfLines = 2; words.preferredMaxLayoutWidth = 282
        parent.addChild(words); return words
    }

    func feedbackStar(radius: CGFloat, earned: Bool) -> SKShapeNode {
        let path = CGMutablePath()
        for index in 0..<10 {
            let angle = CGFloat.pi / 2 + CGFloat(index) * .pi / 5
            let length = index.isMultiple(of: 2) ? radius : radius * 0.47
            let point = CGPoint(x: cos(angle) * length, y: sin(angle) * length)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        let star = SKShapeNode(path: path)
        star.fillColor = earned ? .systemYellow : UIColor(white: 0.8, alpha: 1)
        star.strokeColor = earned ? .systemOrange : .systemGray; star.lineWidth = 2
        return star
    }

    func acknowledgePuzzleCoach() {
        guard let card = gameRoot.childNode(withName: "puzzle-coach") else { return }
        if let raw = card.userData?["goal"] as? String, let kind = PuzzleObjective(rawValue: raw) { progress.markObjectiveSeen(kind) }
        if card.userData?["tries"] as? Bool == true { progress.hasSeenTriesHelp = true }
        card.removeFromParent()
        profiles.persistActive()
        showObstacleIntroduction()
    }

    func showPuzzleCoachIfNeeded() {
        guard hasStartedPuzzle, !finished, levelMenu == nil, generatedLevel?.index == level,
              gameRoot.childNode(withName: "puzzle-coach") == nil,
              !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }) else { return }
        let explainObjective = puzzleGoal.kind != .clear && !progress.hasSeenObjective(puzzleGoal.kind)
        let explainTries = !progress.hasSeenTriesHelp
        guard explainObjective || explainTries else { return }
        gameRoot.childNode(withName: "level-arrival")?.removeFromParent()
        gameRoot.childNode(withName: "control-tip")?.removeFromParent()
        let card = SKShapeNode(rectOf: CGSize(width: 320, height: 170), cornerRadius: 22)
        card.name = "puzzle-coach"; card.position = CGPoint(x: 195, y: 408); card.zPosition = 17
        card.fillColor = UIColor(red: 1, green: 0.95, blue: 0.8, alpha: 0.98); card.strokeColor = .systemOrange; card.lineWidth = 3
        card.userData = ["goal": explainObjective ? puzzleGoal.kind.rawValue : "", "tries": explainTries] as NSMutableDictionary
        gameRoot.addChild(card)
        feedbackText(explainObjective ? puzzleGoal.kind.hudTitle : "Five tries per level", size: 18, at: CGPoint(x: 0, y: 62), parent: card)
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        if explainObjective {
            for index in 0..<3 {
                let example = bubble(currentColor); example.setScale(0.55)
                example.position = CGPoint(x: CGFloat(index - 1) * 26, y: 20); card.addChild(example)
                if index == 1 {
                    let window = SKShapeNode(circleOfRadius: 14)
                    window.fillColor = .white; window.strokeColor = .systemYellow; window.lineWidth = 3; example.addChild(window)
                    let object = rescueObject(kind: puzzleGoal.kind); window.addChild(object)
                    example.setScale(1.1)
                }
                if !quiet { example.run(.sequence([.wait(forDuration: 0.8), .fadeOut(withDuration: 0.25), .wait(forDuration: 0.6), .fadeIn(withDuration: 0.25)])) }
            }
        } else {
            for index in 0..<LevelLives.capacity {
                let heart = questIcon("heart.fill", size: 22, color: .systemPink)
                heart.position = CGPoint(x: CGFloat(index - 2) * 30, y: 20); card.addChild(heart)
            }
        }
        let body = explainObjective ? puzzleGoal.startSummary : "Your first shot uses one try.\nResuming an unfinished puzzle is free."
        feedbackText(body, size: 12, at: CGPoint(x: 0, y: -28), parent: card)
        feedbackText(explainTries ? "First shot uses a try • +1 every five minutes" : PuzzleRating.fiveStarHint(budget: attemptShotBudget), size: 10, at: CGPoint(x: 0, y: -66), parent: card)
        card.run(.sequence([.wait(forDuration: 5), .fadeOut(withDuration: 0.2), .run { [weak self, weak card] in
            guard let self, let card, self.gameRoot.childNode(withName: "puzzle-coach") === card else { return }
            self.acknowledgePuzzleCoach()
        }]))
    }

    func showLevelArrival() {
        gameRoot.childNode(withName: "level-arrival")?.removeFromParent()
        let card = SKShapeNode(rectOf: CGSize(width: 320, height: 182), cornerRadius: 22)
        card.name = "level-arrival"; card.position = CGPoint(x: 195, y: 408); card.zPosition = 15
        card.fillColor = UIColor(red: 1, green: 0.95, blue: 0.78, alpha: 0.97)
        card.strokeColor = .systemOrange; card.lineWidth = 3; gameRoot.addChild(card)
        let title = feedbackText("Level \(level + 1)" + (activeLevel.isMilestone ? " • Finale" : ""), size: 29, at: CGPoint(x: 0, y: 62), parent: card)
        title.numberOfLines = 1; fitLabel(title, width: 278)
        let icon = rescueObject(kind: puzzleGoal.kind); icon.name = "arrival-object"; icon.position = CGPoint(x: 0, y: 17); icon.setScale(1.7); card.addChild(icon)
        let goalText = feedbackText(puzzleGoal.startSummary, size: 14, at: CGPoint(x: 0, y: -27), parent: card)
        goalText.preferredMaxLayoutWidth = 294
        let hint = activeLevel.retryHint(board: board, goal: puzzleGoal, consecutiveLosses: challengeMode ? 0 : progress.levelResults(level).consecutiveLosses)
        let footer = feedbackText(hint ?? PuzzleRating.fiveStarHint(budget: attemptShotBudget), size: hint == nil ? 11 : 10, at: CGPoint(x: 0, y: -67), parent: card)
        footer.name = hint == nil ? "arrival-rating-tip" : "arrival-retry-tip"
        footer.preferredMaxLayoutWidth = 294
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        if !quiet { card.setScale(0.92); card.run(.scale(to: 1, duration: 0.18)) }
        let exit: SKAction = quiet ? .fadeOut(withDuration: 0.2) : .group([.move(to: GameplayHUDLayout.goalCenter, duration: 0.3), .scale(to: 0.08, duration: 0.3), .fadeOut(withDuration: 0.3)])
        card.run(.sequence([.wait(forDuration: hint == nil ? 2.6 : 4), exit, .removeFromParent()]))
    }

    func showTargetFeedback() {
        gameRoot.childNode(withName: "target-feedback")?.removeFromParent()
        let banner = SKShapeNode(rectOf: CGSize(width: 286, height: 46), cornerRadius: 20)
        banner.name = "target-feedback"; banner.position = CGPoint(x: 195, y: 382); banner.zPosition = 15
        banner.fillColor = UIColor(red: 1, green: 0.91, blue: 0.57, alpha: 0.98)
        banner.strokeColor = .white; banner.lineWidth = 2; gameRoot.addChild(banner)
        let title = puzzleGoal.kind == .lanterns ? "Lantern rescued!" : puzzleGoal.kind == .charms ? "Charm collected!" : "Target reached!"
        feedbackText("\(title) \(puzzleGoal.total - puzzleGoal.remaining.count)/\(puzzleGoal.total)", size: 17, at: .zero, parent: banner)
        banner.run(.sequence([.wait(forDuration: 0.9), .fadeOut(withDuration: 0.2), .removeFromParent()]))
    }

    func showPuzzleResult(success: Bool, newBest: Bool) {
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        let card = SKShapeNode(rectOf: CGSize(width: 344, height: 450), cornerRadius: 28)
        card.name = "result"; card.position = CGPoint(x: 195, y: 425); card.zPosition = 20
        card.fillColor = UIColor(red: 1, green: 0.95, blue: 0.80, alpha: 0.99)
        FestivalStyle.finish(card, as: .reward); gameRoot.addChild(card)
        FestivalStyle.reveal(card, quiet: quiet)
        let ribbon = SKShapeNode(rectOf: CGSize(width: 354, height: 51), cornerRadius: 12)
        ribbon.position.y = 200; ribbon.fillColor = FestivalStyle.coral
        FestivalStyle.finish(ribbon, as: .lacquer); card.addChild(ribbon)
        feedbackText(success ? (earnedCourtyardSouvenir ? "Courtyard complete!" : "Level \(level + 1) complete!") : "Level \(level + 1) • Try again", size: 24, at: .zero, parent: ribbon, color: .white)
        let objectiveSummary = feedbackText(success ? puzzleGoal.victorySummary(on: board) : "A fresh angle, a fresh chance", size: 13, at: CGPoint(x: 12, y: 158), parent: card)
        objectiveSummary.preferredMaxLayoutWidth = 268
        if success && puzzleGoal.kind != .clear {
            let object = rescueObject(kind: puzzleGoal.kind)
            object.name = "result-objective-icon"; object.position = CGPoint(x: -145, y: 158); card.addChild(object)
        }
        objectiveSummary.name = "result-objective-summary"
        let stars = success ? PuzzleRating.stars(shotsRemaining: shots, budget: attemptShotBudget) : 0
        for index in 0..<PuzzleRating.maximumStars {
            let star = feedbackStar(radius: index == 2 ? 26 : 20, earned: index < stars)
            star.name = "result-star-\(index)"; star.position = CGPoint(x: CGFloat(index - 2) * 46, y: 105); card.addChild(star)
            if !quiet && index < stars {
                star.setScale(0.05)
                star.run(.sequence([.wait(forDuration: 0.12 + Double(index) * 0.12), .scale(to: 1.15, duration: 0.13), .scale(to: 1, duration: 0.1)]))
            }
        }
        let rating = feedbackText("\(stars) out of \(PuzzleRating.maximumStars) stars", size: 15, at: CGPoint(x: 0, y: 60), parent: card)
        rating.name = "result-star-rating"
        let ratingHelp = success ? (stars == PuzzleRating.maximumStars ? "Top rating!" : PuzzleRating.fiveStarHint(budget: attemptShotBudget)) : "Complete the objective to earn stars."
        let ratingCaption = feedbackText(ratingHelp, size: 10, at: CGPoint(x: 0, y: 35), parent: card)
        ratingCaption.preferredMaxLayoutWidth = 180
        for (index, kind) in [Companion.Kind.animal, .human].enumerated() {
            let area = level / LevelCatalog.levelsPerArea
            let host = FestivalHost.all.first { $0.area == area }
            let neighbor = FestivalNeighbor.all.first { $0.area == area }
            let residentTexture = host.map { atlasTexture("festival-hosts", index: $0.portraitIndex) } ?? neighbor.map { neighborTexture($0) }
            let portrait = SKSpriteNode(texture: kind == .human && residentMilestone != nil ? residentTexture ?? companionTexture(progress.selected(kind), frame: 0) : companionTexture(progress.selected(kind), frame: 0), size: CGSize(width: 56, height: 56))
            if kind == .human && residentMilestone != nil { portrait.name = "milestone-resident" }
            portrait.position = CGPoint(x: index == 0 ? -120 : 120, y: 40); card.addChild(portrait)
        }
        let scoreText = feedbackText("Score \(score)", size: 22, at: CGPoint(x: 0, y: -21), parent: card)
        scoreText.name = "result-score"
        if success && !quiet {
            let finalScore = score
            scoreText.run(.customAction(withDuration: 0.5) { [weak scoreText] _, elapsed in
                scoreText?.text = "Score \(Int(Double(finalScore) * min(1, Double(elapsed) / 0.5)))"
            })
        }
        let reward = SKShapeNode(rectOf: CGSize(width: 298, height: 49), cornerRadius: 15)
        reward.name = "result-earned"; reward.position.y = -65
        reward.fillColor = UIColor(red: 1, green: 0.86, blue: 0.43, alpha: 1)
        FestivalStyle.finish(reward, as: .reward); card.addChild(reward)
        let rewardSymbol = completedQuest?.rewardSymbol ?? (earnedCourtyardSouvenir ? FestivalCelebration.forArea(level / LevelCatalog.levelsPerArea).symbol : !earnedMedals.isEmpty ? "medal.fill" : "star.fill")
        let icon = questIcon(rewardSymbol, size: 28, color: .systemOrange)
        icon.position.x = -123; reward.addChild(icon)
        let rewardTitle = !success ? "Another chance!" : completedQuest != nil ? "Side quest complete!" : earnedCourtyardSouvenir ? "Courtyard keepsake earned!" : !earnedMedals.isEmpty ? "Festival medal earned!" : "Saved-shot bonus +\(shots * 25)"
        let rewardHeading = feedbackText(rewardTitle, size: 14, at: CGPoint(x: 12, y: 8), parent: reward)
        rewardHeading.numberOfLines = 1; fitLabel(rewardHeading, width: 232)
        let rewardDetail = !success ? "Swap or try a wall bounce" : completedQuest?.rewardSummary ?? (earnedCourtyardSouvenir ? FestivalCelebration.forArea(level / LevelCatalog.levelsPerArea).souvenir : newBest ? "New best score!" : challengeMode ? "Challenge puzzle" : "Best \(progress.bestScore(level)) • \(shots) shots saved")
        let rewardCaption = feedbackText(rewardDetail, size: 12, at: CGPoint(x: 12, y: -11), parent: reward)
        rewardCaption.numberOfLines = 1; fitLabel(rewardCaption, width: 232)
        let detail: String
        if !success {
            detail = activeLevel.retryHint(board: board, goal: puzzleGoal, consecutiveLosses: challengeMode ? 0 : progress.levelResults(level).consecutiveLosses)
                ?? "Your next attempt starts with a fresh board."
        }
        else if completedQuest != nil { detail = "Your reward is ready to view." }
        else if let residentMilestone { detail = residentMilestone + (revealedArea.map { " • Discovered: " + LevelCatalog.areas[$0].name } ?? "") }
        else if challengeMode { detail = progress.challengeWon(level / LevelCatalog.levelsPerArea) ? "Challenge ribbon earned! View it on the map." : "Earn five stars to collect the challenge ribbon." }
        else if let revealedArea { detail = "Discovered: " + LevelCatalog.areas[revealedArea].name }
        else if earnedCourtyardSouvenir { detail = "Keepsake saved in your Festival Album." }
        else if activeLevel.isMilestone { detail = progress.hasSouvenir(area: level / LevelCatalog.levelsPerArea) ? "Your courtyard souvenir is in the Album." : "Clear all 20 courtyard levels to earn its souvenir." }
        else { detail = status.text ?? "Beautiful popping!" }
        let resultDetail = feedbackText(detail, size: 13, at: CGPoint(x: 0, y: -116), parent: card)
        resultDetail.name = "result-detail"
        let next: String
        if !success { next = progress.lives(for: level, challenge: challengeMode).available > 0 ? "Try again" : "Wait for a try" }
        else if completedQuest != nil { next = "Collect reward" }
        else if let buddy = progress.pendingBuddy { next = "Meet " + buddy.name }
        else if challengeMode { next = "Back to map" }
        else if level == LevelCatalog.levelCount - 1 { next = "Celebrate!" }
        else { next = "Next • Level \(level + 2)" }
        if !success {
            let state = progress.lives(for: level, challenge: challengeMode)
            let tries = feedbackText("\(state.available)/5 tries" + (state.available < 5 ? " • +1 in " + state.countdown(at: Date()) : ""), size: 12, at: CGPoint(x: 0, y: -146), parent: card)
            tries.name = "result-tries"
        }
        menuButton(next, name: "result-next", point: CGPoint(x: 0, y: -180), parent: card, width: 284, height: 52)
        if success {
            for bubble in nodes.values { bubble.run(.fadeAlpha(to: 0.25, duration: quiet ? 0 : 0.25)) }
            let confetti = SKNode(); confetti.name = "victory-confetti"; confetti.zPosition = 22; gameRoot.addChild(confetti)
            let colors: [UIColor] = [.systemPink, .systemYellow, .systemTeal, .systemOrange]
            for index in 0..<(quiet ? 0 : 22) {
                let piece = SKShapeNode(rectOf: CGSize(width: 5, height: 9), cornerRadius: 1)
                piece.position = CGPoint(x: 35 + CGFloat(index) * 15, y: 677 + CGFloat(index % 3) * 19)
                piece.fillColor = colors[index % colors.count]; piece.strokeColor = .clear; confetti.addChild(piece)
                piece.run(.sequence([.group([.moveBy(x: index.isMultiple(of: 2) ? -20 : 20, y: -390, duration: 1.25), .rotate(byAngle: 3, duration: 1.25), .fadeOut(withDuration: 1.25)]), .removeFromParent()]))
            }
            confetti.run(.sequence([.wait(forDuration: 1.4), .removeFromParent()]))
        }
    }

    func deliverRewardArtwork(_ artwork: SKNode, on parent: SKNode, to destination: CGPoint) {
        guard !FestivalStyle.quiet, let delivery = artwork.copy() as? SKNode else { return }
        delivery.name = "reward-delivery"; delivery.zPosition = 8
        delivery.removeAllActions(); parent.addChild(delivery)
        let scale = delivery.xScale
        let travel = SKAction.move(to: destination, duration: 0.5); travel.timingMode = .easeInEaseOut
        delivery.run(.sequence([.wait(forDuration: 0.9), .group([travel, .scale(to: scale * 0.24, duration: 0.5), .fadeOut(withDuration: 0.5)]), .removeFromParent()]))
    }

    func rescueObject(kind: PuzzleObjective) -> SKNode {
        if kind == .charms {
            let object = SKNode()
            let pouch = SKShapeNode(rectOf: CGSize(width: 17, height: 21), cornerRadius: 4)
            pouch.fillColor = .systemPink; pouch.strokeColor = .systemPurple; pouch.lineWidth = 1.5
            object.addChild(pouch)
            let flower = questIcon("sparkles", size: 10, color: .white); object.addChild(flower)
            let cord = SKShapeNode(ellipseOf: CGSize(width: 9, height: 7))
            cord.position.y = 13; cord.strokeColor = .systemOrange; cord.lineWidth = 2
            object.addChild(cord)
            return object
        }
        guard kind == .lanterns else { return questIcon(kind.symbol, size: 22, color: .systemPink) }
        let object = SKNode()
        let lantern = SKShapeNode(rectOf: CGSize(width: 17, height: 21), cornerRadius: 6)
        lantern.fillColor = .systemOrange; lantern.strokeColor = .systemRed; lantern.lineWidth = 1.5
        object.addChild(lantern)
        for x in [CGFloat(-4), 0, 4] {
            let rib = SKShapeNode(rectOf: CGSize(width: 1, height: 17))
            rib.position.x = x; rib.fillColor = .systemYellow; rib.strokeColor = .clear; object.addChild(rib)
        }
        for y in [CGFloat(-11), 11] {
            let cap = SKShapeNode(rectOf: CGSize(width: 12, height: 3), cornerRadius: 1)
            cap.position.y = y; cap.fillColor = .brown; cap.strokeColor = .clear; object.addChild(cap)
        }
        return object
    }

    func rescueEffect(at location: CGPoint, order: Int = 0, completing: Bool = false) {
        let icon = rescueObject(kind: puzzleGoal.kind)
        icon.name = "rescue-flight"; icon.position = location; icon.zPosition = 24; icon.setScale(1.3); gameRoot.addChild(icon)
        let halo = SKShapeNode(circleOfRadius: 22)
        halo.position = location; halo.strokeColor = .systemYellow; halo.lineWidth = 3; halo.zPosition = 14
        gameRoot.addChild(halo)
        let quietHalo = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        halo.run(.sequence([.group([.scale(to: quietHalo ? 1 : 1.7, duration: 0.3), .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        if quiet { icon.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()])); return }
        let path = CGMutablePath(); path.move(to: location)
        path.addQuadCurve(to: completing ? CGPoint(x: 50, y: 583) : GameplayHUDLayout.rescueDestination, control: CGPoint(x: 52, y: max(710, location.y + 35)))
        icon.run(.sequence([.wait(forDuration: Double(order) * 0.07), .group([.follow(path, asOffset: false, orientToPath: false, duration: 0.48), .scale(to: 0.8, duration: 0.48)]), .run { [weak self] in
            guard !completing else { return }
            self?.gameRoot.childNode(withName: "quest-objective")?.run(.sequence([.scale(to: 1.06, duration: 0.1), .scale(to: 1, duration: 0.1)]), withKey: "rescue-pulse")
        }, .fadeOut(withDuration: 0.1), .removeFromParent()]))
    }

    func celebrateArea() {
        let style = FestivalCelebration.forArea(level / LevelCatalog.levelsPerArea)
        let quiet = UIAccessibility.isReduceMotionEnabled || ProcessInfo.processInfo.isLowPowerModeEnabled
        let colors: [UIColor] = [.systemPink, .systemOrange, .systemTeal, .systemGreen, .systemYellow]
        for index in 0..<(quiet ? 3 : 14) {
            let charm = questIcon(style.symbol, size: quiet ? 15 : 12, color: colors[style.rawValue])
            charm.position = CGPoint(x: 44 + CGFloat(index) * (quiet ? 150 : 23), y: 710)
            charm.name = "area-celebration"; charm.zPosition = 19; gameRoot.addChild(charm)
            let drift = quiet ? SKAction.wait(forDuration: 0.6) : .moveBy(x: index % 2 == 0 ? 18 : -18, y: style == .lanterns ? 60 : -220, duration: 1.25)
            charm.run(.sequence([.group([drift, .fadeOut(withDuration: quiet ? 0.6 : 1.25)]), .removeFromParent()]))
        }
    }

    @discardableResult
    func addMapConversation(to overlay: SKNode) -> Bool {
        mapConversationArea = [mapArea, mapArea - 1].first { $0 >= 0 && progress.hasSouvenir(area: $0) && !progress.collection.readConversations.contains($0) }
        guard let area = mapConversationArea else { return false }
        let host = FestivalHost.all.first { $0.area == area }
        let neighbor = FestivalNeighbor.all.first { $0.area == area }
        let compact = mapArea < FestivalHost.all.count
        let card = panel(width: 112, height: compact ? 60 : 76, point: CGPoint(x: 70, y: compact ? 420 : 576), parent: overlay)
        card.name = "map-chat-dismiss"
        label(host?.name ?? neighbor?.name ?? "Your buddies", size: 14, point: CGPoint(x: 0, y: compact ? 16 : 21), parent: card)
        let words = SKLabelNode(fontNamed: "AvenirNext-Medium")
        let greeting = host?.encouragement ?? neighbor?.greeting ?? "What a lovely festival stop!"
        words.text = greeting.count <= 28 ? greeting : "What a lovely festival stop!"
        words.fontSize = compact ? 12 : 14; words.numberOfLines = 2; words.preferredMaxLayoutWidth = 100
        words.verticalAlignmentMode = .center; words.position.y = compact ? -2 : -4; card.addChild(words)
        label("Tap to close", size: 10, point: CGPoint(x: 0, y: compact ? -24 : -32), parent: card)
        return true
    }

    func addEarnedSouvenir(to overlay: SKNode, markers: [CGPoint]) {
        guard progress.hasSouvenir(area: mapArea), let location = FestivalMapLayout.souvenirPosition(markers: markers) else { return }
        let token = questIcon(FestivalCelebration.forArea(mapArea).symbol, size: 21, color: .systemYellow)
        token.position = location; overlay.addChild(token)
    }

    func showAlbum() {
        menuKind = "album"
        albumArea = min(LevelCatalog.areas.count - 1, max(0, albumArea))
        albumSelection = min(LevelCatalog.areas.count - 1, max(0, albumSelection))
        let overlay = makeMenu(background: LevelCatalog.areas[mapArea].background)
        panel(width: 350, height: 666, point: CGPoint(x: 195, y: 451), parent: overlay)
        label("Festival Album", size: 29, point: CGPoint(x: 195, y: 742), parent: overlay)
        if albumTab == "souvenirs" {
            label("Finish courtyards. Collect keepsakes.", size: 15, point: CGPoint(x: 195, y: 649), parent: overlay)
            let souvenirHelpY = min(CGFloat(380), 520 - CGFloat((LevelCatalog.areas.count - 1) / 5) * 94)
            label("Clear all 20 levels to earn each souvenir.", size: 14, point: CGPoint(x: 195, y: souvenirHelpY), parent: overlay)
        }
        for (index, tab) in ["souvenirs", "cast", "replay"].enumerated() {
            let title = tab == "souvenirs" ? "Souvenirs" : tab == "cast" ? "Cast" : "Replay"
            let name = "album-tab-" + tab
            menuButton(title, name: name, point: CGPoint(x: 85 + CGFloat(index) * 110, y: 687), parent: overlay, width: 102, height: 40)
            (overlay.childNode(withName: name) as? SKShapeNode)?.strokeColor = albumTab == tab ? .systemYellow : .white
        }
        if albumTab == "souvenirs" {
            for area in LevelCatalog.areas.indices {
                let card = panel(width: 55, height: 68, point: CGPoint(x: 67 + CGFloat(area % 5) * 64, y: 590 - CGFloat(area / 5) * 94), parent: overlay)
                card.name = "album-souvenir-\(area)"
                let owned = progress.hasSouvenir(area: area)
                card.addChild(questIcon(owned ? FestivalCelebration.forArea(area).symbol : "lock.fill", size: 26, color: owned ? .systemYellow : .systemGray3))
                label("Area \(area + 1)", size: 10, point: CGPoint(x: 0, y: -26), parent: card)
                card.strokeColor = area == albumSelection ? .systemYellow : .white
            }
            let discovered = albumSelection <= progress.unlockedLevel / LevelCatalog.levelsPerArea
            let owned = progress.hasSouvenir(area: albumSelection)
            let preview = questIcon(discovered ? FestivalCelebration.forArea(albumSelection).symbol : "lock.fill", size: 39, color: owned ? .systemYellow : .white)
            preview.name = "album-keepsake-preview"; preview.position = CGPoint(x: 195, y: 282); overlay.addChild(preview)
            label(discovered ? LevelCatalog.areas[albumSelection].name : "Mystery courtyard", size: 18, point: CGPoint(x: 195, y: 234), parent: overlay)
            label(discovered ? FestivalCelebration.forArea(albumSelection).souvenir : "A keepsake awaits", size: 15, point: CGPoint(x: 195, y: 199), parent: overlay)
            let first = albumSelection * LevelCatalog.levelsPerArea
            let cleared = (first..<first + LevelCatalog.levelsPerArea).filter { progress.stars($0) > 0 }.count
            label(owned ? "Collected!" : "\(cleared)/\(LevelCatalog.levelsPerArea) levels cleared", size: 13, point: CGPoint(x: 195, y: 166), parent: overlay)
            let track = SKShapeNode(rectOf: CGSize(width: 160, height: 6), cornerRadius: 3)
            track.position = CGPoint(x: 195, y: 149); track.fillColor = .systemGray; track.strokeColor = .clear; overlay.addChild(track)
            let fraction = owned ? 1 : CGFloat(cleared) / CGFloat(LevelCatalog.levelsPerArea)
            if fraction > 0 {
                let fill = SKShapeNode(rectOf: CGSize(width: 160 * fraction, height: 6), cornerRadius: 3)
                fill.position.x = -80 + 80 * fraction; fill.fillColor = .systemYellow; fill.strokeColor = .clear; track.addChild(fill)
            }
        } else if albumTab == "cast" {
            var cast: [(String, SKTexture, Bool)] = Companion.all.map { ($0.name, companionTexture($0, frame: 0), progress.unlocked($0)) }
            cast += FestivalHost.all.map { ($0.name, atlasTexture("festival-hosts", index: $0.portraitIndex), progress.hasMet($0)) }
            cast += FestivalNeighbor.all.filter { (5..<LevelCatalog.areas.count).contains($0.area) }.map { ($0.name, neighborTexture($0), progress.hasMet($0)) }
            albumPage = min(max(0, (cast.count - 1) / 6), max(0, albumPage))
            for (local, entry) in cast.dropFirst(albumPage * 6).prefix(6).enumerated() {
                let tile = panel(width: 140, height: 132, point: CGPoint(x: local % 2 == 0 ? 111 : 279, y: 574 - CGFloat(local / 2) * 151), parent: overlay)
                let portrait = SKSpriteNode(texture: entry.1, size: CGSize(width: 88, height: 88))
                portrait.position.y = 11; portrait.alpha = entry.2 ? 1 : 0.22; tile.addChild(portrait)
                label(entry.0, size: 14, point: CGPoint(x: 0, y: -48), parent: tile)
                if !entry.2 { tile.addChild(questIcon("lock.fill", size: 22, color: .white)) }
            }
            label("Page \(albumPage + 1)/\((cast.count + 5) / 6) • Meet friends to collect portraits", size: 12, point: CGPoint(x: 195, y: 190), parent: overlay)
        } else {
            label("Area \(albumArea + 1) • Optional replay goals", size: 18, point: CGPoint(x: 195, y: 649), parent: overlay)
            label("Medals: no boosters • 3 bank matches • 5 stars", size: 11, point: CGPoint(x: 195, y: 628), parent: overlay)
            for (index, filter) in ReplayFilter.allCases.enumerated() {
                let name = "album-filter-" + filter.rawValue
                menuButton(filter.rawValue, name: name, point: CGPoint(x: 85 + CGFloat(index) * 110, y: 605), parent: overlay, width: 102, height: 36)
                (overlay.childNode(withName: name) as? SKShapeNode)?.strokeColor = filter == replayFilter ? .systemYellow : .white
            }
            let levels = progress.replayLevels(area: albumArea, filter: replayFilter)
            for (row, index) in levels.enumerated() {
                let stars = progress.stars(index), medals = progress.medals(for: index).count
                menuButton("\(index + 1) • \(stars)/5★ • \(medals)/3 medals", name: "level-\(index)", point: CGPoint(x: row % 2 == 0 ? 103 : 287, y: 552 - CGFloat(row / 2) * 38), parent: overlay, width: 172, height: 34)
            }
            if levels.isEmpty { label("All caught up in this area!", size: 19, point: CGPoint(x: 195, y: 434), parent: overlay) }
        }
        if albumTab != "souvenirs" {
            menuButton("Previous", name: "album-prev", point: CGPoint(x: 105, y: 129), parent: overlay, width: 152, height: 44)
            menuButton("Next", name: "album-next", point: CGPoint(x: 285, y: 129), parent: overlay, width: 152, height: 44)
        }
        menuButton("Explore Map", name: "album-back", point: CGPoint(x: 195, y: 65), parent: overlay, height: 44)
    }

    func decoratePuzzleBubbles() {
        for (cell, node) in nodes {
            for name in ["puzzle-target", "puzzle-armor", "puzzle-blocker"] { node.childNode(withName: name)?.removeFromParent() }
            if board.blockers.contains(cell) {
                let block = SKShapeNode(rectOf: CGSize(width: 34, height: 34), cornerRadius: 5)
                block.name = "puzzle-blocker"; block.fillColor = .brown; block.strokeColor = .systemOrange
                block.lineWidth = 3; block.zPosition = 3
                // Wood grain and brass nails distinguish an obstacle from a close button.
                for y in [CGFloat(-8), 0, 8] {
                    let grain = SKShapeNode(rectOf: CGSize(width: 26, height: 1.5), cornerRadius: 0.7)
                    grain.position.y = y; grain.fillColor = UIColor(red: 0.39, green: 0.20, blue: 0.08, alpha: 1)
                    grain.strokeColor = .clear; block.addChild(grain)
                }
                for x in [CGFloat(-11), 11] {
                    for y in [CGFloat(-11), 11] {
                        let nail = SKShapeNode(circleOfRadius: 1.8)
                        nail.position = CGPoint(x: x, y: y); nail.fillColor = .systemYellow
                        nail.strokeColor = .clear; block.addChild(nail)
                    }
                }
                node.addChild(block)
            } else if board.armor.contains(cell) {
                let ring = SKShapeNode(circleOfRadius: 18)
                ring.name = "puzzle-armor"; ring.fillColor = .clear; ring.strokeColor = .systemGray3
                ring.lineWidth = 5; ring.zPosition = 3; node.addChild(ring)
                let shield = questIcon("shield.fill", size: 12, color: .white)
                shield.position = CGPoint(x: 12, y: 12); ring.addChild(shield)
            }
            if puzzleGoal.remaining.contains(cell) {
                // Center the object; the original color remains visible around its ivory window.
                let badge = SKShapeNode(circleOfRadius: 14)
                badge.name = "puzzle-target"; badge.fillColor = UIColor(red: 1, green: 0.97, blue: 0.84, alpha: 0.97)
                badge.strokeColor = .white; badge.lineWidth = 1.5; badge.zPosition = 5
                let rim = SKShapeNode(circleOfRadius: 22)
                rim.name = "target-rim"; rim.fillColor = .clear; rim.strokeColor = .systemYellow; rim.lineWidth = 3
                badge.addChild(rim)
                let object = rescueObject(kind: puzzleGoal.kind)
                object.name = "rescue-object"; object.zPosition = 1; badge.addChild(object)
                let sparkle = questIcon("sparkle", size: 9, color: .white)
                sparkle.position = CGPoint(x: 15, y: 15); badge.addChild(sparkle)
                node.addChild(badge)
            }
        }
    }

    func showPlayResults() {
        menuKind = "play-results"
        let overlay = makeMenu(background: LevelCatalog.areas[resultsArea].background)
        panel(width: 346, height: 606, point: CGPoint(x: 195, y: 455), parent: overlay)
        label("Play results", size: 28, point: CGPoint(x: 195, y: 719), parent: overlay)
        label("\(profiles.active.name) • Area \(resultsArea + 1)", size: 17, point: CGPoint(x: 195, y: 684), parent: overlay)
        label("Level     Attempts     Wins*     Saved*", size: 14, point: CGPoint(x: 195, y: 644), parent: overlay)
        for local in 0..<LevelCatalog.levelsPerArea {
            let index = resultsArea * LevelCatalog.levelsPerArea + local
            let result = progress.levelResults(index)
            let y = CGFloat(608 - local * 18)
            label("\(index + 1)", size: 15, point: CGPoint(x: 55, y: y), parent: overlay)
            label("\(progress.attempts(index))", size: 15, point: CGPoint(x: 137, y: y), parent: overlay)
            label("\(result.wins)", size: 15, point: CGPoint(x: 219, y: y), parent: overlay)
            label(result.wins > 0 ? "\(result.averageSaved)" : "—", size: 15, point: CGPoint(x: 311, y: y), parent: overlay)
        }
        let first = resultsArea * LevelCatalog.levelsPerArea
        let summary = CourtyardPlaySummary(results: (first..<first + LevelCatalog.levelsPerArea).map { progress.levelResults($0) })
        label(summary.runs == 0 ? "Play a few puzzles to see your results" : "\(summary.runs) finished runs • \(summary.winPercent)% wins • \(summary.averageSaved) shots saved/win", size: 11, point: CGPoint(x: 195, y: 225), parent: overlay)
        label(String(format: "Boosters per run: %.1f • %d levels played", summary.boostersPerRun, summary.playedLevels), size: 11, point: CGPoint(x: 195, y: 203), parent: overlay)
        label("*Current balance • On this device only", size: 11, point: CGPoint(x: 195, y: 181), parent: overlay)
        menuButton("Previous", name: "results-prev", point: CGPoint(x: 105, y: 128), parent: overlay, width: 156, height: 44)
        menuButton("Next", name: "results-next", point: CGPoint(x: 285, y: 128), parent: overlay, width: 156, height: 44)
        menuButton("Settings", name: "results-back", point: CGPoint(x: 195, y: 65), parent: overlay, height: 44)
    }

    func decorateMechanism() {
        let linkage = SKShapeNode(rectOf: CGSize(width: 72, height: 8), cornerRadius: 3)
        linkage.position = CGPoint(x: 249, y: 153)
        linkage.fillColor = UIColor(red: 0.83, green: 0.61, blue: 0.33, alpha: 1)
        FestivalStyle.finish(linkage, as: .brass)
        gameRoot.addChild(linkage)
        let wheelSupport = SKShapeNode(rectOf: CGSize(width: 9, height: 22), cornerRadius: 3)
        wheelSupport.position = CGPoint(x: 290, y: 159)
        wheelSupport.fillColor = linkage.fillColor
        FestivalStyle.finish(wheelSupport, as: .brass)
        gameRoot.addChild(wheelSupport)
        let wheel = SKNode()
        wheel.name = "handwheel"
        wheel.position = CGPoint(x: 290, y: 173)
        wheel.zPosition = 3
        let rim = SKShapeNode(circleOfRadius: 24)
        rim.fillColor = UIColor(red: 0.36, green: 0.23, blue: 0.18, alpha: 1)
        rim.strokeColor = UIColor(red: 1, green: 0.82, blue: 0.5, alpha: 1)
        FestivalStyle.finish(rim, as: .wood); rim.lineWidth = 3
        wheel.addChild(rim)
        let innerRim = SKShapeNode(circleOfRadius: 20)
        innerRim.fillColor = .clear; innerRim.strokeColor = FestivalStyle.brass.withAlphaComponent(0.42)
        innerRim.lineWidth = 1; wheel.addChild(innerRim)
        for index in 0..<6 {
            let spoke = SKShapeNode(rectOf: CGSize(width: 4, height: 37), cornerRadius: 2)
            spoke.zRotation = CGFloat(index) * .pi / 3
            spoke.fillColor = UIColor(red: 0.89, green: 0.69, blue: 0.4, alpha: 1)
            FestivalStyle.finish(spoke, as: .brass)
            wheel.addChild(spoke)
        }
        let hub = SKShapeNode(circleOfRadius: 4)
        hub.fillColor = FestivalStyle.brass; FestivalStyle.finish(hub, as: .brass)
        wheel.addChild(hub)
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
        box.fillColor = UIColor(red: 1, green: 0.97, blue: 0.85, alpha: 1)
        box.strokeColor = .systemOrange; box.lineWidth = 2
        box.name = name; box.zPosition = 11
        // Use the same rasterized, explicit tint as the rest of the game icons.
        let icon = questIcon(symbol, size: 28, color: UIColor(white: 0.45, alpha: 1))
        box.addChild(icon)
    }

    func boosterButton(_ kind: BubbleShot, name: String, point: CGPoint) {
        let box = SKShapeNode(circleOfRadius: 25)
        box.position = point
        box.name = name
        // The bubble artwork is the button; the clear shape preserves its hit area.
        box.fillColor = .clear
        box.strokeColor = .clear
        box.lineWidth = 1.5
        box.addChild(shotNode(kind))
        let badge = SKShapeNode(circleOfRadius: 10)
        badge.fillColor = .darkGray
        badge.strokeColor = .white
        badge.position = CGPoint(x: 17, y: -12)
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
        FestivalStyle.reveal(gameRoot)
        updateControlLayout()
        showPracticeHint()
        showPuzzleCoachIfNeeded()
    }

    func showLives() {
        menuKind = "lives"
        let overlay = makeMenu(background: LevelCatalog.level(level).background)
        panel(width: 342, height: 358, point: CGPoint(x: 195, y: 450), parent: overlay)
        label("Level \(level + 1) • Tries", size: 27, point: CGPoint(x: 195, y: 580), parent: overlay)
        for index in 0..<LevelLives.capacity {
            let heart = questIcon("heart.fill", size: 29, color: .systemPink)
            heart.name = "life-heart-\(index)"; heart.position = CGPoint(x: 115 + CGFloat(index) * 40, y: 531); overlay.addChild(heart)
        }
        let count = SKLabelNode(fontNamed: "AvenirNext-Bold")
        count.name = "lives-count"; count.fontSize = 23; count.position = CGPoint(x: 195, y: 480); overlay.addChild(count)
        let timer = SKLabelNode(fontNamed: "AvenirNext-Medium")
        timer.name = "lives-countdown"; timer.fontSize = 19; timer.position = CGPoint(x: 195, y: 441); overlay.addChild(timer)
        let help = paragraph("One try returns every five minutes. You can explore the map or play another unlocked level while you wait.", y: 377, parent: overlay, width: 290)
        help.fontSize = 15
        menuButton("Play level \(level + 1)", name: "lives-play", point: CGPoint(x: 195, y: 303), parent: overlay, width: 284, height: 50)
        menuButton("Explore Map", name: "lives-map", point: CGPoint(x: 195, y: 220), parent: overlay, height: 48)
        refreshLivesScreen()
    }

    func refreshLivesScreen() {
        guard menuKind == "lives", let overlay = levelMenu else { return }
        let now = Date()
        let state = progress.lives(for: level, challenge: challengeMode, now: now)
        (overlay.childNode(withName: "lives-count") as? SKLabelNode)?.text = "\(state.available)/5 tries ready"
        (overlay.childNode(withName: "lives-countdown") as? SKLabelNode)?.text = state.available == 5 ? "All tries restored!" : "+1 try in " + state.countdown(at: now)
        let saved = progress.checkpoint
        let resumable = saved?.level == level && (saved?.challenge ?? false) == challengeMode && (saved?.hasStartedTry ?? false)
        let play = overlay.childNode(withName: "lives-play")
        play?.isHidden = state.available == 0 && !resumable
        if let title = play?.children.compactMap({ $0 as? SKLabelNode }).first { title.text = resumable ? "Resume puzzle" : "Play level \(level + 1)" }
        for index in 0..<LevelLives.capacity { overlay.childNode(withName: "life-heart-\(index)")?.alpha = index < state.available ? 1 : 0.2 }
    }

    func beginSelectedLevel() {
        let area = level / LevelCatalog.levelsPerArea
        if !challengeMode && shouldWelcomeCourtyard(area) { showCourtyardWelcome(area: area, action: "play"); return }
        if !ProcessInfo.processInfo.arguments.contains(where: { $0.hasSuffix("-preview") }),
           progress.lives(for: level, challenge: challengeMode).available == 0 { showLives(); return }
        hasStartedPuzzle = true
        closeMenu()
        startLevel()
        presentPuzzleIntroduction()
    }

    private func resumeSavedPuzzle() {
        guard let saved = progress.checkpoint else { showLevels(); return }
        level = saved.level
        challengeMode = saved.challenge ?? false
        if !challengeMode && shouldWelcomeCourtyard(level / LevelCatalog.levelsPerArea) {
            showCourtyardWelcome(area: level / LevelCatalog.levelsPerArea, action: "resume"); return
        }
        if !saved.hasStartedTry && progress.lives(for: level, challenge: challengeMode).available == 0 { showLives(); return }
        hasStartedPuzzle = true
        closeMenu()
        startLevel(restoring: true)
        presentPuzzleIntroduction()
    }

    private func presentPuzzleIntroduction() {
        if !progress.tutorialSeen {
            tutorialPage = 0
            tutorialFromSettings = false
            returnMenu = "game"
            showTutorial()
        } else if let special = progress.nextSpecialLesson(in: board) {
            showSpecialHelp(special)
        } else { showPuzzleCoachIfNeeded() }
    }

    @discardableResult
    func paragraph(_ text: String, y: CGFloat, parent: SKNode, width: CGFloat = 300) -> SKLabelNode {
        let node = SKLabelNode(fontNamed: "AvenirNext-Medium")
        node.text = text
        node.fontSize = 18
        node.numberOfLines = 0
        node.preferredMaxLayoutWidth = width
        node.verticalAlignmentMode = .center
        node.position = CGPoint(x: 195, y: y)
        parent.addChild(node)
        return node
    }

    internal func showHost(_ host: FestivalHost) {
        guard progress.hostIsAvailable(host) else {
            status.text = "Reach level \(host.area * LevelCatalog.levelsPerArea + 1) to meet \(host.name)"
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
        menuButton(dialoguePage == host.introduction.count - 1 ? "Let's go!" : "Next", name: "dialogue-next", point: CGPoint(x: 195, y: 142), parent: overlay, height: 44)
        menuButton("Back", name: "dialogue-back", point: CGPoint(x: 195, y: 84), parent: overlay, width: 132, height: 44)
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
        let overlay = makeMenu(background: LevelCatalog.areas[level / LevelCatalog.levelsPerArea].background)
        panel(width: 342, height: 518, point: CGPoint(x: 195, y: 442), parent: overlay)
        label("Settings", size: 31, point: CGPoint(x: 195, y: 649), parent: overlay)
        for (index, setting) in GameSetting.allCases.enumerated() {
            menuButton("\(setting.title): \(progress.enabled(setting) ? "On" : "Off")", name: "setting-\(setting.rawValue)", point: CGPoint(x: 195, y: 606 - CGFloat(index) * 58), parent: overlay, height: 44)
        }
        menuButton("How to play", name: "tutorial", point: CGPoint(x: 195, y: 250), parent: overlay, height: 44)
        menuButton("Sound levels", name: "sound-levels", point: CGPoint(x: 195, y: 193), parent: overlay, height: 44)
        menuButton("Play results", name: "play-results", point: CGPoint(x: 195, y: 136), parent: overlay, width: 220, height: 44)
        menuButton(returnMenu == "game-menu" ? "Back to puzzle menu" : "Start Menu", name: returnMenu == "game-menu" ? "back" : "home", point: CGPoint(x: 195, y: 78), parent: overlay, width: 270, height: 50)
    }

    func showTutorial() {
        menuKind = "tutorial"
        let overlay = makeMenu(background: "festival-courtyard")
        let titles = ["Aim and pop", "Try a wall bounce", "A little extra help", "Festival surprises"]
        let bodies = ["Drag above the launcher to aim. Release to shoot. Drag back down toward the launcher to cancel. Match three bubbles with the same color and symbol.",
                      "Use the walls to reach tricky spots. Pop a supporting group to drop the bubbles below it. Finish the objective shown above the board to win. Tap the bubble your buddy holds to swap it with the loaded bubble.",
                      "Rainbow pops the largest neighboring color group. Bomb clears nearby bubbles. Their badges show how many you have. Tap one to prepare it, then shoot to use it. Tap it again to cancel. Hold an icon for help!",
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
        else if returnMenu == "game", FestivalHost.all.indices.contains(level / LevelCatalog.levelsPerArea), !progress.hasMet(FestivalHost.all[level / LevelCatalog.levelsPerArea]) {
            menuKind = "game"
            showHost(FestivalHost.all[level / LevelCatalog.levelsPerArea])
        } else { restoreMenu() }
    }

    func showMapBuddies(locked friend: Companion? = nil) {
        showLevels()
        menuKind = "map-buddies"
        guard let overlay = levelMenu else { return }
        for child in overlay.children { child.zPosition -= 20 }
        panel(width: 360, height: 342, point: CGPoint(x: 195, y: 258), parent: overlay)
        label("Shooter & Buddy", size: 24, point: CGPoint(x: 195, y: 397), parent: overlay)
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
        if let friend {
            let notice = panel(width: 342, height: 54, point: CGPoint(x: 195, y: 465), parent: overlay)
            notice.name = "team-unlock-notice"
            label(friend.name, size: 16, point: CGPoint(x: 0, y: 10), parent: notice)
            let requirement = SKLabelNode(fontNamed: "AvenirNext-Medium")
            requirement.text = friend.unlockDescription
            requirement.fontSize = 13; requirement.numberOfLines = 2; requirement.preferredMaxLayoutWidth = 310
            requirement.verticalAlignmentMode = .center; requirement.position.y = -11; notice.addChild(requirement)
        }
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
        if !UIAccessibility.isReduceMotionEnabled && !ProcessInfo.processInfo.isLowPowerModeEnabled { overlay.run(.repeatForever(fireworks)) }
    }

    internal func handleMenu(_ incomingNames: [String]) {
        let names = menuKind == "map-buddies" ? FestivalMenuTargets.buddies(incomingNames) : incomingNames
        if wheelSpinning { return }
        if let token = names.first(where: { $0.hasPrefix("preview-companion-") }),
           let companion = Companion.all.first(where: { "preview-companion-" + $0.id == token }) {
            previewReturnMenu = menuKind; showCompanionPreview(companion); return
        }
        if menuKind == "companion-preview" {
            if names.contains("preview-back") {
                if previewReturnMenu == "courtyard-welcome", let area = courtyardWelcomeArea { showCourtyardWelcome(area: area, action: courtyardWelcomeAction) }
                else if previewReturnMenu == "map-buddies" { showMapBuddies() }
                else { showLevels() }
            }
            return
        }
        if menuKind == "buddy-welcome", !names.contains("buddy-choose"), !names.contains("buddy-later") { dismissCelebrationEffects(); return }
        if menuKind == "map", names.contains("map-current-level") { scrollMap(to: FestivalMapLayout.focusedOffset(local: progress.unlockedLevel - mapArea * LevelCatalog.levelsPerArea)); return }
        if menuKind == "courtyard-welcome" {
            if names.contains("courtyard-welcome-back") { courtyardWelcomeArea = nil; showTitle(); return }
            guard names.contains("courtyard-welcome-explore"), let area = courtyardWelcomeArea else { return }
            progress.markCourtyardWelcomed(area)
            if let host = FestivalHost.all.first(where: { $0.area == area }) { progress.markMet(host) }
            else if let neighbor = FestivalNeighbor.all.first(where: { $0.area == area }) { progress.markMet(neighbor) }
            profiles.persistActive()
            courtyardWelcomeArea = nil
            mapArea = area
            if courtyardWelcomeAction == "play" { beginSelectedLevel() }
            else if courtyardWelcomeAction == "resume" { resumeSavedPuzzle() }
            else { showLevels() }
            return
        }
        if menuKind == "map-buddies", incomingNames.contains("team-unlock-notice") { return }
        if names.contains("lives-play") {
            let saved = progress.checkpoint
            if saved?.level == level && (saved?.challenge ?? false) == challengeMode { resumeSavedPuzzle() }
            else { beginSelectedLevel() }
            return
        }
        if names.contains("lives-map") { mapArea = level / LevelCatalog.levelsPerArea; showLevels(); return }
        if names.contains("result-next") {
            guard levelMenu == nil, gameRoot.childNode(withName: "result") != nil else { return }
            continueAfterResult(); return
        }
        if names.contains("dialogue-back"), let host = introHost {
            if dialoguePage > 0 { dialoguePage -= 1; showHost(host) }
            else { introHost = nil; restoreMenu() }
            return
        }
        if names.contains("neighbor-back") { if neighborFromMap { showLevels() } else { showNeighbors() }; return }
        if names.contains("quest-dialogue-back") {
            if questReturnMenu == "quests" { showQuests(area: questArea) }
            else { mapArea = questArea; showLevels() }
            return
        }
        if names.contains("album-open") { albumTab = "souvenirs"; albumPage = 0; albumArea = mapArea; albumSelection = mapArea; showAlbum(); return }
        if names.contains("album-back") { showLevels(); return }
        if names.contains("album-prev") { if albumTab == "cast" { albumPage = max(0, albumPage - 1) } else { albumArea = max(0, albumArea - 1) }; showAlbum(); return }
        if names.contains("album-next") { if albumTab == "cast" { albumPage += 1 } else { albumArea = min(LevelCatalog.areas.count - 1, albumArea + 1) }; showAlbum(); return }
        if let tab = names.first(where: { $0.hasPrefix("album-tab-") }) { albumTab = String(tab.dropFirst(10)); albumPage = 0; showAlbum(); return }
        if let value = names.first(where: { $0.hasPrefix("album-filter-") }), let filter = ReplayFilter(rawValue: String(value.dropFirst(13))) { replayFilter = filter; showAlbum(); return }
        if let value = names.first(where: { $0.hasPrefix("album-souvenir-") }), let area = Int(value.dropFirst(15)) { albumSelection = area; showAlbum(); return }
        if names.contains("map-chat-dismiss"), let area = mapConversationArea { progress.dismissConversation(area: area); profiles.persistActive(); showLevels(); return }
        if names.contains("game-music"), menuKind == "game-menu" {
            if progress.enabled(.music) && progress.musicVolume > 0 { progress.toggle(.music) }
            else {
                if !progress.enabled(.music) { progress.toggle(.music) }
                if progress.volumeStep(music: true) == 0 { progress.changeVolume(music: true, by: 2) }
            }
            updateMusic()
            profiles.persistActive()
            showGameMenu()
            return
        }
        if names.contains("game-resume") { closeMenu(); return }
        if names.contains("map-resume") { resumeSavedPuzzle(); return }
        if names.contains("game-map") { mapArea = level / LevelCatalog.levelsPerArea; showLevels(); return }
        if names.contains("game-restart") { showRetryPrompt(); return }
        if menuKind == "map-buddies" {
            if names.contains("home") { showTitle(); return }
            if names.contains("map-buddies-close") { showLevels(); return }
            if !names.contains("friends-page") && !names.contains("accessories") && !names.contains(where: { $0.hasPrefix("friend-") }) { showLevels(); return }
        }
        if names.contains("play-results") { resultsArea = level / LevelCatalog.levelsPerArea; showPlayResults(); return }
        if names.contains("results-back") { showSettings(); return }
        if names.contains("results-prev") { resultsArea = max(0, resultsArea - 1); showPlayResults(); return }
        if names.contains("results-next") { resultsArea = min(LevelCatalog.areas.count - 1, resultsArea + 1); showPlayResults(); return }
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
            updateMusic()
            showSettings(); return
        }
        if names.contains("wheel-return") { showWheel(); return }
        if names.contains("new-buddy"), let buddy = progress.pendingBuddy { showBuddyWelcome(buddy); return }
        if menuKind == "buddy-welcome", names.contains("buddy-choose") || names.contains("buddy-later") {
            guard let buddy = welcomedCompanion else { return }
            if names.contains("buddy-choose") { progress.select(buddy) }
            progress.welcome(buddy)
            welcomedCompanion = nil
            if finished { continueAfterResult(showBuddy: false) }
            else { showLevels() }
            return
        }
        if names.contains("saved-progress") { showSavedProgress(); return }
        if names.contains("save-now") {
            saveCheckpoint()
            let saved = profiles.persistActive()
            if saved { progress.markSaved() }
            showSavedProgress(message: saved ? "Backup saved on this iPhone." : "Backup could not be confirmed. Check your iPhone’s free storage.")
            return
        }
        if names.contains("objective-close") { closeMenu(); return }
        if names.contains("neighbors") { if menuKind == "map" { questArea = mapArea }; showNeighbors(); return }
        if let name = names.first(where: { $0.hasPrefix("neighbor-") }), let neighbor = FestivalNeighbor.all.first(where: { "neighbor-\($0.id)" == name }) { showNeighbor(neighbor); return }
        if names.contains("special-ready"), let specialToLearn { progress.markLearned(specialToLearn); closeMenu(); return }
        if names.contains("open-challenge") { showChallenge(); return }
        if names.contains("challenge-play") { level = questArea * LevelCatalog.levelsPerArea; challengeMode = true; beginSelectedLevel(); return }
        if names.contains("sound-levels") { showSoundLevels(); return }
        if names.contains("sound-back") { showSettings(); return }
        if let name = names.first(where: { ["music-up", "music-down", "effects-up", "effects-down"].contains($0) }) {
            progress.changeVolume(music: name.hasPrefix("music"), by: name.hasSuffix("up") ? 1 : -1)
            updateMusic()
            showSoundLevels(); return
        }
        if names.contains("accessories") { showAccessories(); return }
        if names.contains("accessory-back") { showMapBuddies(); return }
        if names.contains("friends-page") { friendsPage = (friendsPage + 1) % ((Companion.all.count + 5) / 6); showMapBuddies(); return }
        if names.contains("pin-none") { progress.adventure.equip(nil); applyCompanionPins(); showAccessories(); return }
        if let name = names.first(where: { $0.hasPrefix("pin-") }), let pin = FestivalPrize(rawValue: String(name.dropFirst(4))) {
            progress.adventure.equip(pin); applyCompanionPins(); showAccessories(); return
        }
        if names.contains("resume-play") { resumeSavedPuzzle(); return }
        if names.contains("retry-confirm") {
            if progress.lives(for: level, challenge: challengeMode).available == 0 { showLives(); return }
            beginSelectedLevel(); return
        }
        if names.contains("retry-cancel") { closeMenu(); return }
        if names.contains("host-quests") { mapArea = introHost?.area ?? mapArea; showLevels(); return }
        if names.contains("quest-list") { showQuests(area: questArea); return }
        if names.contains("quest-back") { mapArea = questArea; showLevels(); return }
        if names.contains("open-wheel") { questArea = mapArea; showWheel(); return }
        if names.contains("wheel-spin") { spinWheel(); return }
        if names.contains("start-continue") {
            if progress.checkpoint != nil { resumeSavedPuzzle() }
            else { mapArea = progress.currentLevel / LevelCatalog.levelsPerArea; showLevels(allowWelcome: true) }
            return
        }
        if names.contains("courtyard-greeting") {
            if let host = FestivalHost.all.first(where: { $0.area == mapArea }) { showHost(host) }
            else if let neighbor = FestivalNeighbor.all.first(where: { $0.area == mapArea }) { showNeighbor(neighbor) }
            return
        }
        if names.contains("continue-stop") {
            level = progress.currentLevel
            if progress.checkpoint != nil { resumeSavedPuzzle() }
            else { challengeMode = false; beginSelectedLevel() }
            return
        }
        if names.contains("quest-accept"), let selectedQuest {
            progress.adventure.accept(selectedQuest, unlockedLevel: progress.unlockedLevel)
            if let host = FestivalHost.all.first(where: { $0.area == selectedQuest.area }) { progress.markMet(host) }
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
        if names.contains("start-adventure") { mapArea = progress.currentLevel / LevelCatalog.levelsPerArea; showLevels(allowWelcome: true) }
        else if names.contains("home") { showTitle() }
        else if names.contains("area-prev") { mapArea = max(0, mapArea - 1); showLevels() }
        else if names.contains("area-next") { mapArea = min(LevelCatalog.areas.count - 1, min(progress.unlockedLevel / LevelCatalog.levelsPerArea + 1, mapArea + 1)); showLevels(allowWelcome: true) }
        else if names.contains("meet-host"), FestivalHost.all.indices.contains(mapArea) {
            let host = FestivalHost.all[mapArea]
            if progress.hostIsAvailable(host) { progress.markMet(host); showQuests(area: mapArea) }
            else if let overlay = levelMenu {
                overlay.childNode(withName: "unlock-message")?.removeFromParent()
                let message = panel(width: 280, height: 32, point: CGPoint(x: 195, y: 139), parent: overlay)
                message.name = "unlock-message"
                label("Reach level \(host.area * LevelCatalog.levelsPerArea + 1) to meet \(host.name)", size: 12, point: CGPoint(x: 0, y: -4), parent: message)
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
            updateMusic()
            showSettings()
        }
        else if let name = names.first(where: { $0.hasPrefix("friend-") }), let friend = Companion.all.first(where: { "friend-\($0.id)" == name }) {
            guard progress.unlocked(friend) else { previewReturnMenu = "map-buddies"; showCompanionPreview(friend); return }
            progress.select(friend)
            progress.welcome(friend)
            if friend.kind == .human { updateOperatorAppearance() }
            showMapBuddies()
        }
        else if let name = names.first(where: { $0.hasPrefix("level-") }), let selected = Int(name.dropFirst(6)), LevelCatalog.levels.indices.contains(selected), selected <= progress.unlockedLevel {
            level = selected
            challengeMode = false
            if progress.checkpoint?.level == level { resumeSavedPuzzle() } else { beginSelectedLevel() }
        }
    }
}
