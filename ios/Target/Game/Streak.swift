enum Streak {
    static func next(_ count: Int, exact: Bool) -> Int { exact ? count + 1 : 0 }

    static func multiplier(for count: Int) -> Double {
        min(Balance.streakCap, 1 + Double(max(0, count - 1)) * Balance.streakStep)
    }
}

// Session skill survives a broken scoring streak. Each result moves one step,
// and the cap means a run of wins never makes relief unreachable.
enum DifficultyProgression {
    static func difficulty(for level: Int) -> Difficulty {
        level >= Balance.hardLevel ? .hard : level >= Balance.mediumLevel ? .medium : .easy
    }

    static func next(_ level: Int, exact: Bool) -> Int {
        max(0, min(Balance.maximumLevel, level + (exact ? 1 : -1)))
    }
}
