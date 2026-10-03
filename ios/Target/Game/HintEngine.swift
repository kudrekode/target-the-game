import Foundation

struct Hint: Sendable {
    let step: SolutionStep?
    let message: String
}

enum HintEngine {
    static func hint(for state: GameState) -> Hint {
        if state.tiles.contains(where: { $0.value == state.round.target }) {
            return Hint(step: nil, message: "You’ve reached the target!")
        }
        // Resume a certified path only when both IDs and values still match.
        let completed = state.round.solution.lastIndex { step in
            state.tiles.contains { $0.id == step.resultID && $0.value == step.value }
        }
        var steps = Array(state.round.solution.dropFirst(completed.map { $0 + 1 } ?? 0))
        var work = state.tiles
        let verified = !steps.isEmpty && steps.allSatisfy { step in
            guard let a = work.first(where: { $0.id == step.first }),
                  let b = work.first(where: { $0.id == step.second }), a.id != b.id,
                  (try? step.operation.calculate(a.value, b.value)) == step.value else { return false }
            work.removeAll { $0.id == a.id || $0.id == b.id }
            work.append(Tile(id: step.resultID, value: step.value, slot: a.slot))
            return true
        } && work.contains { $0.value == state.round.target }
        if !verified {
            steps = Solver.findSolution(tiles: state.tiles, target: state.round.target, nextID: state.nextID,
                                        maxOperations: state.tiles.count - 1, budget: Balance.hintSearch).steps ?? []
        }
        guard let step = steps.first,
              let a = state.tiles.first(where: { $0.id == step.first }),
              let b = state.tiles.first(where: { $0.id == step.second }) else {
            return Hint(step: nil, message: "No exact path found here. Try undoing a move.")
        }
        let suffix = steps.count > 1 ? " — build toward an exact solution" : " — exact!"
        return Hint(step: step, message: "Try \(a.value) \(step.operation.rawValue) \(b.value)\(suffix)")
    }
}
