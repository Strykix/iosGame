import Foundation

/// Owns the local JSON save. Single source of truth for progression and settings.
@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var data: SaveData

    private let fileURL: URL?

    init(fileURL: URL? = ProfileStore.defaultURL()) {
        self.fileURL = fileURL
        if let fileURL, let raw = try? Data(contentsOf: fileURL), let decoded = try? JSONDecoder().decode(SaveData.self, from: raw) {
            data = decoded
        } else {
            data = SaveData()
        }
    }

    nonisolated static func defaultURL() -> URL? {
        guard let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("save.json")
    }

    // MARK: - Progression

    struct RunOutcome {
        let isNewBest: Bool
        let cleanStagingStreak: Int
        let newlyUnlocked: [Skin]
    }

    func record(
        score: Int, altitude: Double, failReason: FailReason?,
        reachedStaging: Bool, cleanStaging: Bool, isContinuation: Bool
    ) -> RunOutcome {
        let before = data.unlockedSkins
        let isNewBest = score > data.bestScore
        if !isContinuation { data.totalRuns += 1 }
        data.bestScore = max(data.bestScore, score)
        data.bestAltitude = max(data.bestAltitude, altitude)
        if failReason == nil { data.orbitCount += 1 } else { data.totalFails += 1 }
        if reachedStaging { data.reachedStaging = true }
        // A continued run already updated the clean-staging streak the first time it ended.
        if reachedStaging && !isContinuation {
            data.cleanStagingStreak = cleanStaging ? data.cleanStagingStreak + 1 : 0
            data.bestCleanStagingStreak = max(data.bestCleanStagingStreak, data.cleanStagingStreak)
        }
        refreshUnlocks()
        save()
        let newlyUnlocked = Skin.allCases.filter { data.unlockedSkins.contains($0) && !before.contains($0) }
        return RunOutcome(isNewBest: isNewBest, cleanStagingStreak: data.cleanStagingStreak, newlyUnlocked: newlyUnlocked)
    }

    func isUnlocked(_ skin: Skin) -> Bool {
        data.unlockedSkins.contains(skin)
    }

    func select(_ skin: Skin) {
        guard isUnlocked(skin) else { return }
        data.selectedSkin = skin
        save()
    }

    /// Called by the store whenever entitlements change (purchase, restore, refund).
    func setOwnedProducts(_ products: Set<String>) {
        guard products != data.ownedProducts else { return }
        data.ownedProducts = products
        refreshUnlocks()
        if !data.unlockedSkins.contains(data.selectedSkin) {
            data.selectedSkin = .prototype
        }
        save()
    }

    func setSound(_ enabled: Bool) {
        data.soundEnabled = enabled
        save()
    }

    func setHaptics(_ enabled: Bool) {
        data.hapticsEnabled = enabled
        save()
    }

    private func refreshUnlocks() {
        var unlocked = data.unlockedSkins
        for skin in Skin.allCases {
            switch skin.unlockRule {
            case .free:
                unlocked.insert(skin)
            case .reachStaging:
                if data.reachedStaging { unlocked.insert(skin) }
            case .totalFails(let count):
                if data.totalFails >= count { unlocked.insert(skin) }
            case .reachOrbit:
                if data.orbitCount > 0 { unlocked.insert(skin) }
            case .purchase(let products):
                if products.contains(where: data.ownedProducts.contains) {
                    unlocked.insert(skin)
                } else {
                    unlocked.remove(skin)
                }
            }
        }
        if data.ownedProducts.contains(ProductID.fleetPack) {
            unlocked.formUnion(Skin.fleetSkins)
        }
        data.unlockedSkins = unlocked
    }

    // MARK: - Persistence

    private func save() {
        guard let fileURL else { return }
        do {
            let encoded = try JSONEncoder().encode(data)
            try encoded.write(to: fileURL, options: .atomic)
        } catch {
            #if DEBUG
            print("Save failed: \(error)")
            #endif
        }
    }
}
