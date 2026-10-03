import Foundation

struct Score: Equatable, Sendable {
    let base: Int
    let time: Int
    let efficiency: Int
    let factor: Double
    var total: Int { Int((Double(base + time + efficiency) * factor).rounded()) }
}

enum Scoring {
    static func score(distance: Int, seconds: TimeInterval, operations: Int, streak: Int) -> Score {
        let exact = distance == 0
        let base = exact ? Balance.exactPoints :
            Balance.proximity.first(where: { distance <= $0.distance })?.points ?? Balance.minimumPoints
        return Score(base: base,
                     time: Int(max(0, seconds).rounded(.down)) * Balance.timePoints,
                     efficiency: exact && operations <= Balance.efficiencyOperations ? Balance.efficiencyPoints : 0,
                     factor: exact ? Streak.multiplier(for: streak) : 1)
    }
}
