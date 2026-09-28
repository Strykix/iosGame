import XCTest
@testable import StarBarge

final class GameSimulationTests: XCTestCase {
    private let dt = 1.0 / 60

    func testNothingHappensUntilFirstTouch() {
        var sim = GameSimulation(seed: 1)
        for _ in 0..<120 {
            XCTAssertTrue(sim.step(dt: dt, throttleInput: false).isEmpty)
        }
        XCTAssertEqual(sim.phase, .pad)
        XCTAssertEqual(sim.rocket.altitude, 0)
    }

    func testHoldingForeverOverheats() {
        var sim = GameSimulation(seed: 1)
        var events: [GameEvent] = []
        for _ in 0..<(60 * 20) where !sim.isOver {
            events += sim.step(dt: dt, throttleInput: true)
        }
        XCTAssertEqual(sim.failReason, .rud)
        XCTAssertTrue(events.contains(.liftoff))
        XCTAssertLessThan(sim.time, 10, "Full throttle must pop quickly")
    }

    func testReleasingAfterLiftoffBellyFlops() {
        var sim = GameSimulation(seed: 1)
        for _ in 0..<60 { _ = sim.step(dt: dt, throttleInput: true) }
        for _ in 0..<(60 * 10) where !sim.isOver { _ = sim.step(dt: dt, throttleInput: false) }
        XCTAssertEqual(sim.failReason, .bellyFlop)
    }

    func testSameSeedSameCourse() {
        XCTAssertEqual(LevelGenerator.make(seed: 42), LevelGenerator.make(seed: 42))
        XCTAssertNotEqual(LevelGenerator.make(seed: 42), LevelGenerator.make(seed: 43))
    }

    func testStagingWindowIsKeptClear() {
        for seed in UInt32(1)...50 {
            let solids = LevelGenerator.make(seed: seed).filter(\.isSolid)
            XCTAssertFalse(solids.contains { $0.altitude > GameConfig.stagingStart - 1 && $0.altitude < GameConfig.stagingEnd + 1 })
        }
    }

    /// A look-ahead bot must be able to reach orbit on most seeds, within the 20–40 s target.
    func testCourseIsWinnable() {
        var wins = 0
        var durations: [Double] = []
        for seed in UInt32(1)...6 {
            let sim = playWithLookahead(seed: seed)
            if sim.phase == .orbit {
                wins += 1
                durations.append(sim.time)
            }
        }
        XCTAssertGreaterThanOrEqual(wins, 3)
        for duration in durations {
            XCTAssertLessThan(duration, 40)
            XCTAssertGreaterThan(duration, 15)
        }
    }

    func testCleanStagingAwardsBonus() {
        var sim = GameSimulation(seed: 7)
        sim = climb(sim, to: GameConfig.stagingStart + 0.5)
        XCTAssertEqual(sim.phase, .hotStaging)
        var events: [GameEvent] = []
        events += sim.step(dt: dt, throttleInput: false)
        for _ in 0..<10 { events += sim.step(dt: dt, throttleInput: false) }
        events += sim.step(dt: dt, throttleInput: true)
        XCTAssertTrue(events.contains(.separation))
        XCTAssertTrue(events.contains(.staged(clean: true)))
        XCTAssertTrue(sim.cleanStaging)
        XCTAssertGreaterThanOrEqual(sim.stylePoints, GameConfig.cleanStagingPoints)
    }

    func testContinueClearsFailure() {
        var sim = GameSimulation(seed: 3)
        for _ in 0..<(60 * 20) where !sim.isOver { _ = sim.step(dt: dt, throttleInput: true) }
        XCTAssertNotNil(sim.failReason)
        sim.applyContinue(removing: nil)
        XCTAssertNil(sim.failReason)
        XCTAssertLessThanOrEqual(sim.rocket.heat, 0.35)
        XCTAssertGreaterThan(sim.graceRemaining, 0)
    }

    func testChallengeCodeRoundTrip() {
        let challenge = Challenge(seed: 123_456_789, score: 12_450)
        XCTAssertEqual(Challenge(code: challenge.code), challenge)
        let url = URL(string: "starbarge://challenge?seed=123456789&score=12450")
        XCTAssertEqual(url.flatMap(Challenge.init(url:)), challenge)
    }

    // MARK: - Helpers

    /// Climbs with a simple heat-aware duty cycle, ignoring obstacles (grace keeps it alive).
    private func climb(_ start: GameSimulation, to altitude: Double) -> GameSimulation {
        var sim = start
        var elapsed = 0.0
        while sim.rocket.altitude < altitude && elapsed < 30 {
            sim.applyContinueIfNeeded()
            // Inside the staging window any release would stage: keep holding.
            let input = sim.phase == .hotStaging || sim.rocket.heat < 0.7 || sim.rocket.velocity < 0
            _ = sim.step(dt: dt, throttleInput: input)
            elapsed += dt
        }
        return sim
    }

    private func playWithLookahead(seed: UInt32) -> GameSimulation {
        var sim = GameSimulation(seed: seed)
        var duty = 1.0
        var nextDecision = 0.0
        var clock = 0.0
        var releaseAt: Double?
        _ = sim.step(dt: dt, throttleInput: true)
        while !sim.isOver && clock < 90 {
            if clock >= nextDecision {
                var best = (-Double.infinity, 0.7)
                for candidate in [0.0, 0.4, 0.7, 1.0] {
                    let value = rollout(sim, duty: candidate)
                    if value > best.0 { best = (value, candidate) }
                }
                duty = best.1
                nextDecision = clock + 0.2
            }
            var input = (clock * 4).truncatingRemainder(dividingBy: 1) < duty
            if sim.phase == .hotStaging && !sim.rocket.staged {
                input = !sim.rocket.throttle
                if !input { releaseAt = clock }
            }
            if let releaseAt, clock - releaseAt < 0.2 { input = false }
            _ = sim.step(dt: dt, throttleInput: input)
            clock += dt
        }
        return sim
    }

    private func rollout(_ start: GameSimulation, duty: Double) -> Double {
        var sim = start
        var t = 0.0
        while t < 2.2 && !sim.isOver {
            var input = (t * 4).truncatingRemainder(dividingBy: 1) < duty
            if sim.phase == .hotStaging && !sim.rocket.staged { input = false }
            _ = sim.step(dt: dt, throttleInput: input)
            t += dt
        }
        return (sim.failReason == nil ? 1000 : 0) + sim.rocket.altitude - sim.rocket.heat * 3
    }
}

private extension GameSimulation {
    /// Test helper: keeps the climb alive through obstacles.
    mutating func applyContinueIfNeeded() {
        if failReason != nil { applyContinue(removing: failObstacleID) }
    }
}
