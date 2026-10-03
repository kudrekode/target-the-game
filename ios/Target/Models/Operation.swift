import Foundation

enum Operation: String, CaseIterable, Sendable {
    case add = "+", subtract = "−", multiply = "×", divide = "÷"

    var name: String {
        switch self {
        case .add: "Add"
        case .subtract: "Subtract"
        case .multiply: "Multiply"
        case .divide: "Divide"
        }
    }

    var isCommutative: Bool { self == .add || self == .multiply }

    func calculate(_ a: Int, _ b: Int) throws -> Int {
        guard a > 0, b > 0 else { throw MoveError.nonPositive }
        let result: Int
        let overflow: Bool
        switch self {
        case .add: (result, overflow) = a.addingReportingOverflow(b)
        case .subtract:
            guard a > b else { throw MoveError.nonPositive }
            (result, overflow) = a.subtractingReportingOverflow(b)
        case .multiply: (result, overflow) = a.multipliedReportingOverflow(by: b)
        case .divide:
            guard a % b == 0 else { throw MoveError.nonIntegerDivision }
            result = a / b
            overflow = false
        }
        guard !overflow, result <= Balance.maximumValue else { throw MoveError.tooLarge }
        return result
    }
}

enum MoveError: Error, Equatable, LocalizedError {
    case differentTiles, nonPositive, nonIntegerDivision, tooLarge, roundEnded

    var errorDescription: String? {
        switch self {
        case .differentTiles: "Select two different numbers."
        case .nonPositive: "Result must be positive."
        case .nonIntegerDivision: "Must divide evenly."
        case .tooLarge: "Result is too large."
        case .roundEnded: "This round has ended."
        }
    }
}
