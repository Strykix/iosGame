import Foundation

enum ProductID {
    static let chromePack = "com.indie.starbarge.pack.chrome"
    static let fleetPack = "com.indie.starbarge.pack.fleet"
    static let all = [chromePack, fleetPack]
}

/// Purely cosmetic skins. Nothing here changes gameplay.
enum Skin: String, Codable, CaseIterable, Identifiable {
    case prototype
    case flight11
    case banana
    case recovered
    case chrome

    var id: String { rawValue }

    enum UnlockRule: Equatable {
        case free
        case reachStaging
        case totalFails(Int)
        case reachOrbit
        case purchase([String])
    }

    var unlockRule: UnlockRule {
        switch self {
        case .prototype: return .free
        case .flight11: return .reachStaging
        case .banana: return .totalFails(10)
        case .recovered: return .reachOrbit
        case .chrome: return .purchase([ProductID.chromePack, ProductID.fleetPack])
        }
    }

    var nameKey: String { "skin.\(rawValue).name" }
    var unlockHintKey: String { "skin.\(rawValue).unlock" }

    var symbol: String {
        switch self {
        case .prototype: return "wrench.and.screwdriver.fill"
        case .flight11: return "11.circle.fill"
        case .banana: return "leaf.fill"
        case .recovered: return "arrow.3.trianglepath"
        case .chrome: return "sparkles"
        }
    }

    /// Skins that the Fleet pack unlocks instantly (everything).
    static let fleetSkins: [Skin] = Skin.allCases
}
