import Foundation

/// The five comedic ways a flight can end. No gore, just cartoon physics.
enum FailReason: String, Codable, CaseIterable {
    /// Rapid Unscheduled Disassembly: overheat or debris.
    case rud
    /// Fell too fast / back to the ground.
    case bellyFlop
    /// Tilted past the point of no return by wind shear.
    case turtleMode
    /// Crashed into the camera drone.
    case livestreamEnded
    /// Tank empty, ego intact.
    case outOfFuel

    var titleKey: String { "fail.\(rawValue).title" }
    var subtitleKey: String { "fail.\(rawValue).subtitle" }

    /// Meme lines picked at random on game over (localized keys).
    var memeKeys: [String] {
        switch self {
        case .rud: return ["meme.rud.1", "meme.rud.2", "meme.generic.tweet"]
        case .bellyFlop: return ["meme.bellyflop.1", "meme.bellyflop.2", "meme.generic.tweet"]
        case .turtleMode: return ["meme.turtle.1", "meme.turtle.2"]
        case .livestreamEnded: return ["meme.livestream.1", "meme.livestream.2", "meme.generic.tweet"]
        case .outOfFuel: return ["meme.fuel.1", "meme.fuel.2"]
        }
    }

    var symbol: String {
        switch self {
        case .rud: return "burst.fill"
        case .bellyFlop: return "arrow.down.to.line"
        case .turtleMode: return "tortoise.fill"
        case .livestreamEnded: return "video.slash.fill"
        case .outOfFuel: return "fuelpump.slash.fill"
        }
    }
}

enum FlightPhase: String, Codable {
    case pad
    case boost
    case hotStaging
    case orbitBurn
    case orbit

    var localizationKey: String { "phase.\(rawValue)" }
}

enum GameEvent: Equatable {
    case liftoff
    case enteredStagingWindow
    case separation
    case staged(clean: Bool)
    case nearMiss
    case spicy
    case tierChanged(AltitudeTier)
    case heatWarning
    case failed(FailReason)
    case orbit
}
