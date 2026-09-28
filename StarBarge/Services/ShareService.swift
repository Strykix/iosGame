import SwiftUI
import UIKit

/// Viral loop: pre-filled text, challenge deep link (same seed = same course), X intent, IG Stories.
enum ShareConfig {
    static let urlScheme = "starbarge"
    static let hashtag = "#StarBarge"
    /// Set to your universal-link domain (e.g. "https://dontpop.app/c") once you host one.
    /// Custom-scheme links are not clickable inside X / Instagram, universal links are.
    static let webChallengeBase: String? = nil
    /// Required by Instagram for Stories sharing. Leave nil to fall back to the share sheet.
    static let facebookAppID: String? = nil
}

struct Challenge: Equatable {
    let seed: UInt32
    let score: Int

    /// Short human code shown on screen, e.g. "K3F9Q-12450".
    var code: String {
        "\(String(seed, radix: 36).uppercased())-\(score)"
    }

    init(seed: UInt32, score: Int) {
        self.seed = seed
        self.score = score
    }

    init?(code: String) {
        let parts = code.uppercased().split(separator: "-")
        guard parts.count == 2, let seed = UInt32(parts[0], radix: 36), let score = Int(parts[1]) else {
            return nil
        }
        self.init(seed: seed, score: score)
    }

    /// starbarge://challenge?seed=123&score=4567  or  starbarge://c/K3F9Q-4567
    init?(url: URL) {
        let isAppScheme = url.scheme == ShareConfig.urlScheme
        let isWebLink = ShareConfig.webChallengeBase.map { url.absoluteString.hasPrefix($0) } ?? false
        guard isAppScheme || isWebLink else { return nil }
        let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []
        if let seedText = items.first(where: { $0.name == "seed" })?.value, let seed = UInt32(seedText) {
            let score = items.first { $0.name == "score" }?.value.flatMap(Int.init) ?? 0
            self.init(seed: seed, score: score)
        } else if let last = url.pathComponents.last, let parsed = Challenge(code: last) {
            self = parsed
        } else {
            return nil
        }
    }

    var link: String {
        if let base = ShareConfig.webChallengeBase {
            return "\(base)/\(code)"
        }
        return "\(ShareConfig.urlScheme)://challenge?seed=\(seed)&score=\(score)"
    }
}

@MainActor
enum ShareService {
    static func shareText(for result: RunResult) -> String {
        let challenge = Challenge(seed: result.seed, score: result.score)
        let altitude = String(format: "%.1f", result.altitude)
        let headline: String
        if result.reachedOrbit {
            headline = String(format: NSLocalizedString("share.text.orbit", comment: ""), result.score)
        } else {
            headline = String(
                format: NSLocalizedString("share.text.fail", comment: ""),
                altitude, NSLocalizedString(result.memeKey, comment: "")
            )
        }
        let dare = String(format: NSLocalizedString("share.text.dare", comment: ""), result.score, challenge.code)
        return "\(headline)\n\(dare)\n\(challenge.link)\n\(ShareConfig.hashtag)"
    }

    static func xIntentURL(for result: RunResult) -> URL? {
        var components = URLComponents(string: "https://x.com/intent/post")
        components?.queryItems = [URLQueryItem(name: "text", value: shareText(for: result))]
        return components?.url
    }

    /// Renders the 9:16 share card (Stories format).
    static func renderCard(for result: RunResult, skin: Skin) -> UIImage? {
        let renderer = ImageRenderer(content: ShareCardView(result: result, skin: skin).frame(width: 360, height: 640))
        renderer.scale = 3
        return renderer.uiImage
    }

    /// Instagram Stories. Returns false when not possible (no app id / app not installed).
    static func shareToStories(image: UIImage) -> Bool {
        guard
            let appID = ShareConfig.facebookAppID,
            let url = URL(string: "instagram-stories://share?source_application=\(appID)"),
            UIApplication.shared.canOpenURL(url),
            let data = image.pngData()
        else { return false }
        UIPasteboard.general.setItems(
            [["com.instagram.sharedSticker.backgroundImage": data]],
            options: [.expirationDate: Date().addingTimeInterval(300)]
        )
        UIApplication.shared.open(url)
        return true
    }
}
