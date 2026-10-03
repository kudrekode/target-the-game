import SwiftUI
import Observation

@MainActor
@Observable
final class GameViewModel {
    enum Screen { case home, game, result, stats }
    struct Merge {
        let original: [Tile]
        let first: Tile
        let second: Tile
        var converged = false
    }

    private(set) var screen: Screen = .home
    private(set) var game: GameState?
    private(set) var stats: Stats
    private(set) var streak = 0
    private(set) var seconds: TimeInterval = Balance.seconds
    private(set) var firstID: Int?
    private(set) var operation: Operation?
    private(set) var message = "Number → operator → number"
    private(set) var merge: Merge?
    private(set) var newTileID: Int?
    private(set) var rejectedIDs: Set<Int> = []
    private(set) var rejection = 0
    private(set) var busy = false
    private(set) var active = true
    var reduceMotion = false

    @ObservationIgnored private let clock = RoundClock()
    @ObservationIgnored private let store: StatsStore
    @ObservationIgnored private let feedback = FeedbackService()
    @ObservationIgnored private let audio = AudioService()
    @ObservationIgnored private var mergeTask: Task<Void, Never>?
    @ObservationIgnored private var hintTask: Task<Void, Never>?
    @ObservationIgnored private var version = 0
    @ObservationIgnored private var revision = 0
    @ObservationIgnored private var settled = false
    @ObservationIgnored private var lastWarning = 11
    @ObservationIgnored private var messageDeadline: TimeInterval = 0

    init(store: StatsStore = StatsStore()) {
        self.store = store
        stats = store.load()
    }

    var result: RoundResult? { game?.result }
    var tiles: [Tile] { merge?.original ?? game?.tiles ?? [] }
    var first: Tile? { game?.tiles.first { $0.id == firstID } }
    var canUndo: Bool { !(game?.history.isEmpty ?? true) && !busy && active }
    var liveScore: Int {
        guard let game else { return 0 }
        return Scoring.score(distance: abs(game.closest.value - game.round.target), seconds: 0,
                             operations: game.operations, streak: streak + 1).base
    }

    func start() {
        cancelWork()
        version += 1
        revision = 0
        settled = false
        lastWarning = 11
        game = GameState(round: RoundGenerator().generate(streak: streak), now: clock.now())
        seconds = Balance.seconds
        firstID = nil
        operation = nil
        newTileID = nil
        rejectedIDs = []
        message = "Number → operator → number"
        screen = .game
        feedback.lightTap()
    }

    func home() {
        guard screen != .game else { return }
        cancelWork()
        screen = .home
    }

    func showStats() { screen = .stats; feedback.lightTap() }

    func selectOperation(_ selected: Operation) {
        guard acceptInput(), firstID != nil else { return }
        operation = selected
        feedback.lightTap()
        audio.play(.tile)
    }

    func selectTile(_ id: Int) {
        guard acceptInput(), let current = game,
              let tile = current.tiles.first(where: { $0.id == id }) else { return }
        feedback.lightTap()
        audio.play(.tile)
        if id == firstID { firstID = nil; operation = nil; return }
        guard let firstID, let operation,
              let first = current.tiles.first(where: { $0.id == firstID }) else {
            self.firstID = id
            return
        }
        let now = clock.now()
        do {
            let resultTile = try game!.combine(first: firstID, operation: operation, second: id, now: now)
            revision += 1
            hintTask?.cancel()
            self.firstID = nil
            self.operation = nil
            rejectedIDs = []
            busy = true
            newTileID = resultTile.id
            setMessage("\(first.value) \(operation.rawValue) \(tile.value) = \(resultTile.value)")
            // Preserve exact scoring at the successful tap, before the merge animation.
            if resultTile.value == current.round.target { settle(at: now, reveal: false) }
            let currentVersion = version
            merge = Merge(original: current.tiles, first: first, second: tile)
            mergeTask = Task { [weak self] in
                guard let self else { return }
                do {
                    if !reduceMotion {
                        try await Task.sleep(for: .milliseconds(16))
                        withAnimation(DesignSystem.Motion.merge) { self.merge?.converged = true }
                        try await Task.sleep(for: .milliseconds(170))
                    }
                    guard version == currentVersion, screen == .game else { return }
                    withAnimation(reduceMotion ? nil : DesignSystem.Motion.spring) { self.merge = nil }
                    if active { feedback.mergeImpact(); audio.play(.merge) }
                    if game?.result?.exact == true, !reduceMotion {
                        try await Task.sleep(for: .milliseconds(180))
                    }
                    guard version == currentVersion, screen == .game else { return }
                    busy = false
                    settle(at: clock.now(), reveal: true)
                } catch { /* Lifecycle cancellation settles the committed move synchronously. */ }
            }
        } catch {
            rejectedIDs = [firstID, id]
            withAnimation(reduceMotion ? nil : .linear(duration: 0.25)) { rejection += 1 }
            feedback.invalidImpact()
            audio.play(.invalid)
            setMessage(error.localizedDescription)
        }
    }

