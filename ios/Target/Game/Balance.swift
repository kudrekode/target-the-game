import Foundation

enum Balance {
    static let seconds: TimeInterval = 60
    static let targetRange = 100...999
    static let smallRange = 1...10
    static let largePool = [25, 50, 75, 100]
    static let generationAttempts = 180
    static let generationSeconds: TimeInterval = 0.030
    static let mediumLevel = 3
    static let hardLevel = 6
    static let maximumLevel = 8
    static let hintSearch = SearchBudget(nodes: 120_000, seconds: 0.040)
    // Match JavaScript's safe integer range, even on 64-bit iPhones.
    static let maximumValue = 9_007_199_254_740_991
    static let exactPoints = 1_000
    static let proximity: [(distance: Int, points: Int)] = [(5, 500), (10, 300), (25, 150), (50, 75)]
    static let minimumPoints = 25
    static let timePoints = 10
    static let efficiencyPoints = 50
    static let efficiencyOperations = 5
    static let streakStep = 0.1
    static let streakCap = 2.0
}

enum Difficulty: String, CaseIterable, Sendable {
    case easy, medium, hard

    var operations: Int {
        switch self {
        case .easy: 2
        case .medium: 3
        case .hard: 4
        }
    }

    var intensity: Int {
        switch self { case .easy: 1; case .medium: 2; case .hard: 3 }
    }
}
