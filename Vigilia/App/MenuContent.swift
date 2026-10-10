import SwiftUI

struct MenuContent: View {
    let session: SessionManager

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if session.isActive {
            Text(session.statusText)
            Divider()
        }

        ForEach(SessionDuration.menuOptions, id: \.self) { option in
            // Elegir otra vez la opción marcada reinicia su tiempo.
            Toggle(option.label, isOn: Binding(
                get: { session.selectedOption == option },
                set: { _ in session.activate(option) }
            ))
        }

        if session.isActive {
            Divider()
            Button("Desactivar") {
                session.deactivate()
            }
        }

        Divider()

        Button("Configuración…") {
            // Una app sin Dock no trae sus ventanas al frente por sí sola.
            NSApplication.shared.activate()
            openSettings()
        }
        .keyboardShortcut(",")

        Button("Salir") {
            session.deactivate()
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}

extension SessionManager {
    /// "Activa · quedan 1 h 23 min", "Activa · indefinida" o "Inactiva".
    var statusText: String {
        guard isActive else { return "Vigilia inactiva" }
        guard let remaining else { return "Activa · indefinida" }
        return "Activa · quedan \(DurationText.remaining(remaining))"
    }
}
