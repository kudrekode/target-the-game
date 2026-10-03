import Foundation

struct Stats: Codable, Equatable, Sendable {
    var totalScore = 0
    var bestScore = 0 // Best individual round, matching the browser.
    var roundsPlayed = 0
    var exactSolutions = 0
    var bestStreak = 0

    mutating func record(_ result: RoundResult) {
        roundsPlayed += 1
        totalScore += result.score.total
        bestScore = max(bestScore, result.score.total)
        exactSolutions += result.exact ? 1 : 0
        bestStreak = max(bestStreak, result.streak)
    }

    var isValid: Bool {
        [totalScore, bestScore, roundsPlayed, exactSolutions, bestStreak].allSatisfy { $0 >= 0 }
    }
}
