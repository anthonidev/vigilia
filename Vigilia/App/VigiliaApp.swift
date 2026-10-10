import SwiftUI

@main
struct VigiliaApp: App {
    @State private var session = SessionManager()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(session: session)
        } label: {
            Image(systemName: session.isActive ? "cup.and.saucer.fill" : "cup.and.saucer")
                .accessibilityLabel(session.statusText)
        }

        Settings {
            Text("La configuración llegará en la Fase 2.")
                .padding(40)
        }
    }
}
