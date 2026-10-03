import Foundation

/// ContinuousClock includes device sleep and ignores wall-clock changes.
/// Backgrounding never extends a deadline. The core accepts injected times in tests.
struct RoundClock: Sendable {
    private let origin = ContinuousClock.now

    func now() -> TimeInterval {
        let duration = origin.duration(to: .now).components
        return Double(duration.seconds) + Double(duration.attoseconds) / 1e18
    }
}
