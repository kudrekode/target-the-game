enum Streak {
    static func difficulty(for count: Int) -> Difficulty {
        count >= 5 ? .hard : count >= 2 ? .medium : .easy
    }

    static func next(_ count: Int, exact: Bool) -> Int { exact ? count + 1 : 0 }

    static func multiplier(for count: Int) -> Double {
        min(Balance.streakCap, 1 + Double(max(0, count - 1)) * Balance.streakStep)
    }
}
