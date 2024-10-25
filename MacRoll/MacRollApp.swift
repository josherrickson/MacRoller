import SwiftUI

@main
struct DiceRollerApp: App {
    var body: some Scene {
        MenuBarExtra("MacRoll", systemImage: "dice") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
