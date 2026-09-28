import Foundation

/// Everything persisted locally, as JSON in Application Support.
struct SaveData: Codable, Equatable {
    var bestScore = 0
    var bestAltitude = 0.0
    var totalRuns = 0
    var totalFails = 0
    var orbitCount = 0
    var reachedStaging = false
    var cleanStagingStreak = 0
    var bestCleanStagingStreak = 0
    var unlockedSkins: Set<Skin> = [.prototype]
    var selectedSkin: Skin = .prototype
    var ownedProducts: Set<String> = []
    var soundEnabled = true
    var hapticsEnabled = true

    init() {}

    // Tolerant decoding: new fields added in updates never wipe an existing save.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = SaveData()
        bestScore = try c.decodeIfPresent(Int.self, forKey: .bestScore) ?? defaults.bestScore
        bestAltitude = try c.decodeIfPresent(Double.self, forKey: .bestAltitude) ?? defaults.bestAltitude
        totalRuns = try c.decodeIfPresent(Int.self, forKey: .totalRuns) ?? defaults.totalRuns
        totalFails = try c.decodeIfPresent(Int.self, forKey: .totalFails) ?? defaults.totalFails
        orbitCount = try c.decodeIfPresent(Int.self, forKey: .orbitCount) ?? defaults.orbitCount
        reachedStaging = try c.decodeIfPresent(Bool.self, forKey: .reachedStaging) ?? defaults.reachedStaging
        cleanStagingStreak = try c.decodeIfPresent(Int.self, forKey: .cleanStagingStreak) ?? defaults.cleanStagingStreak
        bestCleanStagingStreak = try c.decodeIfPresent(Int.self, forKey: .bestCleanStagingStreak) ?? defaults.bestCleanStagingStreak
        let skins = try c.decodeIfPresent([String].self, forKey: .unlockedSkins) ?? []
        unlockedSkins = Set(skins.compactMap(Skin.init(rawValue:))).union([.prototype])
        let selected = try c.decodeIfPresent(String.self, forKey: .selectedSkin).flatMap(Skin.init(rawValue:))
        selectedSkin = selected ?? defaults.selectedSkin
        ownedProducts = try c.decodeIfPresent(Set<String>.self, forKey: .ownedProducts) ?? defaults.ownedProducts
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? defaults.soundEnabled
        hapticsEnabled = try c.decodeIfPresent(Bool.self, forKey: .hapticsEnabled) ?? defaults.hapticsEnabled
    }
}

/// Outcome of one flight, handed to the game-over screen.
struct RunResult: Equatable {
    let seed: UInt32
    let score: Int
    let altitude: Double
    let failReason: FailReason?
    let cleanStaging: Bool
    let nearMisses: Int
    let duration: Double
    let isNewBest: Bool
    let cleanStagingStreak: Int
    let newlyUnlocked: [Skin]
    let reachedStaging: Bool
    let memeKey: String

    var reachedOrbit: Bool { failReason == nil }
}
