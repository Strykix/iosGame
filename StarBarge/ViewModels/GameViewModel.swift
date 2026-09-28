import SpriteKit
import SwiftUI

/// Orchestrates a flight: scene ⇄ HUD ⇄ progression ⇄ ads ⇄ share.
@MainActor
final class GameViewModel: ObservableObject {
    enum Screen: Equatable {
        case launch
        case run
        case gameOver
    }

    @Published private(set) var screen: Screen = .launch
    @Published private(set) var hud = HUDSnapshot()
    @Published private(set) var result: RunResult?
    @Published private(set) var shareImage: UIImage?
    @Published private(set) var challenge: Challenge?
    @Published private(set) var secondChanceUsed = false
    @Published private(set) var isShowingAd = false
    @Published var showHangar = false

    let scene: GameScene
    let profile: ProfileStore
    let store: StoreService
    let ads: AdService
    private let sound = SoundEngine()
    private let haptics = HapticsService()
    private var currentSeed: UInt32 = 1
    private var isContinuation = false
    private var lastHeatTick = Date.distantPast

    init(profile: ProfileStore, store: StoreService, ads: AdService) {
        self.profile = profile
        self.store = store
        self.ads = ads
        scene = GameScene(size: CGSize(width: 390, height: 844))
        scene.scaleMode = .resizeFill
        scene.gameDelegate = self
        store.onEntitlementsChanged = { [weak profile] owned in
            profile?.setOwnedProducts(owned)
        }
        // A rewarded ad finishing its load must reveal the "continue" buttons on the game-over screen.
        ads.onAvailabilityChanged = { [weak self] in
            self?.objectWillChange.send()
        }
        prepareRun()
    }

    func onAppear() {
        applySettings()
        sound.start()
        haptics.prepare()
        Task { await store.start() }
        Task { await ads.start() }
    }

    func applySettings() {
        sound.isEnabled = profile.data.soundEnabled
        haptics.isEnabled = profile.data.hapticsEnabled
        scene.applySkin(profile.data.selectedSkin)
    }

    // MARK: - Flow

    /// Screen 1 → 2. The scene waits for the first hold to lift off.
    func launch() {
        haptics.tap()
        sound.play(.ui)
        screen = .run
    }

    /// Instant restart from the game-over screen.
    func relaunch() {
        haptics.tap()
        prepareRun()
        screen = .run
    }

    func backToMenu() {
        prepareRun()
        screen = .launch
    }

    func openHangar() {
        haptics.tap()
        showHangar = true
    }

    func hangarClosed() {
        applySettings()
    }

    func appWillResignActive() {
        scene.releaseAllTouches()
        sound.setEngine(throttle: false, velocity: 0, active: false)
    }

    private func prepareRun() {
        currentSeed = challenge?.seed ?? UInt32.random(in: 1...UInt32.max)
        secondChanceUsed = false
        isContinuation = false
        result = nil
        shareImage = nil
        scene.prepareRun(seed: currentSeed, skin: profile.data.selectedSkin)
    }

    // MARK: - Challenges (deep links)

    func handle(url: URL) {
        guard let parsed = Challenge(url: url) else { return }
        challenge = parsed
        showHangar = false
        prepareRun()
        screen = .launch
    }

    func clearChallenge() {
        challenge = nil
        prepareRun()
    }

    // MARK: - Second chance (rewarded, opt-in, once per run)

    var canUseSecondChance: Bool {
        ads.isRewardedReady && !secondChanceUsed && result?.reachedOrbit == false && !scene.history.isEmpty
    }

    var canRetryFromStaging: Bool {
        canUseSecondChance && scene.stagingSnapshot != nil
    }

    func continueWithAd() async {
        guard canUseSecondChance, let failed = scene.failedSimulation else { return }
        guard await watchAd() else { return }
        let rewind = Int(GameConfig.continueRewind * 60)
        let index = max(0, scene.history.count - 1 - rewind)
        var state = scene.history[index]
        state.applyContinue(removing: failed.failObstacleID)
        resume(from: state)
    }

