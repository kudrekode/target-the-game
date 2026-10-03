import XCTest
#if !CORE_TEST_RUNNER
@testable import Target
#endif

final class TargetCoreTests: XCTestCase {
    func testAddition() throws { XCTAssertEqual(try Operation.add.calculate(25, 8), 33) }
    func testSubtraction() throws { XCTAssertEqual(try Operation.subtract.calculate(8, 3), 5) }
    func testMultiplication() throws { XCTAssertEqual(try Operation.multiply.calculate(25, 8), 200) }
    func testIntegerDivision() throws { XCTAssertEqual(try Operation.divide.calculate(100, 4), 25) }

    func testInvalidDivision() {
        XCTAssertThrowsError(try Operation.divide.calculate(8, 3)) { XCTAssertEqual($0 as? MoveError, .nonIntegerDivision) }
        XCTAssertThrowsError(try Operation.divide.calculate(8, 0))
    }

    func testInvalidSubtraction() {
        for b in [8, 9] {
            XCTAssertThrowsError(try Operation.subtract.calculate(8, b)) { XCTAssertEqual($0 as? MoveError, .nonPositive) }
        }
    }

    func testSafeIntegerLimits() {
        XCTAssertThrowsError(try Operation.add.calculate(Balance.maximumValue, 1))
        XCTAssertThrowsError(try Operation.multiply.calculate(Int.max, 2))
    }

    func testScoringTiersAndTime() {
        for (distance, base) in [(0, 1000), (1, 500), (5, 500), (6, 300), (10, 300), (11, 150),
                                 (25, 150), (26, 75), (50, 75), (51, 25)] {
            let score = Scoring.score(distance: distance, seconds: 12.9, operations: 3, streak: 1)
            XCTAssertEqual(score.base, base)
            XCTAssertEqual(score.time, 120)
            XCTAssertEqual(score.efficiency, distance == 0 ? 50 : 0)
            XCTAssertEqual(score.total, base + 120 + (distance == 0 ? 50 : 0))
        }
        XCTAssertEqual(Scoring.score(distance: 0, seconds: 0, operations: 6, streak: 1).efficiency, 0)
        XCTAssertEqual(Scoring.score(distance: 0, seconds: 0, operations: 5, streak: 2).total, 1155)
        XCTAssertEqual(Scoring.score(distance: 1, seconds: 0, operations: 1, streak: 8).factor, 1)
    }

    func testStreakProgression() {
        XCTAssertEqual(Streak.next(4, exact: true), 5)
        XCTAssertEqual(Streak.next(4, exact: false), 0)
        XCTAssertEqual(Streak.difficulty(for: 0), .easy)
        XCTAssertEqual(Streak.difficulty(for: 1), .easy)
        XCTAssertEqual(Streak.difficulty(for: 2), .medium)
        XCTAssertEqual(Streak.difficulty(for: 4), .medium)
        XCTAssertEqual(Streak.difficulty(for: 5), .hard)
        XCTAssertEqual(Streak.multiplier(for: 1), 1)
        XCTAssertEqual(Streak.multiplier(for: 3), 1.2, accuracy: 0.00001)
        XCTAssertEqual(Streak.multiplier(for: 50), 2)
    }

