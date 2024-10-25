import Foundation

enum Operation: String {
    case add = "+"
    case subtract = "-"

    var multiplier: Int {
        self == .add ? 1 : -1
    }
}

struct DiceRoll: Identifiable {
    let id = UUID()
    let count: Int
    let sides: Int
    let results: [Int]
    let operation: Operation

    var sum: Int {
        results.reduce(0, +) * operation.multiplier
    }

    var description: String {
        operation == .subtract ? "-\(count)d\(sides)" : "\(count)d\(sides)"
    }
}

struct Modifier: Identifiable {
    let id = UUID()
    let value: Int
    let operation: Operation

    var description: String {
        "\(operation.rawValue)\(value)"
    }

    var sum: Int {
        value * operation.multiplier
    }
}

struct RollResult: Identifiable {
    let id = UUID()
    let input: String
    let timestamp = Date()
    let diceRolls: [DiceRoll]
    let modifiers: [Modifier]
    let invalidComponents: [(String, String)]  // (invalid text, error message)

    var total: Int {
        diceRolls.map(\.sum).reduce(0, +) + modifiers.map(\.sum).reduce(0, +)
    }

    var formattedTime: String {
        timestamp.formatted(date: .omitted, time: .shortened)
    }
}

