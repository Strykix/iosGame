import Foundation

enum ObstacleKind: String, Codable {
    case debris
    case cameraDrone
    case windShear
    case turbulence
}

struct Obstacle: Identifiable, Equatable {
    let id: Int
    let kind: ObstacleKind
    /// Center altitude for solids, bottom of the band for wind/turbulence.
    var altitude: Double
    /// Hitbox half-height (solids) or band height (wind/turbulence), in km.
    var height: Double
    var halfWidth: Double
    var x: Double
    /// Horizontal speed (debris) or angular speed (camera drone).
    var speed: Double
    /// Wind direction or debris travel direction (±1).
    var direction: Double
    /// Wind torque, or camera drone swing amplitude.
    var strength: Double
    var phase: Double
    var rotation: Double = 0
    var active = false
    var nearMissAwarded = false

    var isSolid: Bool { kind == .debris || kind == .cameraDrone }

    func contains(altitude alt: Double) -> Bool {
        alt >= altitude && alt <= altitude + height
    }
}

enum AltitudeTier: Int, CaseIterable, Codable {
    case troposphere
    case stratosphere
    case mesosphere

    static func tier(for altitude: Double) -> AltitudeTier {
        switch altitude {
        case ..<12: return .troposphere
        case ..<50: return .stratosphere
        default: return .mesosphere
        }
    }

    var floor: Double {
        switch self {
        case .troposphere: return 0
        case .stratosphere: return 12
        case .mesosphere: return 50
        }
    }

    var localizationKey: String {
        switch self {
        case .troposphere: return "tier.troposphere"
        case .stratosphere: return "tier.stratosphere"
        case .mesosphere: return "tier.mesosphere"
        }
    }
}

/// Deterministic procedural course. Same seed → same obstacles (used for friend challenges).
enum LevelGenerator {
    static func make(seed: UInt32) -> [Obstacle] {
        var rng = SeededRandom(seed: UInt64(seed))
        var list: [Obstacle] = []
        var nextID = 0
        func makeID() -> Int {
            nextID += 1
            return nextID
        }

        // "Turbulence palier": a rough band at each tier boundary.
        for boundary in [12.0, 50.0] {
            list.append(Obstacle(
                id: makeID(), kind: .turbulence, altitude: boundary - 1.5, height: 3,
                halfWidth: 1, x: 0, speed: 0, direction: 1, strength: 1, phase: 0
            ))
        }

        var altitude = 5.0
        while altitude < 96 {
            // Keep the staging window readable.
            if altitude > GameConfig.stagingStart - 2 && altitude < GameConfig.stagingEnd + 2 {
                altitude = GameConfig.stagingEnd + 2.5
                continue
            }
            let tier = AltitudeTier.tier(for: altitude)
            let roll = rng.nextDouble()
            let kind: ObstacleKind
            let spacing: ClosedRange<Double>
            switch tier {
            case .troposphere:
                kind = roll < 0.55 ? .windShear : .cameraDrone
                spacing = 6...8
            case .stratosphere:
                kind = roll < 0.45 ? .debris : (roll < 0.7 ? .windShear : .cameraDrone)
                spacing = 5...7.5
            case .mesosphere:
                kind = roll < 0.55 ? .debris : (roll < 0.85 ? .windShear : .cameraDrone)
                spacing = 4.2...6
            }
            let difficulty = altitude / GameConfig.karmanLine
            let direction: Double = rng.nextBool() ? 1 : -1

            switch kind {
            case .debris:
                list.append(Obstacle(
                    id: makeID(), kind: .debris, altitude: altitude, height: 0.14,
                    halfWidth: 0.05, x: -direction * 0.75,
                    speed: rng.next(in: 0.28...0.42) + difficulty * 0.12,
                    direction: direction, strength: 0,
                    phase: rng.next(in: -2...2)
                ))
            case .cameraDrone:
                list.append(Obstacle(
                    id: makeID(), kind: .cameraDrone, altitude: altitude, height: 0.13,
                    halfWidth: 0.065, x: 0,
                    speed: rng.next(in: 1.3...2.1),
                    direction: direction, strength: rng.next(in: 0.24...0.34),
                    phase: rng.next(in: 0...(2 * .pi))
                ))
            case .windShear:
                list.append(Obstacle(
                    id: makeID(), kind: .windShear, altitude: altitude, height: rng.next(in: 2.5...3.8),
                    halfWidth: 1, x: 0, speed: 0,
                    direction: direction, strength: rng.next(in: 0.7...0.95) + difficulty * 0.3,
                    phase: 0
                ))
            case .turbulence:
                break
            }
            altitude += rng.next(in: spacing)
        }
        return list
    }
}

/// SplitMix64 — tiny, fast, deterministic.
struct SeededRandom: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed &+ 0x9E37_79B9_7F4A_7C15
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func nextDouble() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + nextDouble() * (range.upperBound - range.lowerBound)
    }

    mutating func nextBool() -> Bool {
        next() & 1 == 0
    }
}