    func testGeneratedRoundsAreExactlySolvable() throws {
        var random = SeededRandom(seed: 82719)
        for (band, streak) in [(Difficulty.easy, 0), (.medium, 2), (.hard, 5)] {
            var fallbackCount = 0
            var totalDepth = 0
            for _ in 0..<1_000 {
                let round = RoundGenerator().generate(streak: streak, using: &random)
                XCTAssertEqual(round.numbers.count, 6)
                XCTAssertTrue(round.numbers.prefix(4).allSatisfy { Balance.smallRange.contains($0) })
                XCTAssertTrue(round.numbers.suffix(2).allSatisfy { Balance.largePool.contains($0) })
                XCTAssertEqual(Set(round.numbers.suffix(2)).count, 2)
                XCTAssertTrue(Balance.targetRange.contains(round.target))
                XCTAssertFalse(round.numbers.contains(round.target))
                XCTAssertTrue(round.difficulty == band || round.difficulty == .easy)
                XCTAssertTrue(round.difficulty.operationRange.contains(round.solution.count))
                if round.difficulty != band { fallbackCount += 1 }
                totalDepth += round.solution.count
                // Independent arithmetic replay, rather than trusting the generator or calculate().
                var work = Dictionary(uniqueKeysWithValues: round.numbers.enumerated().map { ($0.offset, $0.element) })
                for step in round.solution {
                    XCTAssertNotEqual(step.first, step.second)
                    let a = try XCTUnwrap(work.removeValue(forKey: step.first))
                    let b = try XCTUnwrap(work.removeValue(forKey: step.second))
                    let value: Int
                    switch step.operation {
                    case .add: value = a + b
                    case .subtract: value = a - b
                    case .multiply: value = a * b
                    case .divide: XCTAssertEqual(a % b, 0); value = a / b
                    }
                    XCTAssertGreaterThan(value, 0)
                    XCTAssertLessThanOrEqual(value, Balance.maximumValue)
                    XCTAssertEqual(value, step.value)
                    XCTAssertNil(work[step.resultID])
                    work[step.resultID] = value
                }
                XCTAssertTrue(work.values.contains(round.target))
                var used: Set<Int> = [try XCTUnwrap(round.solution.last).resultID]
                for step in round.solution.reversed() where used.contains(step.resultID) {
                    used.insert(step.first); used.insert(step.second)
                }
                XCTAssertTrue(round.solution.allSatisfy { used.contains($0.resultID) })
            }
            print("\(band.rawValue): 1000/1000 exact; emergency fallbacks \(fallbackCount); mean depth \(Double(totalDepth) / 1000)")
        }
    }

    func testDifficultyShortcutSample() {
        var random = SeededRandom(seed: 9162)
        for streak in [2, 5] {
            var shortcuts = 0
            for _ in 0..<10 {
                let round = RoundGenerator().generate(streak: streak, using: &random)
                let result = Solver.findSolution(tiles: round.initialTiles, target: round.target, nextID: 6,
                                                 maxOperations: Streak.difficulty(for: streak).operationRange.lowerBound - 1,
                                                 budget: SearchBudget(nodes: 1_000_000, seconds: 1))
                if result.steps != nil { shortcuts += 1 }
            }
            // Difficulty rejects shortcuts when budgets permit; it is deliberately not an absolute promise.
            print("Streak \(streak): \(shortcuts)/10 sampled rounds have a shorter path")
        }
    }

    func testHintCertifiedIntermediatePath() throws {
        var state = intermediateState()
        XCTAssertEqual(HintEngine.hint(for: state).step?.operation, .multiply)
        _ = try state.combine(first: 0, operation: .multiply, second: 1, now: 1)
        let hint = HintEngine.hint(for: state)
        XCTAssertEqual(hint.step?.first, 3)
        XCTAssertEqual(hint.step?.value, 347)
    }

    func testHintSearchCanMoveAwayFromTarget() throws {
        var state = GameState(round: Round(target: 200, numbers: [25, 7, 1], difficulty: .easy, solution: []), now: 0)
        let hint = try XCTUnwrap(HintEngine.hint(for: state).step)
        XCTAssertEqual(hint.operation, .add)
        XCTAssertEqual(hint.value, 8)
        _ = try state.combine(first: hint.first, operation: hint.operation, second: hint.second, now: 1)
        let next = try XCTUnwrap(HintEngine.hint(for: state).step)
        XCTAssertEqual(next.operation, .multiply)
        XCTAssertEqual(next.value, 200)
    }

    func testHintAfterUndoUsesFreshIDs() throws {
        var state = intermediateState()
        _ = try state.combine(first: 0, operation: .multiply, second: 1, now: 1)
        XCTAssertTrue(state.undo(now: 2))
        _ = try state.combine(first: 0, operation: .multiply, second: 1, now: 3)
        XCTAssertEqual(state.nextID, 5)
        let step = try XCTUnwrap(HintEngine.hint(for: state).step)
        XCTAssertTrue(step.first == 4 || step.second == 4)
        XCTAssertEqual(step.value, 347)
    }

    func testUnsolvableHintIsHonest() {
        let state = GameState(round: Round(target: 999, numbers: [2, 3], difficulty: .easy, solution: []), now: 0)
        let hint = HintEngine.hint(for: state)
        XCTAssertNil(hint.step)
        XCTAssertTrue(hint.message.contains("Try undoing"))
    }

    func testSolverHonoursBudget() {
        let tiles = [2, 3, 4, 5, 25, 75].enumerated().map { Tile(id: $0.offset, value: $0.element, slot: $0.offset) }
        let result = Solver.findSolution(tiles: tiles, target: 999, nextID: 6, maxOperations: 5,
                                         budget: SearchBudget(nodes: 0, seconds: 1))
        XCTAssertNil(result.steps)
        XCTAssertFalse(result.complete)
    }

