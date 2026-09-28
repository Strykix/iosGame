import UIKit

@MainActor
final class HapticsService {
    var isEnabled = true

    private let light = UIImpactFeedbackGenerator(style: .light)
    private let rigid = UIImpactFeedbackGenerator(style: .rigid)
    private let heavy = UIImpactFeedbackGenerator(style: .heavy)
    private let notification = UINotificationFeedbackGenerator()
    private let selection = UISelectionFeedbackGenerator()

    func prepare() {
        guard isEnabled else { return }
        light.prepare()
        rigid.prepare()
        notification.prepare()
    }

    func throttleTick(intensity: Double) {
        guard isEnabled else { return }
        light.impactOccurred(intensity: CGFloat(min(max(intensity, 0.2), 1)))
    }

    func handle(_ event: GameEvent) {
        guard isEnabled else { return }
        switch event {
        case .liftoff:
            heavy.impactOccurred()
        case .separation:
            rigid.impactOccurred(intensity: 1)
        case .staged(let clean):
            if clean { notification.notificationOccurred(.success) }
        case .nearMiss:
            rigid.impactOccurred(intensity: 0.7)
        case .tierChanged:
            heavy.impactOccurred(intensity: 0.6)
        case .heatWarning:
            notification.notificationOccurred(.warning)
        case .failed:
            heavy.impactOccurred(intensity: 1)
            notification.notificationOccurred(.error)
        case .orbit:
            notification.notificationOccurred(.success)
        case .enteredStagingWindow, .spicy:
            selection.selectionChanged()
        }
    }

    func tap() {
        guard isEnabled else { return }
        selection.selectionChanged()
    }
}
