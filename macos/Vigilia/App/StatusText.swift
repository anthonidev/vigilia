import Foundation

extension SessionManager {
    /// "Activa · quedan 1 h 23 min", "Activa · indefinida" o "Vigilia inactiva".
    var statusText: String {
        guard isActive else { return "Vigilia inactiva" }
        guard let remaining else { return "Activa · indefinida" }
        return "Activa · quedan \(DurationText.remaining(remaining))"
    }
}

nonisolated enum BotStatusText {
    /// Estado del bot para el menú, o `nil` si el bot está desactivado en Ajustes.
    static func text(
        botEnabled: Bool,
        hasToken: Bool,
        isAccountLinked: Bool,
        status: TelegramBot.Status
    ) -> String? {
        guard botEnabled else { return nil }
        guard hasToken else { return "Bot: falta el token" }
        guard isAccountLinked else { return "Bot: falta vincular la cuenta" }
        return switch status {
        case .off, .connecting: "Bot: conectando…"
        case .running: "Bot conectado"
        case .reconnecting: "Bot: sin conexión, reintentando…"
        case .invalidToken: "Bot: token inválido"
        case .conflict: "Bot: otro programa usa este bot"
        }
    }
}