    func testSolverDuplicateValuesKeepDistinctIDs() throws {
        let tiles = [2, 2, 25].enumerated().map { Tile(id: $0.offset, value: $0.element, slot: $0.offset) }
        let result = Solver.findSolution(tiles: tiles, target: 100, nextID: 3, maxOperations: 2,
                                         budget: SearchBudget(nodes: 100_000, seconds: 1))
        let steps = try XCTUnwrap(result.steps)
        XCTAssertEqual(steps.count, 2)
        XCTAssertTrue(steps.allSatisfy { $0.first != $0.second })
        XCTAssertEqual(steps.last?.value, 100)
    }

    func testUndoRestoresTilesAndSlots() throws {
        var state = intermediateState()
        let original = state.tiles
        _ = try state.combine(first: 1, operation: .add, second: 2, now: 1)
        XCTAssertEqual(state.tiles.first { $0.id == 3 }?.slot, 1)
        XCTAssertEqual(state.operations, 1)
        XCTAssertTrue(state.undo(now: 2))
        XCTAssertEqual(state.tiles, original)
        XCTAssertEqual(state.operations, 0)
        XCTAssertEqual(state.undoCount, 1)
        XCTAssertEqual(state.nextID, 4)
        XCTAssertFalse(state.undo(now: 3))
    }

    func testAdditionalUndosRemainAvailable() throws {
        var state = intermediateState()
        for second in [1.0, 3.0] {
            _ = try state.combine(first: 0, operation: .add, second: 1, now: second)
            XCTAssertTrue(state.undo(now: second + 1))
        }
        XCTAssertEqual(state.undoCount, 2)
    }

    func testInvalidMoveDoesNotMutateState() {
        var state = intermediateState()
        let original = state.tiles
        XCTAssertThrowsError(try state.combine(first: 1, operation: .divide, second: 2, now: 1))
        XCTAssertEqual(state.tiles, original)
        XCTAssertEqual(state.operations, 0)
        XCTAssertTrue(state.history.isEmpty)
        XCTAssertEqual(state.nextID, 3)
        XCTAssertThrowsError(try state.combine(first: 1, operation: .add, second: 1, now: 1))
    }

    func testDeadlineCannotBeExtendedByUndoOrInactivity() throws {
        var state = intermediateState()
        _ = try state.combine(first: 0, operation: .multiply, second: 1, now: 1)
        XCTAssertTrue(state.undo(now: 59))
        XCTAssertEqual(state.deadline, 60)
        XCTAssertEqual(state.remaining(at: 61), 0)
        XCTAssertFalse(state.undo(now: 61))
        XCTAssertThrowsError(try state.combine(first: 0, operation: .add, second: 1, now: 61))
        let result = try XCTUnwrap(state.finishIfNeeded(now: 61, streak: 3))
        XCTAssertFalse(result.exact)
        XCTAssertEqual(result.seconds, 0)
        XCTAssertEqual(result.streak, 0)
    }

    func testClosestUsesCurrentTiles() throws {
        var state = GameState(round: Round(target: 100, numbers: [99, 20, 2], difficulty: .easy, solution: []), now: 0)
        XCTAssertEqual(state.closest.value, 99)
        _ = try state.combine(first: 0, operation: .add, second: 1, now: 1)
        XCTAssertEqual(state.closest.value, 119) // A consumed tile is not a historic best.
    }

    func testExactFinishesOnceAtMoveTime() throws {
        var state = GameState(round: Round(target: 200, numbers: [25, 8, 3], difficulty: .easy, solution: []), now: 100)
        _ = try state.combine(first: 0, operation: .multiply, second: 1, now: 120.25)
        let result = try XCTUnwrap(state.finishIfNeeded(now: 120.25, streak: 1))
        XCTAssertTrue(result.exact)
        XCTAssertEqual(result.seconds, 39.75)
        XCTAssertEqual(result.streak, 2)
        XCTAssertEqual(result.score.total, 1584)
        XCTAssertEqual(state.finishIfNeeded(now: 500, streak: 50), result)
        XCTAssertFalse(state.undo(now: 121))
        XCTAssertThrowsError(try state.combine(first: 2, operation: .add, second: 3, now: 121))
    }

