import Foundation

struct GameState: Sendable {
    let round: Round
    let deadline: TimeInterval
    private(set) var tiles: [Tile]
    private(set) var history: [[Tile]] = []
    private(set) var operations = 0
    private(set) var undoCount = 0
    private(set) var nextID: Int
    private(set) var result: RoundResult?

    init(round: Round, now: TimeInterval) {
        self.round = round
        tiles = round.initialTiles
        nextID = round.numbers.count
        deadline = now + Balance.seconds
    }

    func remaining(at now: TimeInterval) -> TimeInterval { max(0, deadline - now) }

    var closest: Tile {
        tiles.min { abs($0.value - round.target) < abs($1.value - round.target) }!
    }

    mutating func combine(first: Int, operation: Operation, second: Int, now: TimeInterval) throws -> Tile {
        guard result == nil, remaining(at: now) > 0 else { throw MoveError.roundEnded }
        guard first != second,
              let a = tiles.first(where: { $0.id == first }),
              let b = tiles.first(where: { $0.id == second }) else { throw MoveError.differentTiles }
        let value = try operation.calculate(a.value, b.value)
        history.append(tiles)
        let tile = Tile(id: nextID, value: value, slot: a.slot)
        nextID += 1
        tiles = tiles.filter { $0.id != b.id }.map { $0.id == a.id ? tile : $0 }
        operations += 1
        return tile
    }

    @discardableResult
    mutating func undo(now: TimeInterval) -> Bool {
        guard result == nil, remaining(at: now) > 0, let previous = history.popLast() else { return false }
        tiles = previous
        operations -= 1
        undoCount += 1
        // IDs stay monotonic: never reuse an undone result's ID.
        return true
    }

    /// Exactly once settlement. Exact moves use their tap time before UI animation.
    @discardableResult
    mutating func finishIfNeeded(now: TimeInterval, streak: Int) -> RoundResult? {
        if let result { return result }
        let nearest = closest.value
        let distance = abs(nearest - round.target)
        guard distance == 0 || tiles.count == 1 || remaining(at: now) == 0 else { return nil }
        let nextStreak = Streak.next(streak, exact: distance == 0)
        let seconds = remaining(at: now)
        let finished = RoundResult(target: round.target, closest: nearest, seconds: seconds,
                                   operations: operations, streak: nextStreak,
                                   score: Scoring.score(distance: distance, seconds: seconds,
                                                        operations: operations, streak: nextStreak))
        result = finished
        return finished
    }
}
