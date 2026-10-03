import Foundation

struct RoundGenerator {
    func generate(streak: Int = 0) -> Round {
        var random = SystemRandomNumberGenerator()
        return generate(streak: streak, using: &random)
    }

    func generate<R: RandomNumberGenerator>(streak: Int, using random: inout R) -> Round {
        let difficulty = Streak.difficulty(for: streak)
        let clock = RoundClock()
        var fallback: Round?
        for _ in 0..<Balance.generationAttempts {
            var numbers = (0..<4).map { _ in Int.random(in: Balance.smallRange, using: &random) }
            var pool = Balance.largePool
            for _ in 0..<2 { numbers.append(pool.remove(at: Int.random(in: pool.indices, using: &random))) }
            var work = numbers.enumerated().map { Tile(id: $0.offset, value: $0.element, slot: $0.offset) }
            var steps: [SolutionStep] = []
            let count = Int.random(in: difficulty.operationRange, using: &random)
            for index in 0..<count {
                let aIndex = Int.random(in: work.indices, using: &random)
                let bIndex = (aIndex + Int.random(in: 1..<work.count, using: &random)) % work.count
                let a = work[aIndex], b = work[bIndex]
                let legal = Operation.allCases.compactMap { operation -> SolutionStep? in
                    guard let value = try? operation.calculate(a.value, b.value),
                          value != a.value, value != b.value else { return nil }
                    return SolutionStep(first: a.id, second: b.id, operation: operation,
                                        value: value, resultID: numbers.count + index)
                }
                guard let move = legal.randomElement(using: &random) else { break }
                steps.append(move)
                work.remove(at: max(aIndex, bIndex))
                work.remove(at: min(aIndex, bIndex))
                work.append(Tile(id: move.resultID, value: move.value, slot: a.slot))
            }
            if let final = steps.last, steps.count == count,
               Balance.targetRange.contains(final.value), !numbers.contains(final.value) {
                // Every generated move must contribute to the final expression.
                var used: Set<Int> = [final.resultID]
                for step in steps.reversed() where used.contains(step.resultID) {
                    used.insert(step.first); used.insert(step.second)
                }
                if steps.allSatisfy({ used.contains($0.resultID) }) {
                    let candidate = Round(target: final.value, numbers: numbers, difficulty: difficulty, solution: steps)
                    if fallback == nil { fallback = candidate }
                    if difficulty == .easy { return candidate }
                    let shallow = Solver.findSolution(tiles: candidate.initialTiles, target: candidate.target,
                                                      nextID: 6, maxOperations: difficulty.operationRange.lowerBound - 1,
                                                      budget: Balance.generationSearch)
                    if shallow.complete && shallow.steps == nil { return candidate }
                    if clock.now() >= Balance.generationSeconds { break }
                }
            }
        }
        if let fallback { return fallback }
        // Certified emergency fallback, just as in the browser. Difficulty is a heuristic.
        return Round(target: 200, numbers: [2, 3, 7, 8, 25, 75], difficulty: .easy,
                     solution: [SolutionStep(first: 4, second: 3, operation: .multiply, value: 200, resultID: 6)])
    }
}
