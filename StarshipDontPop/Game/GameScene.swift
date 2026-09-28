import SpriteKit
import UIKit

struct HUDSnapshot: Equatable {
    var altitude = 0.0
    var velocity = 0.0
    var heat = 0.0
    var fuel = 1.0
    var tilt = 0.0
    var phase: FlightPhase = .pad
    var tier: AltitudeTier = .troposphere
    var score = 0
    var stylePoints = 0
    var throttle = false
    var inWind = false
    var inTurbulence = false
    var stagingPending = false
    var waitingForTouch = true
    var grace = false
}

@MainActor
protocol GameSceneDelegate: AnyObject {
    func gameScene(_ scene: GameScene, didEmit event: GameEvent)
    func gameScene(_ scene: GameScene, didUpdate hud: HUDSnapshot)
    /// Fail animation or orbit celebration is over: show the game-over screen.
    func gameSceneDidFinishRun(_ scene: GameScene)
}

/// Renders a `GameSimulation` and turns touches into throttle. Finger down = throttle up.
final class GameScene: SKScene {
    enum Mode {
        case idle
        case ready
        case running
        case awaitingResume
        case failing
        case celebrating
        case replay
    }

    weak var gameDelegate: GameSceneDelegate?
    private(set) var simulation = GameSimulation(seed: 1)
    private(set) var mode: Mode = .idle
    private(set) var history: [GameSimulation] = []
    private(set) var stagingSnapshot: GameSimulation?
    private(set) var failedSimulation: GameSimulation?

    private var skin: Skin = .prototype
    private var isThrottling = false
    private var lastUpdate: TimeInterval?
    private var hudAccumulator = 0.0
    private var modeTimer = 0.0
    private var replayCursor = 0.0
    private var cameraOffset = 0.0
    private var shake = 0.0
    private var clock = 0.0
    private var rocketFraction = GameConfig.rocketScreenYFraction
    private var rocketFractionTarget = GameConfig.rocketScreenYFraction
    private var layoutSize: CGSize = .zero
    private var lastHUD = HUDSnapshot()

    // MARK: Nodes

    private let world = SKNode()
    private let sky = SKSpriteNode(color: .blue, size: CGSize(width: 1, height: 1))
    private var stars: [(node: SKSpriteNode, base: CGPoint, depth: CGFloat)] = []
    private var speedLines: [SKSpriteNode] = []
    private let markerLayer = SKNode()
    private var markers: [(node: SKNode, altitude: Double)] = []
    private let obstacleLayer = SKNode()
    private var obstacleNodes: [Int: SKNode] = [:]
    private var warningNodes: [Int: SKLabelNode] = [:]
    private let ground = SKSpriteNode(color: UIColor(hex: 0x3A3733), size: CGSize(width: 1, height: 1))
    private let padNode = SKSpriteNode(color: UIColor(hex: 0x6B6660), size: CGSize(width: 1, height: 1))
    private let tower = SKSpriteNode()
    private let rocketNode = SKNode()
    private let boosterSprite = SKSpriteNode()
    private let shipSprite = SKSpriteNode()
    private let flameSprite = SKSpriteNode(texture: Artwork.softDot)
    private let exhaust = SKEmitterNode()
    private var droppedBooster: (node: SKSpriteNode, altitude: Double, velocity: Double)?
    private let fxLayer = SKNode()
    private let staticOverlay = SKSpriteNode()
    private let staticLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let replayBadge = SKLabelNode(fontNamed: "AvenirNext-Heavy")

    // MARK: Geometry

    private var pxPerKm: CGFloat { size.height / CGFloat(GameConfig.visibleKm) }
    private var rocketY: CGFloat { size.height * CGFloat(rocketFraction) }
    private var rocketWidth: CGFloat { max(18, size.width * CGFloat(GameConfig.rocketHalfWidth) * 2.1) }
    private var boosterLengthPx: CGFloat { CGFloat(GameConfig.stackLength - GameConfig.shipLength) * pxPerKm }
    private var shipLengthPx: CGFloat { CGFloat(GameConfig.shipLength) * pxPerKm }

    private func screenX(_ x: Double) -> CGFloat { size.width / 2 + CGFloat(x) * size.width }
    private func screenY(_ altitude: Double, camera: Double) -> CGFloat {
        rocketY + CGFloat(altitude - camera) * pxPerKm
    }

    // MARK: - Lifecycle

    override func didMove(to view: SKView) {
        backgroundColor = .black
        view.isMultipleTouchEnabled = true
        guard world.parent == nil else { return }
        buildStaticNodes()
        layout()
        render(simulation, positionRocket: true)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard world.parent != nil, size.width > 1, size.height > 1, size != layoutSize else { return }
        layout()
        render(simulation, positionRocket: true)
    }

    // MARK: - Public API

    func prepareRun(seed: UInt32, skin: Skin) {
        if skin != self.skin || layoutSize == .zero {
            self.skin = skin
            applySkinTextures()
        }
        simulation = GameSimulation(seed: seed)
        history.removeAll(keepingCapacity: true)
        stagingSnapshot = nil
        failedSimulation = nil
        resetVisuals()
        mode = .ready
        pushHUD(force: true)
    }

