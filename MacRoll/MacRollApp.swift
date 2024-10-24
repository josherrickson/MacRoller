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
    let invalidComponents: [(String, String)]  // (invalid text, error message)

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
                let results = (0..<count).map { _ in Int.random(in: 1...sides) }
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

// MARK: - Views
struct ErrorPopover: View {
    let invalidComponents: [(String, String)]

    func truncate(_ str: String, maxLength: Int) -> String {
        if str.count <= maxLength {
            return str
        }
        return String(str.prefix(maxLength)) + "..."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Errors were found:")
                .font(.headline)
            ForEach(invalidComponents, id: \.0) { component, message in
                Text("• '\(truncate(component, maxLength: 8))': \(truncate(message, maxLength: 40))")
                    .foregroundColor(.red)
            }
        }
        .padding()
    }
}

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
    @State private var showErrorPopover = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(result.input)
                        .font(.caption)
                    if !result.invalidComponents.isEmpty {
                        Button {
                            showErrorPopover.toggle()
                        } label: {
                            Image(systemName: "info.circle")
                                .foregroundColor(.red)
                                .font(.caption)
                        }
                        .buttonStyle(.plain)
                        .popover(isPresented: $showErrorPopover, arrowEdge: .bottom) {
                            ErrorPopover(invalidComponents: result.invalidComponents)
                        }
                    }
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
    @State private var showErrorPopover = false

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
            HStack {
                TextField("Enter dice roll (e.g. 3d20 + 2)", text: $diceInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit(rollDice)

                if let result = rollResult, !result.invalidComponents.isEmpty {
                    Button {
                        showErrorPopover.toggle()
                    } label: {
                        Image(systemName: "info.circle")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showErrorPopover, arrowEdge: .bottom) {
                        ErrorPopover(invalidComponents: result.invalidComponents)
                    }
                }
            }

            Button("Roll", action: rollDice)
                .disabled(diceInput.isEmpty)

            if let result = rollResult {
                ResultView(result: result)
            }

            if !rollHistory.isEmpty && historyEnabled {
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
        showErrorPopover = false  // Reset popover state on new roll

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
