import Foundation

struct RocketState: Equatable {
    var altitude = 0.0
    var velocity = 0.0
    var x = 0.0
    var tilt = 0.0
    var heat = 0.0
    var fuel = 1.0
    var throttle = false
    var staged = false

    var length: Double { staged ? GameConfig.shipLength : GameConfig.stackLength }
}

/// Pure, deterministic game logic. No SpriteKit, no UIKit: the scene only renders it.
/// A value type, so snapshots for replay / continue / retry-from-staging are plain copies.
struct GameSimulation {
    let seed: UInt32
    private(set) var rocket = RocketState()
    private(set) var obstacles: [Obstacle]
    private(set) var phase: FlightPhase = .pad
    private(set) var time = 0.0
    private(set) var maxAltitude = 0.0
    private(set) var stylePoints = 0
    private(set) var cleanStaging = false
    private(set) var failReason: FailReason?
    private(set) var failObstacleID: Int?
    private(set) var tier: AltitudeTier = .troposphere
    private(set) var turbulence = 0.0
    private(set) var windTorque = 0.0
    private(set) var nearMisses = 0
    private(set) var stagingPendingSince: Double?
    private(set) var graceRemaining = 0.0
    private var heatWarningArmed = true
    private var spicyAccumulator = 0.0

    init(seed: UInt32) {
        self.seed = seed
        obstacles = LevelGenerator.make(seed: seed)
    }

    var score: Int { Int(maxAltitude * 100) + stylePoints }
    var isOver: Bool { failReason != nil || phase == .orbit }
    var didReachStaging: Bool { rocket.staged || phase == .hotStaging }

    private var params: GameConfig.StageParams {
        rocket.staged ? GameConfig.ship : GameConfig.booster
    }

    // MARK: - Step

    mutating func step(dt: Double, throttleInput: Bool) -> [GameEvent] {
        guard !isOver else { return [] }
        var events: [GameEvent] = []
        let wantsThrottle = throttleInput && rocket.fuel > 0

        if phase == .pad {
            guard wantsThrottle else { return events }
            phase = .boost
            events.append(.liftoff)
        }

        time += dt
        graceRemaining = max(0, graceRemaining - dt)

        updateStaging(wantsThrottle: wantsThrottle, events: &events)
        rocket.throttle = wantsThrottle

        updateObstacles(dt: dt)
        updateEnvironment()
        integrate(dt: dt)
        updateScoring(dt: dt, events: &events)

        if graceRemaining <= 0 {
            checkCollisions(events: &events)
            checkFails(events: &events)
        } else {
            rocket.velocity = max(rocket.velocity, GameConfig.fallLimit + 1)
            rocket.tilt = min(max(rocket.tilt, -0.6), 0.6)
            rocket.heat = min(rocket.heat, 0.9)
        }
        if isOver { return events }

        updatePhase(events: &events)
        return events
    }

    // MARK: - Staging

    private mutating func updateStaging(wantsThrottle: Bool, events: inout [GameEvent]) {
        if phase == .hotStaging && !rocket.staged {
            let released = rocket.throttle && !wantsThrottle
            let forced = rocket.altitude >= GameConfig.stagingEnd || rocket.fuel <= 0
            if released {
                separate()
                stagingPendingSince = time
                events.append(.separation)
            } else if forced {
                separate()
                rocket.heat = min(0.95, rocket.heat + 0.25)
                events.append(.separation)
                resolveStaging(clean: false, events: &events)
            }
        }

        if let since = stagingPendingSince {
            let elapsed = time - since
            if wantsThrottle && elapsed > 0 {
                resolveStaging(clean: elapsed <= GameConfig.cleanStagingWindow, events: &events)
            } else if elapsed > GameConfig.cleanStagingWindow {
                resolveStaging(clean: false, events: &events)
            }
        }
    }

    private mutating func separate() {
        // `altitude` is the base of the stack; after separation it becomes the ship's base.
        rocket.altitude += GameConfig.stackLength - GameConfig.shipLength
        rocket.staged = true
        rocket.fuel = 1
        rocket.heat = max(0, rocket.heat - 0.2)
    }

    private mutating func resolveStaging(clean: Bool, events: inout [GameEvent]) {
        stagingPendingSince = nil
        cleanStaging = clean
        phase = .orbitBurn
        if clean {
            stylePoints += GameConfig.cleanStagingPoints
            rocket.velocity += 0.8
            rocket.heat = min(rocket.heat, 0.2)
        }
        events.append(.staged(clean: clean))
    }

    // MARK: - Physics

    private mutating func updateObstacles(dt: Double) {
        let cutoff = rocket.altitude - 5
        obstacles.removeAll { $0.altitude + $0.height < cutoff }
        for index in obstacles.indices {
            var obstacle = obstacles[index]
            if !obstacle.active && obstacle.altitude - rocket.altitude < GameConfig.spawnDistance {
                obstacle.active = true
            }
            guard obstacle.active else { continue }
            switch obstacle.kind {
            case .debris:
                obstacle.x += obstacle.direction * obstacle.speed * dt
                obstacle.rotation += obstacle.phase * dt
            case .cameraDrone:
                obstacle.phase += obstacle.speed * dt
                obstacle.x = obstacle.strength * sin(obstacle.phase)
            case .windShear, .turbulence:
                break
            }
            obstacles[index] = obstacle
        }
    }

    private mutating func updateEnvironment() {
        let center = rocket.altitude + rocket.length / 2
        windTorque = 0
        turbulence = 0
        for obstacle in obstacles where obstacle.contains(altitude: center) {
            switch obstacle.kind {
            case .windShear: windTorque += obstacle.direction * obstacle.strength
            case .turbulence: turbulence = 1
            default: break
            }
        }
    }