    /// Continue / retry-from-staging: resume from a patched snapshot, paused until the next touch.
    func resume(from state: GameSimulation) {
        simulation = state
        history.removeAll(keepingCapacity: true)
        failedSimulation = nil
        resetVisuals()
        mode = .awaitingResume
        render(simulation, positionRocket: true)
        pushHUD(force: true)
    }

    func applySkin(_ skin: Skin) {
        guard skin != self.skin else { return }
        self.skin = skin
        applySkinTextures()
    }

    func releaseAllTouches() {
        isThrottling = false
    }

    // MARK: - Touches (the whole control scheme)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        isThrottling = true
        if mode == .ready || mode == .awaitingResume {
            mode = .running
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateThrottle(from: event)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        updateThrottle(from: event)
    }

    private func updateThrottle(from event: UIEvent?) {
        let remaining = event?.allTouches?.filter { $0.phase != .ended && $0.phase != .cancelled }.count ?? 0
        isThrottling = remaining > 0
    }

    // MARK: - Game loop

    override func update(_ currentTime: TimeInterval) {
        let dt = lastUpdate.map { min(max(currentTime - $0, 0), 1.0 / 20) } ?? 1.0 / 60
        lastUpdate = currentTime
        clock += dt

        rocketFraction += (rocketFractionTarget - rocketFraction) * min(1, dt * 3)
        cameraOffset *= max(0, 1 - dt * 6)
        shake = max(0, shake - dt * 2.5)

        switch mode {
        case .running:
            let events = simulation.step(dt: dt, throttleInput: isThrottling)
            record()
            render(simulation, positionRocket: true)
            handle(events)
        case .failing, .celebrating:
            render(simulation, positionRocket: false)
            modeTimer -= dt
            if modeTimer <= 0 {
                startReplay()
                gameDelegate?.gameSceneDidFinishRun(self)
            }
        case .replay:
            advanceReplay()
        case .idle, .ready, .awaitingResume:
            render(simulation, positionRocket: true)
        }

        updateAmbient(dt: dt, velocity: currentVelocity)
        updateDroppedBooster(dt: dt)
        world.position = shake > 0
            ? CGPoint(x: CGFloat.random(in: -1...1) * 9 * shake, y: CGFloat.random(in: -1...1) * 9 * shake)
            : .zero

        hudAccumulator += dt
        if hudAccumulator >= 1.0 / 20 {
            hudAccumulator = 0
            pushHUD(force: false)
        }
    }

    private var currentVelocity: Double {
        switch mode {
        case .replay:
            return history.isEmpty ? 0 : history[min(Int(replayCursor), history.count - 1)].rocket.velocity
        case .failing, .celebrating:
            return max(0, simulation.rocket.velocity * 0.3)
        default:
            return simulation.rocket.velocity
        }
    }

    private func record() {
        history.append(simulation)
        let limit = Int(GameConfig.historyDuration * 60)
        if history.count > limit {
            history.removeFirst(history.count - limit)
        }
    }

    // MARK: - Events

    private func handle(_ events: [GameEvent]) {
        for event in events {
            switch event {
            case .enteredStagingWindow:
                stagingSnapshot = simulation
                floatText(NSLocalizedString("fx.staging.window", comment: ""), color: UIColor(hex: 0x3FD17A), size: 26)
            case .separation:
                dropBooster()
            case .staged(let clean):
                if clean {
                    floatText(NSLocalizedString("fx.clean.staging", comment: ""), color: UIColor(hex: 0x3FD17A), size: 34)
                    shake = 0.4
                } else {
                    floatText(NSLocalizedString("fx.sloppy.staging", comment: ""), color: UIColor(hex: 0xFF8A2A), size: 26)
                }
            case .nearMiss:
                floatText(NSLocalizedString("fx.near.miss", comment: ""), color: .white, size: 22)
            case .spicy:
                floatText(NSLocalizedString("fx.spicy", comment: ""), color: UIColor(hex: 0xFF5A36), size: 18)
            case .tierChanged(let tier):
                floatText(NSLocalizedString(tier.localizationKey, comment: "").uppercased(), color: .white, size: 30, y: 0.62)
                shake = max(shake, 0.25)
            case .failed(let reason):
                startFailure(reason)
            case .orbit:
                startCelebration()
            case .liftoff, .heatWarning:
                break
            }
            gameDelegate?.gameScene(self, didEmit: event)
        }
    }

    // MARK: - Rendering

