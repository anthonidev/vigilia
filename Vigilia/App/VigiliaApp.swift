import SwiftUI

@main
struct VigiliaApp: App {
    @State private var session: SessionManager
    @State private var icon: MenuBarIcon

    init() {
        let session = SessionManager()
        _session = State(initialValue: session)
        _icon = State(initialValue: MenuBarIcon(session: session))

        #if DEBUG
        DebugLaunch.apply(to: session)
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(session: session)
        } label: {
            Image(nsImage: icon.image(active: session.isActive))
                .accessibilityLabel(session.statusText)
        }

        Settings {
            Text("La configuración llegará en la Fase 2.")
                .padding(40)
        }
    }
}
