import AppTrackingTransparency
import GoogleMobileAds
import UIKit
import UserMessagingPlatform

/// Google AdMob rewarded ads. IDs come from Info.plist, filled per build configuration in project.yml:
/// `GADApplicationIdentifier` (App ID) and `AdMobRewardedUnitID` (rewarded ad unit).
@MainActor
final class AdMobService: NSObject, AdService {
    /// Google's public test IDs. Debug builds use them; never ship them in Release.
    static let testAppID = "ca-app-pub-3940256099942544~1458002511"
    static let testRewardedUnitID = "ca-app-pub-3940256099942544/1712485313"

    var onAvailabilityChanged: (() -> Void)?
    var isRewardedReady: Bool { rewardedAd != nil }
    var needsPrivacyOptions: Bool {
        ConsentInformation.shared.privacyOptionsRequirementStatus == .required
    }

    private let unitID: String
    private var rewardedAd: RewardedAd?
    private var isLoading = false
    private var isStarted = false
    private var retryDelay: TimeInterval = 5
    private var presentation: CheckedContinuation<Bool, Never>?
    private var earnedReward = false

    /// Returns nil when Info.plist has no usable IDs, so the factory falls back to `NoAdService`.
    init?(bundle: Bundle = .main) {
        guard
            let appID = bundle.object(forInfoDictionaryKey: "GADApplicationIdentifier") as? String,
            appID.hasPrefix("ca-app-pub-"),
            let unitID = bundle.object(forInfoDictionaryKey: "AdMobRewardedUnitID") as? String,
            unitID.hasPrefix("ca-app-pub-")
        else { return nil }
        self.unitID = unitID
        super.init()
        #if !DEBUG
        if unitID == Self.testRewardedUnitID {
            print("⚠️ AdMob: Release build is using Google's TEST ad unit. Set your IDs in project.yml.")
        }
        #endif
    }

    // MARK: - Start (consent first, always)

    func start() async {
        guard !isStarted else { return }
        isStarted = true
        await ConsentFlow.run()
        let consent = ConsentInformation.shared
        log("consent status=\(consent.consentStatus.rawValue) canRequestAds=\(consent.canRequestAds)")
        guard consent.canRequestAds else { return }
        _ = await MobileAds.shared.start()
        log("SDK started")
        await loadRewarded()
    }

    func presentPrivacyOptions() async {
        guard let root = UIApplication.topViewController() else { return }
        do {
            try await ConsentForm.presentPrivacyOptionsForm(from: root)
        } catch {
            log("privacy options: \(error.localizedDescription)")
        }
        // Consent may have changed: (re)load if now allowed.
        if ConsentInformation.shared.canRequestAds && rewardedAd == nil {
            _ = await MobileAds.shared.start()
            await loadRewarded()
        }
    }

    // MARK: - Rewarded

    private func loadRewarded() async {
        guard !isLoading, rewardedAd == nil, ConsentInformation.shared.canRequestAds else { return }
        isLoading = true
        do {
            let ad = try await RewardedAd.load(with: unitID, request: Request())
            ad.fullScreenContentDelegate = self
            rewardedAd = ad
            retryDelay = 5
            isLoading = false
            log("rewarded ad ready")
            onAvailabilityChanged?()
        } catch {
            isLoading = false
            log("load failed: \(error.localizedDescription), retry in \(Int(retryDelay))s")
            scheduleRetry()
        }
    }

    /// Exponential backoff (5 s → 10 min) so a flaky network never spams requests.
    private func scheduleRetry() {
        let delay = retryDelay
        retryDelay = min(retryDelay * 2, 600)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            await self?.loadRewarded()
        }
    }

    func showRewarded() async -> Bool {
        guard presentation == nil, let ad = rewardedAd, let root = UIApplication.topViewController() else {
            return false
        }
        rewardedAd = nil
        earnedReward = false
        onAvailabilityChanged?()
        return await withCheckedContinuation { continuation in
            presentation = continuation
            ad.present(from: root) { [weak self] in
                self?.earnedReward = true
            }
        }
    }

    private func finishPresentation() {
        presentation?.resume(returning: earnedReward)
        presentation = nil
        Task { await loadRewarded() }
    }

    private func log(_ message: String) {
        #if DEBUG
        print("AdMob: \(message)")
        #endif
    }
}

extension AdMobService: FullScreenContentDelegate {
    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        finishPresentation()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        log("present failed: \(error.localizedDescription)")
        earnedReward = false
        finishPresentation()
    }
}

/// GDPR consent via Google UMP (mandatory in the EEA), then Apple's App Tracking Transparency.
@MainActor
enum ConsentFlow {
    static func run() async {
        let parameters = RequestParameters()
        #if DEBUG
        // Simulate the EEA so the consent form can be tested from anywhere (simulators are test devices).
        let debugSettings = DebugSettings()
        debugSettings.geography = .EEA
        parameters.debugSettings = debugSettings
        #endif
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: parameters)
            if let root = UIApplication.topViewController() {
                try await ConsentForm.loadAndPresentIfRequired(from: root)
            }
        } catch {
            // Offline or no message configured: fall back to the consent stored from a previous session.
            #if DEBUG
            print("UMP: \(error.localizedDescription)")
            #endif
        }
        await requestTrackingIfNeeded()
    }

    /// Without it, ads are still served, just not personalized.
    private static func requestTrackingIfNeeded() async {
        guard ATTrackingManager.trackingAuthorizationStatus == .notDetermined else { return }
        _ = await ATTrackingManager.requestTrackingAuthorization()
    }
}