    private mutating func integrate(dt: Double) {
        let p = params
        var accel = -p.gravity - p.drag * rocket.velocity
        if rocket.throttle { accel += p.thrust }
        if turbulence > 0 {
            accel += sin(time * 13.1) * sin(time * 5.7) * 5
        }
        rocket.velocity += accel * dt
        rocket.altitude += rocket.velocity * dt

        if maxAltitude < 0.3 && rocket.altitude < 0 {
            rocket.altitude = 0
            rocket.velocity = max(0, rocket.velocity)
        }

        if rocket.throttle {
            rocket.heat += (p.heatBase + p.heatPerSpeed * max(0, rocket.velocity)) * dt
            rocket.fuel = max(0, rocket.fuel - p.fuelBurn * dt)
        } else {
            rocket.heat = max(0, rocket.heat - p.cooling * dt)
        }
        if turbulence > 0 { rocket.heat += 0.05 * dt }

        let wobble = sin(time * 2.3) * 0.05
        let recovery = rocket.throttle ? -p.stabilize * rocket.tilt : p.instability * rocket.tilt
        rocket.tilt += (windTorque + recovery + wobble) * dt
        rocket.x += sin(rocket.tilt) * GameConfig.driftSpeed * dt
        rocket.x = min(max(rocket.x, -GameConfig.xLimit), GameConfig.xLimit)
    }

    // MARK: - Scoring

    private mutating func updateScoring(dt: Double, events: inout [GameEvent]) {
        maxAltitude = max(maxAltitude, min(rocket.altitude, GameConfig.karmanLine))

        if rocket.heat > 0.8 && heatWarningArmed {
            heatWarningArmed = false
            events.append(.heatWarning)
        } else if rocket.heat < 0.6 {
            heatWarningArmed = true
        }

        if rocket.heat > 0.85 {
            spicyAccumulator += dt
            if spicyAccumulator >= 1 {
                spicyAccumulator -= 1
                stylePoints += GameConfig.spicyPoints
                events.append(.spicy)
            }
        } else {
            spicyAccumulator = 0
        }
    }

    // MARK: - Collisions & fails

    private mutating func checkCollisions(events: inout [GameEvent]) {
        let bottom = rocket.altitude
        let top = rocket.altitude + rocket.length
        for index in obstacles.indices where obstacles[index].isSolid && obstacles[index].active {
            let obstacle = obstacles[index]
            let overlapsVertically = obstacle.altitude + obstacle.height > bottom && obstacle.altitude - obstacle.height < top
            guard overlapsVertically else { continue }
            let gap = abs(obstacle.x - rocket.x) - (obstacle.halfWidth + GameConfig.rocketHalfWidth)
            if gap < 0 {
                failObstacleID = obstacle.id
                fail(obstacle.kind == .cameraDrone ? .livestreamEnded : .rud, events: &events)
                return
            } else if gap < GameConfig.nearMissMargin && !obstacle.nearMissAwarded {
                obstacles[index].nearMissAwarded = true
                nearMisses += 1
                stylePoints += GameConfig.nearMissPoints
                events.append(.nearMiss)
            }
        }
    }

    private mutating func checkFails(events: inout [GameEvent]) {
        guard failReason == nil else { return }
        if rocket.heat >= 1 {
            fail(.rud, events: &events)
        } else if abs(rocket.tilt) >= GameConfig.maxTilt {
            fail(.turtleMode, events: &events)
        } else if rocket.velocity < GameConfig.fallLimit || (maxAltitude >= 0.3 && rocket.altitude <= 0) {
            fail(rocket.fuel <= 0 ? .outOfFuel : .bellyFlop, events: &events)
        }
    }

    private mutating func fail(_ reason: FailReason, events: inout [GameEvent]) {
        failReason = reason
        rocket.throttle = false
        events.append(.failed(reason))
    }

    // MARK: - Phases

    private mutating func updatePhase(events: inout [GameEvent]) {
        let newTier = AltitudeTier.tier(for: rocket.altitude)
        if newTier != tier {
            tier = newTier
            events.append(.tierChanged(newTier))
        }
        if phase == .boost && rocket.altitude >= GameConfig.stagingStart {
            phase = .hotStaging
            events.append(.enteredStagingWindow)
        }
        if rocket.altitude >= GameConfig.karmanLine {
            phase = .orbit
            maxAltitude = GameConfig.karmanLine
            stylePoints += GameConfig.orbitPoints
            events.append(.orbit)
        }
    }

    // MARK: - Second chances

    /// Rewarded "continue": patch a rewound snapshot so the player gets a fair restart.
    mutating func applyContinue(removing obstacleID: Int?) {
        failReason = nil
        failObstacleID = nil
        rocket.heat = min(rocket.heat, 0.35)
        rocket.tilt = 0
        rocket.x *= 0.5
        rocket.velocity = max(rocket.velocity, 1.5)
        rocket.fuel = max(rocket.fuel, 0.4)
        rocket.throttle = false
        rocket.altitude = max(rocket.altitude, 1)
        let low = rocket.altitude - 1
        let high = rocket.altitude + 4
        obstacles.removeAll { obstacle in
            obstacle.id == obstacleID || (obstacle.isSolid && obstacle.altitude > low && obstacle.altitude < high)
        }
        graceRemaining = GameConfig.graceDuration
        if phase == .pad { phase = .boost }
    }

    /// Prepares a snapshot taken on entering the staging window for a "retry from staging".
    mutating func prepareStagingRetry() {
        rocket.throttle = false
        rocket.heat = min(rocket.heat, 0.4)
        rocket.tilt = 0
        graceRemaining = 0.8
    }
}
