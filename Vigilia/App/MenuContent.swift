import SwiftUI

struct MenuContent: View {
    let session: SessionManager
    let bot: TelegramBot
    let settings: AppSettings
    let token: TelegramTokenStore

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        if session.isActive {
            Text(session.statusText)
            if let botStatus {
                Text(botStatus)
            }
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

extension MenuContent {
    /// Estado del bot, solo si está activado en Ajustes.
    private var botStatus: String? {
        guard settings.botEnabled else { return nil }
        guard token.hasToken else { return "Bot: falta el token" }
        guard settings.isAccountLinked else { return "Bot: falta vincular la cuenta" }
        return switch bot.status {
        case .off, .connecting: "Bot: conectando…"
        case .running: "Bot conectado"
        case .reconnecting: "Bot: sin conexión, reintentando…"
        case .invalidToken: "Bot: token inválido"
        case .conflict: "Bot: otro programa usa este bot"
        }
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