    func testOneRemainingTileEndsRound() throws {
        var state = GameState(round: Round(target: 100, numbers: [25, 3], difficulty: .easy, solution: []), now: 0)
        _ = try state.combine(first: 0, operation: .multiply, second: 1, now: 5)
        let result = try XCTUnwrap(state.finishIfNeeded(now: 5.17, streak: 2))
        XCTAssertEqual(result.distance, 25)
        XCTAssertEqual(result.score.base, 150)
        XCTAssertEqual(result.score.time, 540)
        XCTAssertEqual(result.streak, 0)
    }

    func testStatsRecordAndPersistence() throws {
        let suite = "target-tests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = StatsStore(defaults: defaults)
        XCTAssertEqual(store.load(), Stats())
        var stats = Stats()
        let result = RoundResult(target: 200, closest: 200, seconds: 10, operations: 1, streak: 4,
                                 score: Scoring.score(distance: 0, seconds: 10, operations: 1, streak: 4))
        stats.record(result)
        store.save(stats)
        XCTAssertEqual(store.load(), stats)
        XCTAssertEqual(stats.roundsPlayed, 1)
        XCTAssertEqual(stats.exactSolutions, 1)
        XCTAssertEqual(stats.bestStreak, 4)
        XCTAssertEqual(stats.bestScore, result.score.total)
        defaults.set(Data("not-json".utf8), forKey: "target.stats.v1")
        XCTAssertEqual(store.load(), Stats())
        var corrupt = Stats(); corrupt.totalScore = -1
        defaults.set(try JSONEncoder().encode(corrupt), forKey: "target.stats.v1")
        XCTAssertEqual(store.load(), Stats())
    }

    #if !CORE_TEST_RUNNER
    @MainActor
    func testTimerAdvancesWithoutInputAndRestartsAfterInactivity() async throws {
        let model = GameViewModel()
        model.start(round: Round(target: 347, numbers: [50, 7, 3], difficulty: .easy, solution: []))
        defer { model.sceneChanged(active: false) }
        let initial = model.seconds
        try await Task.sleep(for: .milliseconds(350))
        XCTAssertLessThan(model.seconds, initial - 0.2)
        model.sceneChanged(active: false)
        let paused = model.seconds
        try await Task.sleep(for: .milliseconds(250))
        model.sceneChanged(active: true)
        XCTAssertLessThan(model.seconds, paused - 0.2)
        let resumed = model.seconds
        try await Task.sleep(for: .milliseconds(250))
        XCTAssertLessThan(model.seconds, resumed - 0.1)
    }

    @MainActor
    func testMergeCanChainOrSwitchToIndependentNumbersAndUndo() async throws {
        let model = GameViewModel()
        let round = Round(target: 999, numbers: [2, 3, 4, 5, 25, 50], difficulty: .easy, solution: [])
        model.start(round: round)
        defer { model.sceneChanged(active: false) }
        model.selectTile(0)
        model.selectOperation(.add)
        model.selectTile(1)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertFalse(model.busy)
        XCTAssertEqual(model.first?.value, 5)
        XCTAssertNil(model.operation)
        // Start an independent calculation, retaining the first result in its slot.
        model.selectTile(2)
        XCTAssertEqual(model.firstID, 2)
        model.selectOperation(.multiply)
        model.selectTile(3)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(model.first?.value, 20)
        XCTAssertEqual(model.game?.tiles.first { $0.id == 6 }?.value, 5)
        model.selectOperation(.add)
        model.selectTile(6)
        try await Task.sleep(for: .milliseconds(400))
        XCTAssertEqual(model.first?.value, 25)
        XCTAssertEqual(model.game?.operations, 3)
        model.undo()
        XCTAssertNil(model.firstID)
        XCTAssertNil(model.operation)
        XCTAssertEqual(model.game?.tiles.map(\.value), [5, 20, 25, 50])
        XCTAssertEqual(model.game?.operations, 2)
    }
    #endif

    private func intermediateState() -> GameState {
        GameState(round: Round(target: 347, numbers: [50, 7, 3], difficulty: .easy,
                               solution: [SolutionStep(first: 0, second: 1, operation: .multiply, value: 350, resultID: 3),
                                          SolutionStep(first: 3, second: 2, operation: .subtract, value: 347, resultID: 4)]), now: 0)
    }
}

private struct SeededRandom: RandomNumberGenerator {
    var seed: UInt64
    mutating func next() -> UInt64 {
        seed = seed &* 6364136223846793005 &+ 1442695040888963407
        return seed
    }
}