    func retryFromStagingWithAd() async {
        guard canRetryFromStaging, var state = scene.stagingSnapshot else { return }
        guard await watchAd() else { return }
        state.prepareStagingRetry()
        resume(from: state)
    }

    private func watchAd() async -> Bool {
        isShowingAd = true
        let rewarded = await ads.showRewarded()
        isShowingAd = false
        return rewarded
    }

    private func resume(from state: GameSimulation) {
        secondChanceUsed = true
        isContinuation = true
        result = nil
        shareImage = nil
        scene.resume(from: state)
        screen = .run
    }

    // MARK: - Share

    var shareText: String {
        guard let result else { return ShareConfig.hashtag }
        return ShareService.shareText(for: result)
    }

    var xShareURL: URL? {
        result.flatMap(ShareService.xIntentURL(for:))
    }

    func shareToStories() {
        guard let image = shareImage else { return }
        if !ShareService.shareToStories(image: image) {
            ActivitySheet.present(items: [image, shareText])
        }
    }

    // MARK: - Results

    private func finishRun() {
        let final = scene.failedSimulation ?? scene.simulation
        let reason = final.failReason
        let outcome = profile.record(
            score: final.score,
            altitude: final.maxAltitude,
            failReason: reason,
            reachedStaging: final.didReachStaging,
            cleanStaging: final.cleanStaging,
            isContinuation: isContinuation
        )
        let run = RunResult(
            seed: final.seed,
            score: final.score,
            altitude: final.maxAltitude,
            failReason: reason,
            cleanStaging: final.cleanStaging,
            nearMisses: final.nearMisses,
            duration: final.time,
            isNewBest: outcome.isNewBest,
            cleanStagingStreak: outcome.cleanStagingStreak,
            newlyUnlocked: outcome.newlyUnlocked,
            reachedStaging: final.didReachStaging,
            memeKey: memeKey(reason: reason, altitude: final.maxAltitude)
        )
        result = run
        sound.setEngine(throttle: false, velocity: 0, active: false)
        screen = .gameOver
        // Render the share card after the game-over screen is up, so it never delays it.
        let skin = profile.data.selectedSkin
        Task { [weak self] in
            await Task.yield()
            guard let self, self.result == run else { return }
            self.shareImage = ShareService.renderCard(for: run, skin: skin)
        }
    }

    private func memeKey(reason: FailReason?, altitude: Double) -> String {
        guard let reason else {
            return ["meme.orbit.1", "meme.orbit.2"].randomElement() ?? "meme.orbit.1"
        }
        if altitude >= 80 && Bool.random() {
            return "meme.almost"
        }
        return reason.memeKeys.randomElement() ?? "meme.rud.1"
    }
}

// MARK: - GameSceneDelegate

extension GameViewModel: GameSceneDelegate {
    func gameScene(_ scene: GameScene, didEmit event: GameEvent) {
        haptics.handle(event)
        sound.play(for: event)
    }

    func gameScene(_ scene: GameScene, didUpdate hud: HUDSnapshot) {
        self.hud = hud
        let flying = screen == .run && !hud.waitingForTouch && hud.phase != .pad
        sound.setEngine(throttle: hud.throttle, velocity: hud.velocity, active: flying)
        if flying && hud.throttle && hud.heat > 0.75 && Date().timeIntervalSince(lastHeatTick) > 0.25 {
            lastHeatTick = Date()
            haptics.throttleTick(intensity: hud.heat)
        }
    }

    func gameSceneDidFinishRun(_ scene: GameScene) {
        finishRun()
    }
}

/// Fallback share sheet (used for Stories when Instagram isn't configured).
@MainActor
enum ActivitySheet {
    static func present(items: [Any]) {
        guard let presenter = UIApplication.topViewController() else { return }
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        controller.popoverPresentationController?.sourceView = presenter.view
        presenter.present(controller, animated: true)
    }
}
