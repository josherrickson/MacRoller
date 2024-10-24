import SwiftUI
import RegexBuilder

// MARK: - Models
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

    var total: Int {
        diceRolls.map(\.sum).reduce(0, +) + modifiers.map(\.sum).reduce(0, +)
    }

    var formattedTime: String {
        timestamp.formatted(date: .omitted, time: .shortened)
    }
}

// MARK: - Parser
struct DiceParser {
    static func parse(_ input: String) -> RollResult {
        let normalized = input.trimmingCharacters(in: .whitespaces)

        var diceRolls: [DiceRoll] = []
        var modifiers: [Modifier] = []

        let components = normalized.components(separatedBy: CharacterSet(charactersIn: "+-"))
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        let operators = normalized.matches(of: /[+-]/).map { String($0.0) }

        for (i, component) in components.enumerated() {
            // For first component, use + if no operator present
            let operation = i == 0 && !(normalized.hasPrefix("+") || normalized.hasPrefix("-"))
                ? .add
                : (Operation(rawValue: operators[i - 1]) ?? .add)

            if component.contains("d") {
                guard component.filter({ $0 == "d" }).count == 1 else {
                    continue  // Skip invalid components with multiple 'd's
                }
                print(component)

                let parts = component.components(separatedBy: "d")
                                   .map { $0.trimmingCharacters(in: .whitespaces) }
                print(parts)
                let count = parts[0].isEmpty ? 1 : (Int(parts[0]) ?? 1)
                if let sides = Int(parts[1]), count > 0, sides > 0 {
                    let results = (0..<count).map { _ in Int.random(in: 1...sides) }
                    diceRolls.append(DiceRoll(count: count, sides: sides, results: results, operation: operation))
                }
            } else if let value = Int(component) {
                modifiers.append(Modifier(value: value, operation: operation))
            }
        }

        return RollResult(
            input: input,
            diceRolls: diceRolls,
            modifiers: modifiers
        )
    }
}

// MARK: - Views
struct ResultView: View {
    let result: RollResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(result.diceRolls) { roll in
                HStack {
                    Text("\(roll.description): [\(roll.results.map(String.init).joined(separator: ", "))]")
                        .font(.body)
                    if roll.results.count > 1 {
                        Text("Sum: \(roll.sum)")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
            }

            ForEach(result.modifiers) { modifier in
                Text(modifier.description)
                    .font(.body)
            }

            Divider()

            Text("Total: \(result.total)")
                .font(.title3)
                .fontWeight(.bold)
        }
    }
}

struct HistoryItemView: View {
    let result: RollResult
    let onReuse: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.input)
                        .font(.caption)
                    Spacer()
                    Text(result.formattedTime)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                Text("Result: \(result.total)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Button(action: onReuse) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ContentView: View {
    @State private var diceInput = "2d20 + 1"
    @State private var rollResult: RollResult?
    @State private var rollHistory: [RollResult] = []
    @State private var showHistory = false
    @AppStorage("historyEnabled") private var historyEnabled = false

    var body: some View {
        VStack(spacing: 12) {
            // Menu Button
            HStack {
                Text("MacRoll")
                    .font(.title)
                    .fontWeight(.bold)
                Spacer()
                Menu {
                    Toggle("Enable History", isOn: Binding(
                        get: { historyEnabled },
                        set: { isEnabled in
                            if !isEnabled {
                                // Clear history when disabling
                                rollHistory.removeAll()
                                showHistory = false
                            }
                            historyEnabled = isEnabled
                        }
                    ))
                    Divider()
                    Button("Quit", action: {
                        NSApplication.shared.terminate(nil)
                    })
                } label: {
                    Image(systemName: "gear")
                        .foregroundColor(.secondary)
                        .frame(width: 20, height: 20)
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
            .padding(.bottom, 4)

            // Main content
            TextField("Enter dice roll (e.g. 3d20 + 2)", text: $diceInput)
                .textFieldStyle(.roundedBorder)
                .onSubmit(rollDice)

            Button("Roll", action: rollDice)
                .disabled(diceInput.isEmpty)

            if let result = rollResult {
                ResultView(result: result)
            }

            if !rollHistory.isEmpty && historyEnabled{
                Divider()

                Button {
                    showHistory.toggle()
                } label: {
                    HStack {
                        Text("History")
                            .font(.headline)
                        Spacer()
                        Image(systemName: showHistory ? "chevron.up" : "chevron.down")
                    }
                    .contentShape(Rectangle())
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)

                if showHistory {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(rollHistory) { historyItem in
                                HistoryItemView(
                                    result: historyItem,
                                    onReuse: { diceInput = historyItem.input }
                                )
                                .contextMenu {
                                    Button("Remove", role: .destructive) {
                                        rollHistory.removeAll { $0.id == historyItem.id }
                                    }
                                }
                            }
                        }
                    }
                    .frame(height: 300)
                }
            }
        }
        .padding()
        .frame(width: 250)
    }

    private func rollDice() {
        guard !diceInput.isEmpty else { return }
        let result = DiceParser.parse(diceInput)
        rollResult = result

        if historyEnabled {
            rollHistory.insert(result, at: 0)

            if rollHistory.count > 50 {
                rollHistory.removeLast()
            }
        }
    }
}

@main
struct DiceRollerApp: App {
    var body: some Scene {
        MenuBarExtra("MacRoll", systemImage: "dice") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
