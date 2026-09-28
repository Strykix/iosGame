import Foundation

/// Every tuning constant of the game lives here.
/// Units: altitude in km, horizontal position in "screen widths" (x ∈ [-0.5, 0.5]), time in seconds.
enum GameConfig {
    static let karmanLine = 100.0
    static let stagingStart = 36.0
    static let stagingEnd = 44.0
    /// Release → re-press faster than this inside the staging window = CLEAN STAGING.
    static let cleanStagingWindow = 0.55

    static let visibleKm = 6.0
    static let rocketScreenYFraction = 0.26

    static let stackLength = 0.72
    static let shipLength = 0.36
    static let rocketHalfWidth = 0.03

    static let maxTilt = 1.0
    static let fallLimit = -4.2
    static let xLimit = 0.4
    static let driftSpeed = 0.3

    static let spawnDistance = 7.5
    static let nearMissMargin = 0.07

    static let historyDuration = 3.0
    static let continueRewind = 1.5
    static let graceDuration = 1.6

    static let nearMissPoints = 150
    static let cleanStagingPoints = 1000
    static let spicyPoints = 50
    static let orbitPoints = 5000

    struct StageParams {
        let thrust: Double
        let gravity: Double
        let drag: Double
        let heatBase: Double
        let heatPerSpeed: Double
        let cooling: Double
        let fuelBurn: Double
        let stabilize: Double
        let instability: Double
    }

    static let booster = StageParams(
        thrust: 6.4, gravity: 3.0, drag: 0.5,
        heatBase: 0.08, heatPerSpeed: 0.032, cooling: 0.55,
        fuelBurn: 0.07, stabilize: 1.9, instability: 0.35
    )

    static let ship = StageParams(
        thrust: 5.6, gravity: 2.2, drag: 0.32,
        heatBase: 0.1, heatPerSpeed: 0.036, cooling: 0.5,
        fuelBurn: 0.05, stabilize: 1.9, instability: 0.4
    )
}
