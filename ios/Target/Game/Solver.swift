import Foundation

struct SearchBudget: Sendable {
    let nodes: Int
    let seconds: TimeInterval
}

struct SearchResult: Sendable {
    let steps: [SolutionStep]?
    let complete: Bool
    let nodes: Int
}

/// Iterative depth search returns the shortest path it proves within a bounded budget.
/// Failure keys use values; returned paths retain IDs for duplicate tiles and undo.
enum Solver {
    static func findSolution(tiles: [Tile], target: Int, nextID: Int,
                             maxOperations: Int, budget: SearchBudget) -> SearchResult {
        var search = Search(target: target, budget: budget)
        for depth in 0...max(0, min(maxOperations, tiles.count - 1)) {
            if let steps = search.visit(tiles, depth: depth, nextID: nextID) {
                return SearchResult(steps: steps, complete: true, nodes: search.nodes)
            }
            if search.limited { break }
        }
        return SearchResult(steps: nil, complete: !search.limited, nodes: search.nodes)
    }

    private struct Key: Hashable { let depth: Int; let values: [Int] }

    private struct Search {
        let target: Int
        let budget: SearchBudget
        let clock = RoundClock()
        var nodes = 0
        var limited = false
        var failed: Set<Key> = []

        mutating func visit(_ tiles: [Tile], depth: Int, nextID: Int) -> [SolutionStep]? {
            if tiles.contains(where: { $0.value == target }) { return [] }
            guard depth > 0, tiles.count >= 2 else { return nil }
            nodes += 1
            guard nodes <= budget.nodes, clock.now() < budget.seconds else { limited = true; return nil }
            let key = Key(depth: depth, values: tiles.map(\.value).sorted())
            guard !failed.contains(key) else { return nil }
            var moves: [SolutionStep] = []
            for i in tiles.indices {
                for j in tiles.indices where i != j {
                    for operation in Operation.allCases {
                        if operation.isCommutative && j < i { continue }
                        guard let value = try? operation.calculate(tiles[i].value, tiles[j].value),
                              value != tiles[i].value, value != tiles[j].value else { continue }
                        moves.append(SolutionStep(first: tiles[i].id, second: tiles[j].id,
                                                  operation: operation, value: value, resultID: nextID))
                    }
                }
            }
            moves.sort { abs($0.value - target) < abs($1.value - target) }
            for move in moves {
                let rest = tiles.filter { $0.id != move.first && $0.id != move.second }
                let tile = Tile(id: nextID, value: move.value, slot: 0)
                if let tail = visit(rest + [tile], depth: depth - 1, nextID: nextID + 1) {
                    return [move] + tail
                }
                if limited { return nil }
            }
            failed.insert(key)
            return nil
        }
    }
}
