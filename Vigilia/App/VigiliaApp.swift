import SwiftUI

@main
struct VigiliaApp: App {
    var body: some Scene {
        MenuBarExtra("Vigilia", systemImage: "cup.and.saucer") {
            Button("Salir") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
    }
}
