import UIKit

@MainActor
final class FeedbackService {
    private let light = UIImpactFeedbackGenerator(style: .light)
    private let merge = UIImpactFeedbackGenerator(style: .medium)
    private let notification = UINotificationFeedbackGenerator()

    func lightTap() { light.impactOccurred(intensity: 0.6) }
    func mergeImpact() { merge.impactOccurred(intensity: 0.8) }
    func invalidImpact() { notification.notificationOccurred(.error) }
    func successImpact() { notification.notificationOccurred(.success) }
    func warningImpact() { light.impactOccurred(intensity: 0.4) }
}
