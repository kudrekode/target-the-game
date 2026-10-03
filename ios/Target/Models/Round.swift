import Foundation

struct Tile: Identifiable, Equatable, Sendable {
    let id: Int
    let value: Int
    // Six physical board positions persist through combinations and undo.
    let slot: Int
}

struct SolutionStep: Equatable, Sendable {
    let first: Int
    let second: Int
    let operation: Operation
    let value: Int
    let resultID: Int
}

struct Round: Sendable {
    let target: Int
    let numbers: [Int]
    let difficulty: Difficulty
    let solution: [SolutionStep]

    var initialTiles: [Tile] {
        numbers.enumerated().map { Tile(id: $0.offset, value: $0.element, slot: $0.offset) }
    }
}

struct RoundResult: Equatable, Sendable {
    let target: Int
    let closest: Int
    let seconds: TimeInterval
    let operations: Int
    let streak: Int
    let score: Score
    var distance: Int { abs(closest - target) }
    var exact: Bool { distance == 0 }
    var title: String {
        exact ? "EXACT" : distance == 1 ? "ONE AWAY" : distance <= 10 ? "SO CLOSE" : "ROUND OVER"
    }
}
