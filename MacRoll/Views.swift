import SwiftUI

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

struct CopyButton: View {
    let text: String
    let fullText: String
    @AppStorage("copyDiceRoll") private var copyDiceRoll = true
    @State private var isCopied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(copyDiceRoll ? fullText : text, forType: .string)

            // Show feedback
            withAnimation {
                isCopied = true
            }

            // Reset after delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation {
                    isCopied = false
                }
            }
        } label: {
            Image(systemName: isCopied ? "checkmark.circle.fill" : "doc.on.doc")
                .foregroundColor(isCopied ? .green : .secondary)
                .font(.caption)
        }
        .buttonStyle(.plain)
    }
}


struct ResultView: View {
    let result: RollResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(result.diceRolls) { roll in
                HStack {
                    let resultsString = roll.results.map(String.init).joined(separator: ", ")
                    let diceResultDescription = "\(roll.description): [\(resultsString)]"

                    Text(diceResultDescription)
                        .font(.body)

                    if roll.results.count > 1 {
                        Text("Sum: \(roll.sum)")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    CopyButton(
                        text: resultsString,
                        fullText: diceResultDescription
                    )
                }
            }

            ForEach(result.modifiers) { modifier in
                Text(modifier.description)
                    .font(.body)
            }

            Divider()

            HStack {
                Text("Total: \(result.total)")
                    .font(.title3)
                    .fontWeight(.bold)

                Spacer()

                CopyButton(
                    text: String(result.total),
                    fullText: "\(result.input): \(result.total)"
                )
            }
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

            VStack {
                Button(action: onReuse) {
                    Image(systemName: "arrow.counterclockwise")
                        .font(.caption)
                }
                .buttonStyle(.plain)

                Spacer()

                CopyButton(
                    text: String(result.total),
                    fullText: "\(result.input): \(result.total)"
                )
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct ContentView: View {
    @FocusState private var isInputFocused: Bool
    @State private var diceInput = "2d20 + 1"
    @State private var rollResult: RollResult?
    @State private var rollHistory: [RollResult] = []
    @State private var showHistory = false
    @AppStorage("historyEnabled") private var historyEnabled = false
    @AppStorage("copyDiceRoll") private var copyDiceRoll = true
    @State private var showErrorButton = false
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
                    Toggle("Include Roll Formula in Copy", isOn: $copyDiceRoll)
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
                    .focused($isInputFocused)
                    .onSubmit(rollDice)

                Button {
                    diceInput = ""
                    showErrorButton = false
                    showErrorPopover = false
                } label: {
                    Image(systemName: "trash")
                        .imageScale(.small)
                }
                .buttonStyle(.plain)

                if showErrorButton, let result = rollResult {
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
        .onAppear {
            isInputFocused = true
        }
    }

    private func rollDice() {
        guard !diceInput.isEmpty else { return }
        let result = DiceParser.parse(diceInput)
        rollResult = result
        // reset all errors on new roll
        showErrorPopover = false
        showErrorButton = false
        if !result.invalidComponents.isEmpty {
            showErrorButton = true
        }

        if historyEnabled {
            rollHistory.insert(result, at: 0)

            if rollHistory.count > 50 {
                rollHistory.removeLast()
            }
        }
    }
}