    private func render(_ state: GameSimulation, positionRocket: Bool) {
        let camera = state.rocket.altitude + cameraOffset
        updateSky(altitude: state.rocket.altitude)
        updateStars(camera: camera)

        let groundY = screenY(0, camera: camera)
        ground.position = CGPoint(x: size.width / 2, y: groundY)
        padNode.position = CGPoint(x: size.width / 2, y: groundY)
        tower.position = CGPoint(x: size.width / 2 - rocketWidth * 0.55, y: groundY)
        let groundVisible = groundY > -40
        ground.isHidden = !groundVisible
        padNode.isHidden = !groundVisible
        tower.isHidden = !groundVisible

        for marker in markers {
            marker.node.position.y = screenY(marker.altitude, camera: camera)
            marker.node.isHidden = abs(marker.node.position.y - size.height / 2) > size.height * 3
        }

        renderObstacles(state, camera: camera)

        guard positionRocket else { return }
        let rocket = state.rocket
        rocketNode.position = CGPoint(x: screenX(rocket.x), y: screenY(rocket.altitude, camera: camera))
        rocketNode.zRotation = CGFloat(-rocket.tilt)
        boosterSprite.isHidden = rocket.staged
        shipSprite.position = CGPoint(x: 0, y: rocket.staged ? 0 : boosterLengthPx)

        let throttle = rocket.throttle && state.phase != .pad
        let flicker = CGFloat(0.85 + 0.15 * sin(clock * 47))
        flameSprite.isHidden = !throttle
        flameSprite.yScale = throttle ? flicker * (1 + CGFloat(max(0, rocket.velocity)) * 0.08) : 0.2
        exhaust.particleBirthRate = throttle ? 260 : (state.phase == .pad ? 0 : 12)
        exhaust.particleSpeed = 260 + CGFloat(max(0, rocket.velocity)) * 55
        rocketNode.alpha = state.graceRemaining > 0 ? (Int(clock * 12) % 2 == 0 ? 0.45 : 1) : 1
    }

    private func renderObstacles(_ state: GameSimulation, camera: Double) {
        var visible = Set<Int>()
        let low = camera - 3
        let high = camera + GameConfig.visibleKm + 1.5
        var warned = Set<Int>()

        for obstacle in state.obstacles {
            let top = obstacle.altitude + obstacle.height
            let bottom = obstacle.isSolid ? obstacle.altitude - obstacle.height : obstacle.altitude
            guard top > low, bottom < high else {
                if obstacle.isSolid && obstacle.active && bottom >= high {
                    showWarning(for: obstacle, camera: camera)
                    warned.insert(obstacle.id)
                }
                continue
            }
            visible.insert(obstacle.id)
            let node = obstacleNodes[obstacle.id] ?? makeNode(for: obstacle)
            switch obstacle.kind {
            case .debris, .cameraDrone:
                node.position = CGPoint(x: screenX(obstacle.x), y: screenY(obstacle.altitude, camera: camera))
                if obstacle.kind == .debris {
                    node.zRotation = CGFloat(obstacle.rotation)
                } else {
                    node.zRotation = CGFloat(sin(obstacle.phase) * 0.15)
                }
                node.isHidden = !obstacle.active
            case .windShear:
                node.position = CGPoint(x: 0, y: screenY(obstacle.altitude, camera: camera))
                (node as? WindBandNode)?.animate(clock: clock)
            case .turbulence:
                node.position = CGPoint(x: 0, y: screenY(obstacle.altitude, camera: camera))
                (node as? TurbulenceBandNode)?.animate(clock: clock)
            }
        }

        for (id, node) in obstacleNodes where !visible.contains(id) {
            node.removeFromParent()
            obstacleNodes[id] = nil
        }
        for (id, node) in warningNodes where !warned.contains(id) {
            node.removeFromParent()
            warningNodes[id] = nil
        }
    }

    private func makeNode(for obstacle: Obstacle) -> SKNode {
        let node: SKNode
        switch obstacle.kind {
        case .debris:
            let size = CGSize(
                width: CGFloat(obstacle.halfWidth * 2) * self.size.width * 1.05,
                height: CGFloat(obstacle.height * 2) * pxPerKm * 1.05
            )
            node = SKSpriteNode(texture: SKTexture(image: Artwork.debrisImage(size: size, seed: obstacle.id)), size: size)
        case .cameraDrone:
            let size = CGSize(
                width: CGFloat(obstacle.halfWidth * 2) * self.size.width,
                height: CGFloat(obstacle.height * 2) * pxPerKm * 1.2
            )
            let sprite = SKSpriteNode(texture: SKTexture(image: Artwork.droneImage(size: size)), size: size)
            let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = NSLocalizedString("obstacle.camera", comment: "")
            label.fontSize = 10
            label.fontColor = UIColor(hex: 0xFF2D2D)
            label.position = CGPoint(x: 0, y: size.height / 2 + 4)
            sprite.addChild(label)
            node = sprite
        case .windShear:
            node = WindBandNode(
                width: size.width, height: CGFloat(obstacle.height) * pxPerKm,
                direction: obstacle.direction, seed: obstacle.id
            )
        case .turbulence:
            node = TurbulenceBandNode(width: size.width, height: CGFloat(obstacle.height) * pxPerKm)
        }
        obstacleLayer.addChild(node)
        obstacleNodes[obstacle.id] = node
        return node
    }

    private func showWarning(for obstacle: Obstacle, camera: Double) {
        let label: SKLabelNode
        if let existing = warningNodes[obstacle.id] {
            label = existing
        } else {
            label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
            label.text = obstacle.kind == .cameraDrone ? "📷" : "⚠︎"
            label.fontSize = 22
            label.fontColor = UIColor(hex: 0xFFC53D)
            label.verticalAlignmentMode = .center
            obstacleLayer.addChild(label)
            warningNodes[obstacle.id] = label
        }
        let x = min(max(screenX(obstacle.x), 24), size.width - 24)
        label.position = CGPoint(x: x, y: size.height * 0.78)
        let distance = obstacle.altitude - camera
        label.alpha = CGFloat(max(0.25, 1 - (distance - GameConfig.visibleKm) / 3)) * (Int(clock * 6) % 2 == 0 ? 1 : 0.6)
    }

