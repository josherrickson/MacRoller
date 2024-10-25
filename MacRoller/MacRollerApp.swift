import SwiftUI

@main
struct MacRollerApp: App {
    var body: some Scene {
        MenuBarExtra("MacRoller", systemImage: "dice") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }
}
