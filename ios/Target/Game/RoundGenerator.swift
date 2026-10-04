import Foundation

struct RoundGenerator {
    let attemptLimit: Int
    let timeBudget: TimeInterval

    init(attemptLimit: Int = Balance.generationAttempts, timeBudget: TimeInterval = Balance.generationSeconds) {
        self.attemptLimit = attemptLimit
        self.timeBudget = timeBudget
    }

    func generate(level: Int = 0) -> Round {
        var random = SystemRandomNumberGenerator()
        return generate(level: level, using: &random)
    }

    func generate<R: RandomNumberGenerator>(level: Int, using random: inout R) -> Round {
        let difficulty = DifficultyProgression.difficulty(for: level)
        let clock = RoundClock()
        for _ in 0..<max(0, attemptLimit) {
            if clock.now() >= timeBudget { break }
            var numbers = (0..<4).map { _ in Int.random(in: Balance.smallRange, using: &random) }
            var pool = Balance.largePool
            for _ in 0..<2 { numbers.append(pool.remove(at: Int.random(in: pool.indices, using: &random))) }
            var work = numbers.enumerated().map { Tile(id: $0.offset, value: $0.element, slot: $0.offset) }
            var steps: [SolutionStep] = []
            let count = difficulty.operations
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
                    if !Solver.canReachWithin(numbers: numbers, target: final.value, maxOperations: count - 1) { return candidate }
                }
            }
        }
        return fallback(difficulty: difficulty)
    }

    func fallback(difficulty: Difficulty) -> Round {
        // Same certificates as the browser, independently checked for minimum
        // depth by the core tests. Exhausting generation never changes the band.
        switch difficulty {
        case .easy:
            return Round(target: 189, numbers: [6, 4, 4, 9, 50, 25], difficulty: difficulty, solution: [
                SolutionStep(first: 5, second: 1, operation: .subtract, value: 21, resultID: 6),
                SolutionStep(first: 3, second: 6, operation: .multiply, value: 189, resultID: 7),
            ])
        case .medium:
            return Round(target: 215, numbers: [1, 3, 9, 8, 50, 25], difficulty: difficulty, solution: [
                SolutionStep(first: 3, second: 1, operation: .multiply, value: 24, resultID: 6),
                SolutionStep(first: 2, second: 6, operation: .multiply, value: 216, resultID: 7),
                SolutionStep(first: 7, second: 0, operation: .subtract, value: 215, resultID: 8),
            ])
        case .hard:
            return Round(target: 557, numbers: [5, 4, 9, 8, 75, 50], difficulty: difficulty, solution: [
                SolutionStep(first: 5, second: 2, operation: .multiply, value: 450, resultID: 6),
                SolutionStep(first: 1, second: 3, operation: .multiply, value: 32, resultID: 7),
                SolutionStep(first: 7, second: 6, operation: .add, value: 482, resultID: 8),
                SolutionStep(first: 8, second: 4, operation: .add, value: 557, resultID: 9),
            ])
        }
    }
}