    // MARK: - Ambient

    private static let skyStops: [(Double, UIColor)] = [
        (0, UIColor(hex: 0x6FB0F0)),
        (12, UIColor(hex: 0x3E74CC)),
        (30, UIColor(hex: 0x1A2F6B)),
        (60, UIColor(hex: 0x080D26)),
        (100, UIColor(hex: 0x02030A)),
    ]

    private func updateSky(altitude: Double) {
        let stops = Self.skyStops
        var color = stops[stops.count - 1].1
        for index in 0..<(stops.count - 1) where altitude < stops[index + 1].0 {
            let (a0, c0) = stops[index]
            let (a1, c1) = stops[index + 1]
            color = UIColor.lerp(c0, c1, CGFloat((max(altitude, a0) - a0) / (a1 - a0)))
            break
        }
        sky.color = color
    }

    private func updateStars(camera: Double) {
        let visibility = CGFloat(min(max((camera - 18) / 40, 0), 1))
        for (index, star) in stars.enumerated() {
            let travel = CGFloat(camera) * pxPerKm * star.depth
            var y = (star.base.y - travel).truncatingRemainder(dividingBy: size.height)
            if y < 0 { y += size.height }
            star.node.position = CGPoint(x: star.base.x, y: y)
            star.node.alpha = visibility * CGFloat(0.55 + 0.45 * sin(clock * 2 + Double(index)))
        }
    }