    func undo() {
        guard acceptInput(), game!.undo(now: clock.now()) else { return }
        revision += 1
        hintTask?.cancel()
        firstID = nil
        operation = nil
        newTileID = nil
        rejectedIDs = []
        feedback.lightTap()
        setMessage("Last combination undone.")
        // The browser reward stub always succeeds: subsequent undos stay available.
    }

    func hint() {
        guard acceptInput(), let snapshot = game else { return }
        feedback.lightTap()
        hintTask?.cancel()
        let currentVersion = version, currentRevision = revision
        setMessage("Finding a path…")
        // The bounded search runs off the UI thread; stale hints never overwrite new moves.
        hintTask = Task { [weak self] in
            let hint = await Task.detached(priority: .userInitiated) { HintEngine.hint(for: snapshot) }.value
            guard !Task.isCancelled, let self, version == currentVersion, revision == currentRevision,
                  screen == .game, active, !busy else { return }
            tick()
            guard screen == .game else { return }
            setMessage(hint.message, duration: 5)
        }
    }

    func tick() {
        guard screen == .game, let game else { return }
        seconds = game.result?.seconds ?? game.remaining(at: clock.now())
        if !busy { settle(at: clock.now(), reveal: true) }
        guard screen == .game, game.result == nil else { return }
        let whole = Int(ceil(seconds))
        if active, whole > 0, whole <= 10, whole < lastWarning {
            lastWarning = whole
            audio.play(.countdown)
            if whole <= 3 { feedback.warningImpact() }
        }
        if clock.now() >= messageDeadline, !busy { message = "Number → operator → number" }
    }

    func sceneChanged(active isActive: Bool) {
        active = isActive
        if !isActive {
            audio.stop()
            hintTask?.cancel()
            mergeTask?.cancel()
            merge = nil
            busy = false
        }
        // Deadlines keep running while inactive, suspended, or locked.
        tick()
    }

    private func acceptInput() -> Bool {
        guard screen == .game, active, !busy else { return false }
        tick()
        return screen == .game && game?.result == nil
    }

    private func settle(at now: TimeInterval, reveal: Bool) {
        guard let result = game?.finishIfNeeded(now: now, streak: streak) else { return }
        seconds = result.seconds
        if !settled {
            settled = true
            streak = result.streak
            stats.record(result)
            store.save(stats)
        }
        if reveal, screen == .game {
            if active {
                if result.exact { feedback.successImpact(); audio.play(.exact) }
                else if result.distance <= 10 { feedback.lightTap() }
            }
            screen = .result
        }
    }

    private func setMessage(_ value: String, duration: TimeInterval = 3.5) {
        message = value
        messageDeadline = clock.now() + duration
    }

    private func cancelWork() {
        mergeTask?.cancel()
        hintTask?.cancel()
        merge = nil
        busy = false
    }
}
