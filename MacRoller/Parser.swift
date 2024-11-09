import Foundation

struct DiceParser {
    static func parse(_ input: String, _ d10StartsAt0: Bool = false) -> RollResult {
        // trim whitespace and lowercase all letters
        let normalized = input.trimmingCharacters(in: .whitespaces).lowercased()

        var diceRolls: [DiceRoll] = []
        var modifiers: [Modifier] = []
        var invalidComponents: [(String, String)] = []

        let components = normalized.components(separatedBy: CharacterSet(charactersIn: "+-"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let operators = normalized.matches(of: /[+-]/).map { String($0.0) }

        for (i, component) in components.enumerated() {
            let operation = i == 0 && !(normalized.hasPrefix("+") || normalized.hasPrefix("-"))
                ? .add
                : (Operation(rawValue: operators[i - 1]) ?? .add)

            if component.contains("d") {
                // If there are multiple 'd', error
                if component.filter({ $0 == "d" }).count > 1 {
                    invalidComponents.append((component, "Multiple 'd' characters"))
                    continue
                }

                // If there's anything but 'd', numbers and whitespace, error
                let validCharacters = CharacterSet.decimalDigits
                    .union(CharacterSet(charactersIn: "d"))
                    .union(CharacterSet.whitespaces)

                let invalidChars = component.unicodeScalars
                    .filter { !validCharacters.contains($0) }
                    .map(String.init)

                if !invalidChars.isEmpty {
                    invalidComponents.append((component,
                                              "Invalid character\(invalidChars.count > 1 ? "s" : ""): \(invalidChars.joined(separator: ", "))"
                                              ))
                    continue
                }

                let parts = component.components(separatedBy: "d")
                               .map { $0.trimmingCharacters(in: .whitespaces) }

                let count = parts[0].isEmpty ? 1 : (Int(parts[0]) ?? 0)
                let sides = Int(parts[1]) ?? 0

                if count <= 0 {
                    invalidComponents.append((component, "Invalid number of dice"))
                    continue
                }
                if sides <= 0 {
                    invalidComponents.append((component, "Invalid dice size"))
                    continue
                }
                let results: [Int]
                if sides == 10 && d10StartsAt0 {
                    results = (0..<count).map { _ in Int.random(in: 0...9) }
                } else {
                    results = (0..<count).map { _ in Int.random(in: 1...sides) }
                }
                diceRolls.append(DiceRoll(count: count, sides: sides, results: results, operation: operation))
            } else if let value = Int(component) {
                modifiers.append(Modifier(value: value, operation: operation))
            } else {
                invalidComponents.append((component, "Invalid input"))
            }
        }

        return RollResult(
            input: input,
            diceRolls: diceRolls,
            modifiers: modifiers,
            invalidComponents: invalidComponents
        )
    }
}