    private func updateAmbient(dt: Double, velocity: Double) {
        let speed = CGFloat(max(0, velocity))
        let alpha = min(0.35, max(0, (speed - 1) / 10))
        for line in speedLines {
            line.alpha = alpha
            line.position.y -= speed * pxPerKm * CGFloat(dt) * 0.9
            if line.position.y < -line.size.height {
                line.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: size.height + line.size.height)
            }
        }
    }

    // MARK: - Staging visuals

    private func dropBooster() {
        droppedBooster?.node.removeFromParent()
        let sprite = SKSpriteNode(texture: boosterSprite.texture, size: boosterSprite.size)
        sprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        sprite.zPosition = 9
        sprite.zRotation = rocketNode.zRotation
        fxLayer.addChild(sprite)
        let altitude = simulation.rocket.altitude - (GameConfig.stackLength - GameConfig.shipLength)
        droppedBooster = (sprite, altitude, simulation.rocket.velocity - 1.2)
        sprite.run(.rotate(byAngle: .pi * 0.6 * (Bool.random() ? 1 : -1), duration: 2.5))
        sprite.position = CGPoint(x: screenX(simulation.rocket.x), y: rocketY)
        // Keep the camera steady while the ship's base jumps up by the booster length.
        cameraOffset = -(GameConfig.stackLength - GameConfig.shipLength)
        let puff = makeBurst(colors: [.white, UIColor(white: 0.8, alpha: 1)], count: 40, speed: 120, lifetime: 0.7, scale: 0.9)
        puff.position = CGPoint(x: screenX(simulation.rocket.x), y: rocketY)
        fxLayer.addChild(puff)
        puff.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
    }

    private func updateDroppedBooster(dt: Double) {
        guard var booster = droppedBooster else { return }
        booster.velocity -= 3 * dt
        booster.altitude += booster.velocity * dt
        let camera = simulation.rocket.altitude + cameraOffset
        booster.node.position.y = screenY(booster.altitude, camera: camera)
        if booster.node.position.y < -size.height {
            booster.node.removeFromParent()
            droppedBooster = nil
        } else {
            droppedBooster = booster
        }
    }

    // MARK: - Fail & win

    private func startFailure(_ reason: FailReason) {
        failedSimulation = simulation
        mode = .failing
        modeTimer = 1.5
        flameSprite.isHidden = true
        exhaust.particleBirthRate = 0
        let center = CGPoint(x: rocketNode.position.x, y: rocketNode.position.y + rocketHeightPx / 2)

        switch reason {
        case .rud:
            rocketNode.isHidden = true
            let burst = makeBurst(
                colors: [UIColor(hex: 0xFFF3B0), UIColor(hex: 0xFFB020), UIColor(hex: 0xFF5A36), UIColor(white: 0.5, alpha: 1)],
                count: 160, speed: 330, lifetime: 1.1, scale: 1.4
            )
            burst.position = center
            fxLayer.addChild(burst)
            spawnPieces(at: center)
            shake = 1
            bigText("RUD!", color: UIColor(hex: 0xFFC53D))
        case .bellyFlop:
            let direction: CGFloat = simulation.rocket.tilt >= 0 ? -1 : 1
            rocketNode.run(.group([
                .rotate(toAngle: direction * .pi / 2, duration: 0.45, shortestUnitArc: true),
                .sequence([.wait(forDuration: 0.2), .moveBy(x: 0, y: -size.height * 0.5, duration: 0.9)]),
            ]))
            bigText(NSLocalizedString("fx.splat", comment: ""), color: .white)
            shake = 0.5
        case .turtleMode:
            rocketNode.run(.sequence([
                .rotate(toAngle: .pi, duration: 0.7, shortestUnitArc: true),
                .repeatForever(.sequence([.moveBy(x: 0, y: -8, duration: 0.3), .moveBy(x: 0, y: 8, duration: 0.3)])),
            ]))
            bigText("🐢", color: .white)
        case .livestreamEnded:
            staticOverlay.isHidden = false
            staticOverlay.run(.repeatForever(.animate(with: Artwork.staticNoise, timePerFrame: 0.05)), withKey: "static")
            staticLabel.isHidden = false
            shake = 0.6
        case .outOfFuel:
            let puffs = makeBurst(colors: [UIColor(white: 0.7, alpha: 1)], count: 12, speed: 40, lifetime: 1.2, scale: 0.8)
            puffs.position = CGPoint(x: rocketNode.position.x, y: rocketNode.position.y)
            fxLayer.addChild(puffs)
            rocketNode.run(.group([
                .moveBy(x: 0, y: -size.height * 0.35, duration: 1.4),
                .sequence([.rotate(byAngle: 0.25, duration: 0.35), .rotate(byAngle: -0.5, duration: 0.7)]),
            ]))
            bigText(NSLocalizedString("fx.pfff", comment: ""), color: .white)
        }
    }

    private var rocketHeightPx: CGFloat {
        simulation.rocket.staged ? shipLengthPx : boosterLengthPx + shipLengthPx
    }

    private func spawnPieces(at point: CGPoint) {
        for index in 0..<6 {
            let piece = SKSpriteNode(color: UIColor(hex: index % 2 == 0 ? 0xB8BEC6 : 0x2B2E33), size: CGSize(width: 6, height: 12))
            piece.position = point
            piece.zPosition = 20
            fxLayer.addChild(piece)
            let angle = CGFloat(index) / 6 * .pi * 2 + CGFloat.random(in: -0.3...0.3)
            let distance = CGFloat.random(in: 90...170)
            piece.run(.sequence([
                .group([
                    .moveBy(x: cos(angle) * distance, y: sin(angle) * distance - 60, duration: 1.1),
                    .rotate(byAngle: .pi * 4, duration: 1.1),
                    .fadeOut(withDuration: 1.1),
                ]),
                .removeFromParent(),
            ]))
        }
    }

    private func startCelebration() {
        mode = .celebrating
        modeTimer = 2.2
        rocketNode.run(.moveBy(x: 0, y: size.height * 0.9, duration: 2))
        exhaust.particleBirthRate = 260
        let confetti = SKEmitterNode()
        confetti.particleTexture = Artwork.confettiPiece
        confetti.particleBirthRate = 220
        confetti.numParticlesToEmit = 500
        confetti.particleLifetime = 3
        confetti.emissionAngle = -.pi / 2
        confetti.emissionAngleRange = 0.6
        confetti.particleSpeed = 180
        confetti.particleSpeedRange = 120
        confetti.yAcceleration = -120
        confetti.particleRotationRange = .pi * 2
        confetti.particleRotationSpeed = 4
        confetti.particleScale = 1
        confetti.particleScaleRange = 0.5
        confetti.particleColorBlendFactor = 1
        confetti.particleColor = .white
        confetti.particleColorRedRange = 1
        confetti.particleColorGreenRange = 1
        confetti.particleColorBlueRange = 1
        confetti.particlePositionRange = CGVector(dx: size.width, dy: 0)
        confetti.position = CGPoint(x: size.width / 2, y: size.height + 10)
        confetti.zPosition = 60
        fxLayer.addChild(confetti)
        bigText(NSLocalizedString("fx.orbit", comment: ""), color: UIColor(hex: 0xFFD23F))
    }

    // MARK: - Replay (last 3 s before the fail, in slow motion)

    private func startReplay() {
        guard !history.isEmpty, failedSimulation != nil else {
            mode = .idle
            return
        }
        mode = .replay
        replayCursor = 0
        rocketFractionTarget = 0.7
        staticOverlay.isHidden = true
        staticOverlay.removeAction(forKey: "static")
        staticLabel.isHidden = true
        fxLayer.removeAllChildren()
        droppedBooster = nil
        restoreRocketNode()
        replayBadge.isHidden = false
    }

    private func advanceReplay() {
        replayCursor += 0.5
        let count = history.count
        if replayCursor >= Double(count + 40) {
            replayCursor = 0
            restoreRocketNode()
        }
        let index = min(Int(replayCursor), count - 1)
        let frame = history[index]
        if Int(replayCursor) == count - 1 {
            let flash = makeBurst(colors: [UIColor(hex: 0xFFB020), UIColor(hex: 0xFF5A36)], count: 80, speed: 220, lifetime: 0.8, scale: 1)
            flash.position = CGPoint(x: rocketNode.position.x, y: rocketNode.position.y + rocketHeightPx / 2)
            fxLayer.addChild(flash)
            flash.run(.sequence([.wait(forDuration: 1.2), .removeFromParent()]))
            rocketNode.isHidden = true
        }
        render(frame, positionRocket: Int(replayCursor) < count)
        replayBadge.alpha = Int(clock * 2) % 2 == 0 ? 1 : 0.5
    }

    // MARK: - FX helpers

    private func makeBurst(colors: [UIColor], count: Int, speed: CGFloat, lifetime: CGFloat, scale: CGFloat) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = Artwork.softDot
        emitter.particleBirthRate = CGFloat(count) * 20
        emitter.numParticlesToEmit = count
        emitter.particleLifetime = lifetime
        emitter.particleLifetimeRange = lifetime * 0.5
        emitter.emissionAngleRange = .pi * 2
        emitter.particleSpeed = speed
        emitter.particleSpeedRange = speed * 0.7
        emitter.particleAlpha = 1
        emitter.particleAlphaSpeed = -1 / lifetime
        emitter.particleScale = scale
        emitter.particleScaleRange = scale * 0.5
        emitter.particleScaleSpeed = scale * 0.8
        emitter.particleColorBlendFactor = 1
        emitter.zPosition = 30
        let times = colors.indices.map { NSNumber(value: Double($0) / Double(max(colors.count - 1, 1))) }
        emitter.particleColorSequence = SKKeyframeSequence(keyframeValues: colors, times: times)
        return emitter
    }

    private func floatText(_ text: String, color: UIColor, size fontSize: CGFloat, y: CGFloat = 0.5) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = fontSize
        label.fontColor = color
        label.position = CGPoint(x: size.width / 2, y: size.height * y)
        label.zPosition = 50
        label.setScale(0.6)
        fxLayer.addChild(label)
        label.run(.sequence([
            .group([.scale(to: 1, duration: 0.15), .moveBy(x: 0, y: 60, duration: 0.9)]),
            .fadeOut(withDuration: 0.3),
            .removeFromParent(),
        ]))
    }

    private func bigText(_ text: String, color: UIColor) {
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = text
        label.fontSize = 64
        label.fontColor = color
        label.position = CGPoint(x: size.width / 2, y: size.height * 0.58)
        label.zPosition = 70
        label.setScale(0.2)
        let shadow = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        shadow.text = text
        shadow.fontSize = 64
        shadow.fontColor = UIColor.black.withAlphaComponent(0.5)
        shadow.position = CGPoint(x: 3, y: -3)
        shadow.zPosition = -1
        label.addChild(shadow)
        fxLayer.addChild(label)
        label.run(.sequence([
            .scale(to: 1.15, duration: 0.14),
            .scale(to: 1, duration: 0.1),
            .wait(forDuration: 0.9),
            .fadeOut(withDuration: 0.25),
            .removeFromParent(),
        ]))
    }

    // MARK: - HUD bridge

    private func pushHUD(force: Bool) {
        guard mode != .replay else { return }
        let state = simulation
        let hud = HUDSnapshot(
            altitude: max(0, state.rocket.altitude),
            velocity: state.rocket.velocity,
            heat: min(state.rocket.heat, 1),
            fuel: state.rocket.fuel,
            tilt: state.rocket.tilt,
            phase: state.phase,
            tier: state.tier,
            score: state.score,
            stylePoints: state.stylePoints,
            throttle: state.rocket.throttle,
            inWind: state.windTorque != 0,
            inTurbulence: state.turbulence > 0,
            stagingPending: state.stagingPendingSince != nil,
            waitingForTouch: mode == .ready || mode == .awaitingResume,
            grace: state.graceRemaining > 0
        )
        guard force || hud != lastHUD else { return }
        lastHUD = hud
        gameDelegate?.gameScene(self, didUpdate: hud)
    }

    // MARK: - Setup

    private func buildStaticNodes() {
        sky.anchorPoint = .zero
        sky.zPosition = -100
        addChild(sky)
        addChild(world)

        for _ in 0..<70 {
            let star = SKSpriteNode(texture: Artwork.softDot)
            let side = CGFloat.random(in: 2...5)
            star.size = CGSize(width: side, height: side)
            star.zPosition = -90
            world.addChild(star)
            stars.append((star, .zero, CGFloat.random(in: 0.02...0.08)))
        }
        for _ in 0..<12 {
            let line = SKSpriteNode(color: .white, size: CGSize(width: 1.5, height: CGFloat.random(in: 40...120)))
            line.zPosition = -80
            line.alpha = 0
            world.addChild(line)
            speedLines.append(line)
        }

        markerLayer.zPosition = -50
        world.addChild(markerLayer)
        obstacleLayer.zPosition = 5
        world.addChild(obstacleLayer)

        ground.anchorPoint = CGPoint(x: 0.5, y: 1)
        ground.zPosition = -10
        world.addChild(ground)
        padNode.anchorPoint = CGPoint(x: 0.5, y: 0)
        padNode.zPosition = -9
        world.addChild(padNode)
        tower.anchorPoint = CGPoint(x: 1, y: 0)
        tower.zPosition = -8
        world.addChild(tower)

        rocketNode.zPosition = 10
        world.addChild(rocketNode)
        boosterSprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        rocketNode.addChild(boosterSprite)
        shipSprite.anchorPoint = CGPoint(x: 0.5, y: 0)
        rocketNode.addChild(shipSprite)
        flameSprite.anchorPoint = CGPoint(x: 0.5, y: 1)
        flameSprite.colorBlendFactor = 1
        flameSprite.blendMode = .add
        flameSprite.zPosition = -1
        rocketNode.addChild(flameSprite)

        exhaust.particleTexture = Artwork.softDot
        exhaust.particleBirthRate = 0
        exhaust.particleLifetime = 0.5
        exhaust.particleLifetimeRange = 0.2
        exhaust.emissionAngle = -.pi / 2
        exhaust.emissionAngleRange = 0.28
        exhaust.particleSpeed = 300
        exhaust.particleSpeedRange = 80
        exhaust.particleAlpha = 0.9
        exhaust.particleAlphaSpeed = -1.6
        exhaust.particleScale = 0.5
        exhaust.particleScaleRange = 0.2
        exhaust.particleScaleSpeed = 1.1
        exhaust.particleColorBlendFactor = 1
        exhaust.zPosition = -2
        exhaust.targetNode = world
        rocketNode.addChild(exhaust)

        fxLayer.zPosition = 40
        world.addChild(fxLayer)

        staticOverlay.anchorPoint = .zero
        staticOverlay.zPosition = 90
        staticOverlay.alpha = 0.85
        staticOverlay.isHidden = true
        addChild(staticOverlay)
        staticLabel.text = NSLocalizedString("fx.no.signal", comment: "")
        staticLabel.fontSize = 30
        staticLabel.fontColor = .white
        staticLabel.zPosition = 91
        staticLabel.isHidden = true
        addChild(staticLabel)

        replayBadge.text = NSLocalizedString("fx.replay", comment: "")
        replayBadge.fontSize = 16
        replayBadge.fontColor = UIColor(hex: 0xFF3B30)
        replayBadge.horizontalAlignmentMode = .left
        replayBadge.zPosition = 95
        replayBadge.isHidden = true
        addChild(replayBadge)
    }

    private func layout() {
        layoutSize = size
        sky.size = size
        staticOverlay.size = size
        staticLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.62)
        replayBadge.position = CGPoint(x: 20, y: size.height * 0.86)

        for index in stars.indices {
            stars[index].base = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
        }
        for line in speedLines {
            line.position = CGPoint(x: CGFloat.random(in: 0...size.width), y: CGFloat.random(in: 0...size.height))
        }

        ground.size = CGSize(width: size.width, height: size.height)
        padNode.size = CGSize(width: rocketWidth * 3.2, height: 8)
        let towerSize = CGSize(width: rocketWidth * 1.9, height: (boosterLengthPx + shipLengthPx) * 1.15)
        tower.texture = SKTexture(image: Artwork.towerImage(size: towerSize))
        tower.size = towerSize

        buildMarkers()
        for node in obstacleNodes.values { node.removeFromParent() }
        obstacleNodes.removeAll()
        applySkinTextures()
    }

    private func buildMarkers() {
        markerLayer.removeAllChildren()
        markers.removeAll()

        func line(altitude: Double, text: String, color: UIColor, dashed: Bool) {
            let node = SKNode()
            let segments = dashed ? 16 : 1
            let segmentWidth = size.width / CGFloat(segments)
            for index in 0..<segments {
                let segment = SKSpriteNode(color: color, size: CGSize(width: dashed ? segmentWidth * 0.6 : size.width, height: 2))
                segment.anchorPoint = CGPoint(x: 0, y: 0.5)
                segment.position = CGPoint(x: CGFloat(index) * segmentWidth, y: 0)
                node.addChild(segment)
            }
            let label = SKLabelNode(fontNamed: "AvenirNext-Bold")
            label.text = text
            label.fontSize = 12
            label.fontColor = color
            label.horizontalAlignmentMode = .right
            label.position = CGPoint(x: size.width - 12, y: 6)
            node.addChild(label)
            markerLayer.addChild(node)
            markers.append((node, altitude))
        }

        let tierFormat = NSLocalizedString("marker.tier", comment: "")
        line(altitude: 12, text: String(format: tierFormat, NSLocalizedString("tier.stratosphere", comment: "").uppercased(), 12), color: UIColor.white.withAlphaComponent(0.6), dashed: true)
        line(altitude: 50, text: String(format: tierFormat, NSLocalizedString("tier.mesosphere", comment: "").uppercased(), 50), color: UIColor.white.withAlphaComponent(0.6), dashed: true)
        line(altitude: GameConfig.karmanLine, text: NSLocalizedString("marker.karman", comment: ""), color: UIColor(hex: 0xFFD23F), dashed: false)

        let bandHeight = CGFloat(GameConfig.stagingEnd - GameConfig.stagingStart) * pxPerKm
        let band = SKSpriteNode(color: UIColor(hex: 0x3FD17A).withAlphaComponent(0.1), size: CGSize(width: size.width, height: bandHeight))
        band.anchorPoint = .zero
        let bandLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        bandLabel.text = NSLocalizedString("marker.staging", comment: "")
        bandLabel.fontSize = 13
        bandLabel.fontColor = UIColor(hex: 0x3FD17A)
        bandLabel.position = CGPoint(x: size.width / 2, y: 10)
        band.addChild(bandLabel)
        let top = SKSpriteNode(color: UIColor(hex: 0x3FD17A).withAlphaComponent(0.7), size: CGSize(width: size.width, height: 2))
        top.anchorPoint = .zero
        top.position = CGPoint(x: 0, y: bandHeight)
        band.addChild(top)
        let bottom = SKSpriteNode(color: UIColor(hex: 0x3FD17A).withAlphaComponent(0.7), size: CGSize(width: size.width, height: 2))
        bottom.anchorPoint = .zero
        band.addChild(bottom)
        markerLayer.addChild(band)
        markers.append((band, GameConfig.stagingStart))
    }

    private func applySkinTextures() {
        guard size.width > 1 else { return }
        let width = rocketWidth
        boosterSprite.texture = SKTexture(image: Artwork.boosterImage(skin: skin, size: CGSize(width: width, height: boosterLengthPx)))
        boosterSprite.size = CGSize(width: width, height: boosterLengthPx)
        shipSprite.texture = SKTexture(image: Artwork.shipImage(skin: skin, size: CGSize(width: width, height: shipLengthPx)))
        shipSprite.size = CGSize(width: width, height: shipLengthPx)
        let palette = SkinPalette.palette(for: skin)
        flameSprite.color = palette.flame
        flameSprite.size = CGSize(width: width * 0.9, height: width * 2.6)
        exhaust.particlePositionRange = CGVector(dx: width * 0.45, dy: 0)
        exhaust.particleColorSequence = SKKeyframeSequence(
            keyframeValues: [palette.flameCore, palette.flame, UIColor(white: 0.75, alpha: 0.6)],
            times: [0, 0.2, 1]
        )
    }

    private func resetVisuals() {
        rocketFractionTarget = GameConfig.rocketScreenYFraction
        rocketFraction = GameConfig.rocketScreenYFraction
        cameraOffset = 0
        shake = 0
        isThrottling = false
        fxLayer.removeAllChildren()
        droppedBooster = nil
        staticOverlay.isHidden = true
        staticOverlay.removeAction(forKey: "static")
        staticLabel.isHidden = true
        replayBadge.isHidden = true
        exhaust.resetSimulation()
        for node in obstacleNodes.values { node.removeFromParent() }
        obstacleNodes.removeAll()
        for node in warningNodes.values { node.removeFromParent() }
        warningNodes.removeAll()
        restoreRocketNode()
    }

    private func restoreRocketNode() {
        rocketNode.removeAllActions()
        rocketNode.isHidden = false
        rocketNode.alpha = 1
    }
}

