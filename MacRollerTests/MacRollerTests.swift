import Testing
@testable import MacRoller

struct DiceParserTests {
    // MARK: - Valid Input Tests

    @Test func basicDiceRoll() async throws {
        let result = DiceParser.parse("2d6")

        #expect(result.diceRolls.count == 1)
        #expect(result.diceRolls[0].count == 2)
        #expect(result.diceRolls[0].sides == 6)
        #expect(result.diceRolls[0].operation == .add)
        #expect(result.diceRolls[0].results.count == 2)
        #expect(result.diceRolls[0].results.allSatisfy { $0 >= 1 && $0 <= 6 })

        #expect(result.modifiers.isEmpty)
        #expect(result.invalidComponents.isEmpty)
    }

    @Test func implicitSingleDie() async throws {
        let result = DiceParser.parse("d20")

        #expect(result.diceRolls.count == 1)
        #expect(result.diceRolls[0].count == 1)
        #expect(result.diceRolls[0].sides == 20)
        #expect(result.diceRolls[0].results.count == 1)
        #expect(result.diceRolls[0].results[0] >= 1 && result.diceRolls[0].results[0] <= 20)
    }

    @Test func complexExpression() async throws {
        let result = DiceParser.parse("2d6 + d4 - 3 + 5")

        #expect(result.diceRolls.count == 2)
        #expect(result.modifiers.count == 2)

        // First dice roll
        #expect(result.diceRolls[0].count == 2)
        #expect(result.diceRolls[0].sides == 6)
        #expect(result.diceRolls[0].operation == .add)

        // Second dice roll
        #expect(result.diceRolls[1].count == 1)
        #expect(result.diceRolls[1].sides == 4)
        #expect(result.diceRolls[1].operation == .add)

        // Modifiers
        #expect(result.modifiers[0].value == 3)
        #expect(result.modifiers[0].operation == .subtract)
        #expect(result.modifiers[1].value == 5)
        #expect(result.modifiers[1].operation == .add)
    }

    // MARK: - Invalid Input Tests

    @Test func multipleDCharacters() async throws {
        let result = DiceParser.parse("2d6d4")

        #expect(result.diceRolls.isEmpty)
        #expect(result.invalidComponents.count == 1)
        #expect(result.invalidComponents[0].0 == "2d6d4")
        #expect(result.invalidComponents[0].1 == "Multiple 'd' characters")
    }

    @Test func invalidCharacters() async throws {
        let result = DiceParser.parse("2d6f")

        #expect(result.diceRolls.isEmpty)
        #expect(result.invalidComponents.count == 1)
        #expect(result.invalidComponents[0].0 == "2d6f")
        #expect(result.invalidComponents[0].1 == "Invalid character: f")
    }

    @Test func zeroDice() async throws {
        let result = DiceParser.parse("0d6")

        #expect(result.diceRolls.isEmpty)
        #expect(result.invalidComponents.count == 1)
        #expect(result.invalidComponents[0].0 == "0d6")
        #expect(result.invalidComponents[0].1 == "Invalid number of dice")
    }

    @Test func zeroSides() async throws {
        let result = DiceParser.parse("2d0")

        #expect(result.diceRolls.isEmpty)
        #expect(result.invalidComponents.count == 1)
        #expect(result.invalidComponents[0].0 == "2d0")
        #expect(result.invalidComponents[0].1 == "Invalid dice size")
    }

    // MARK: - Edge Cases

    @Test func whitespaceHandling() async throws {
        let result = DiceParser.parse("  2d6  +  3  ")

        #expect(result.diceRolls.count == 1)
        #expect(result.modifiers.count == 1)
        #expect(result.invalidComponents.isEmpty)
    }

    @Test func caseInsensitivity() async throws {
        let result = DiceParser.parse("2D6")

        #expect(result.diceRolls.count == 1)
        #expect(result.diceRolls[0].count == 2)
        #expect(result.diceRolls[0].sides == 6)
    }

    @Test func emptyString() async throws {
        let result = DiceParser.parse("")

        #expect(result.diceRolls.isEmpty)
        #expect(result.modifiers.isEmpty)
        #expect(result.invalidComponents.isEmpty)
    }
}
