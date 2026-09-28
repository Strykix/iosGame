import UIKit

/// Rewarded ads only, always opt-in. The game never talks to an ad SDK directly.
@MainActor
protocol AdService: AnyObject {
    var isRewardedReady: Bool { get }
    /// Fired when an ad becomes available or is consumed, so the UI can refresh its buttons.
    var onAvailabilityChanged: (() -> Void)? { get set }
    /// GDPR policy: a way to change privacy choices must stay reachable.
    var needsPrivacyOptions: Bool { get }

    /// Consent (GDPR + ATT), SDK start, first preload. Called once at launch.
    func start() async
    /// Returns true when the reward was earned.
    func showRewarded() async -> Bool
    func presentPrivacyOptions() async
}

enum AdServiceFactory {
    /// - Unit tests: no ads.
    /// - `MOCK_ADS=1` env var (Edit Scheme > Run > Environment): alert mock, works offline.
    /// - Otherwise AdMob (Google test IDs in Debug, yours in Release — see project.yml).
    @MainActor
    static func make() -> AdService {
        let environment = ProcessInfo.processInfo.environment
        if environment["XCTestConfigurationFilePath"] != nil {
            return NoAdService()
        }
        if environment["MOCK_ADS"] == "1" {
            return MockAdService()
        }
        return AdMobService() ?? NoAdService()
    }
}

/// Fallback when ads are unavailable or not configured: rewarded buttons are hidden.
@MainActor
final class NoAdService: AdService {
    var isRewardedReady: Bool { false }
    var onAvailabilityChanged: (() -> Void)?
    var needsPrivacyOptions: Bool { false }
    func start() async {}
    func showRewarded() async -> Bool { false }
    func presentPrivacyOptions() async {}
}

/// Offline mock: a system alert stands in for the ad so the whole flow is testable.
@MainActor
final class MockAdService: AdService {
    var isRewardedReady: Bool { true }
    var onAvailabilityChanged: (() -> Void)?
    var needsPrivacyOptions: Bool { false }

    func start() async {}
    func presentPrivacyOptions() async {}

    func showRewarded() async -> Bool {
        guard let presenter = UIApplication.topViewController() else { return true }
        return await withCheckedContinuation { continuation in
            let alert = UIAlertController(
                title: NSLocalizedString("ad.mock.title", comment: ""),
                message: NSLocalizedString("ad.mock.message", comment: ""),
                preferredStyle: .alert
            )
            alert.addAction(UIAlertAction(title: NSLocalizedString("ad.mock.watch", comment: ""), style: .default) { _ in
                continuation.resume(returning: true)
            })
            alert.addAction(UIAlertAction(title: NSLocalizedString("ad.mock.skip", comment: ""), style: .cancel) { _ in
                continuation.resume(returning: false)
            })
            presenter.present(alert, animated: true)
        }
    }
}