// MARK: - Band nodes

final class WindBandNode: SKNode {
    private var streaks: [(node: SKSpriteNode, baseX: CGFloat, speed: CGFloat)] = []
    private let width: CGFloat
    private let direction: CGFloat

    init(width: CGFloat, height: CGFloat, direction: Double, seed: Int) {
        self.width = width
        self.direction = CGFloat(direction)
        super.init()
        let band = SKSpriteNode(color: UIColor(hex: 0x8FE3FF).withAlphaComponent(0.09), size: CGSize(width: width, height: height))
        band.anchorPoint = .zero
        addChild(band)

        var rng = SeededRandom(seed: UInt64(seed))
        let count = max(6, Int(height / 40))
        for _ in 0..<count {
            let streak = SKSpriteNode(color: .white, size: CGSize(width: CGFloat(rng.next(in: 40...110)), height: 2))
            streak.alpha = CGFloat(rng.next(in: 0.25...0.6))
            streak.position.y = CGFloat(rng.nextDouble()) * height
            addChild(streak)
            streaks.append((streak, CGFloat(rng.nextDouble()) * width, CGFloat(rng.next(in: 180...320))))
        }

        let symbol = SKSpriteNode(texture: SKTexture(image: Artwork.windSymbolImage(pointSize: 26)))
        symbol.alpha = 0.8
        // Inset past the heat / fuel gauges on the screen edges.
        symbol.position = CGPoint(x: direction > 0 ? 64 : width - 64, y: 24)
        symbol.xScale = direction > 0 ? 1 : -1
        addChild(symbol)
        let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
        label.text = NSLocalizedString(direction > 0 ? "obstacle.wind.right" : "obstacle.wind.left", comment: "")
        label.fontSize = 12
        label.fontColor = UIColor(hex: 0x8FE3FF)
        label.position = CGPoint(x: width / 2, y: 18)
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    func animate(clock: Double) {
        let span = width + 120
        for streak in streaks {
            var x = (streak.baseX + CGFloat(clock) * streak.speed * direction).truncatingRemainder(dividingBy: span)
            if x < 0 { x += span }
            streak.node.position.x = x - 60
        }
    }
}

final class TurbulenceBandNode: SKNode {
    private let label = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let labelX: CGFloat

    init(width: CGFloat, height: CGFloat) {
        labelX = width / 2
        super.init()
        let band = SKSpriteNode(color: UIColor(hex: 0xFF8A2A).withAlphaComponent(0.1), size: CGSize(width: width, height: height))
        band.anchorPoint = .zero
        addChild(band)
        for y in [CGFloat(0), height] {
            let edge = SKSpriteNode(color: UIColor(hex: 0xFF8A2A).withAlphaComponent(0.6), size: CGSize(width: width, height: 2))
            edge.anchorPoint = .zero
            edge.position.y = y
            addChild(edge)
        }
        label.text = NSLocalizedString("obstacle.turbulence", comment: "")
        label.fontSize = 13
        label.fontColor = UIColor(hex: 0xFF8A2A)
        label.position = CGPoint(x: width / 2, y: 12)
        addChild(label)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    func animate(clock: Double) {
        label.position.x = labelX + CGFloat(sin(clock * 40)) * 2
    }
}
