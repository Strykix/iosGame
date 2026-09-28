#if DEBUG
/// Look-ahead bot for demos and App Store screenshots (`-autopilot` launch argument).
/// DEBUG only: it is never compiled into a release build.
struct Autopilot {
    private static let dt = 1.0 / 60
    private static let candidates = [0.0, 0.25, 0.5, 0.65, 0.8, 1.0]

    private var duty = 1.0
    private var nextDecision = 0.0
    private var releaseAt: Double?

    mutating func throttle(for sim: GameSimulation) -> Bool {
        if sim.phase == .pad { return true }
        let time = sim.time
        if time >= nextDecision {
            duty = Self.candidates.max { rollout(sim, duty: $0) < rollout(sim, duty: $1) } ?? 0.7
            nextDecision = time + 0.1
        }
        var input = (time * 4).truncatingRemainder(dividingBy: 1) < duty
        // Clean staging: release once inside the window, then press again quickly.
        if sim.phase == .hotStaging && !sim.rocket.staged {
            input = !sim.rocket.throttle
            if !input { releaseAt = time }
        }
        if let releaseAt, time - releaseAt < 0.2 { input = false }
        return input
    }

    /// Simulates ~2 s ahead with a fixed duty cycle; survival first, then altitude, minus heat.
    private func rollout(_ start: GameSimulation, duty: Double) -> Double {
        var sim = start
        var t = 0.0
        while t < 2.2 && !sim.isOver {
            var input = (t * 4).truncatingRemainder(dividingBy: 1) < duty
            if sim.phase == .hotStaging && !sim.rocket.staged { input = false }
            _ = sim.step(dt: Self.dt, throttleInput: input)
            t += Self.dt
        }
        let survived = sim.failReason == nil ? 1000.0 : 0
        return survived + sim.rocket.altitude - sim.rocket.heat * 3
    }
}
#endif
