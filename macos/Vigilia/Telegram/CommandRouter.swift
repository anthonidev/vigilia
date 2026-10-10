import Foundation

/// Lo que el router necesita de la sesión. `SessionManager` lo cumple; los tests usan uno falso.
protocol SessionControlling: AnyObject {
    var isActive: Bool { get }
    var isIndefinite: Bool { get }
    var remaining: TimeInterval? { get }
    @discardableResult func extend(byMinutes minutes: Int) -> ExtendResult
    func set(minutes: Int)
    func makeIndefinite()
    func deactivate(remotely: Bool)
}

extension SessionManager: SessionControlling {}

/// Respuesta del bot a un comando.
nonisolated struct BotReply: Equatable, Sendable {
    var text: String
    var keyboard: InlineKeyboardMarkup?
    /// Acción que se hace después de enviar la respuesta. Desactivar apaga el bot,
    /// así que hay que responder antes.
    var followUp: FollowUp = .none

    nonisolated enum FollowUp: Equatable, Sendable {
        case none
        case deactivate
        case screenshot(ScreenshotRequest)
    }
}

/// Convierte cada comando en una acción sobre la sesión y una respuesta.
struct CommandRouter {
    let session: any SessionControlling

    func reply(to command: BotCommand) -> BotReply {
        switch command {
        case .status:
            return statusReply()

        case .extend(let minutes):
            switch session.extend(byMinutes: minutes) {
            case .extended:
                return BotReply(
                    text: "➕ Sumados \(DurationText.label(minutes: minutes)). \(remainingSentence())",
                    keyboard: BotKeyboards.controls
                )
            case .alreadyIndefinite:
                return BotReply(text: "La sesión ya es indefinida.", keyboard: BotKeyboards.controls)
            case .inactive:
                return BotReply(text: BotText.inactive)
            }

        case .set(let minutes):
            guard session.isActive else { return BotReply(text: BotText.inactive) }
            session.set(minutes: minutes)
            return BotReply(text: "⏱️ Listo. \(remainingSentence())", keyboard: BotKeyboards.controls)

        case .indefinite:
            guard session.isActive else { return BotReply(text: BotText.inactive) }
            session.makeIndefinite()
            return BotReply(
                text: "♾️ Sesión indefinida. La Mac seguirá despierta hasta que desactives la sesión.",
                keyboard: BotKeyboards.controls
            )

        case .off:
            guard session.isActive else { return BotReply(text: BotText.inactive) }
            return BotReply(
                text: "😴 Sesión desactivada. Tu Mac ya puede dormir y el bot se apaga hasta la próxima sesión.",
                followUp: .deactivate
            )

        case .screenshot(let request):
            guard session.isActive else { return BotReply(text: BotText.inactive) }
            // La captura es asíncrona y la envía el bot; aquí no hay texto que responder.
            return BotReply(text: "", followUp: .screenshot(request))

        case .help:
            return BotReply(text: BotText.help)

        case .dismiss:
            return BotReply(text: "👍 Vale, la sesión terminará a su hora.")

        case .link:
            return BotReply(text: "Tu cuenta ya está vinculada.")

        case .invalidArgument(let usage):
            return BotReply(text: usage)

        case .unknown:
            return BotReply(text: "No conozco ese comando. Escribe /ayuda para ver la lista.")
        }
    }

    private func statusReply() -> BotReply {
        guard session.isActive else { return BotReply(text: BotText.inactive) }
        let text = session.isIndefinite
            ? "☕ Vigilia activa de forma indefinida."
            : "☕ Vigilia activa. \(remainingSentence())"
        return BotReply(text: text, keyboard: BotKeyboards.controls)
    }

    private func remainingSentence() -> String {
        guard let remaining = session.remaining else { return "Sesión indefinida." }
        return "Quedan \(DurationText.remaining(remaining))."
    }
}

nonisolated enum BotKeyboards {
    /// Botones de control de la sesión.
    static let controls = InlineKeyboardMarkup(inlineKeyboard: [
        [
            InlineKeyboardButton(text: "+30 min", callbackData: "ext:30"),
            InlineKeyboardButton(text: "+1 h", callbackData: "ext:60"),
            InlineKeyboardButton(text: "+2 h", callbackData: "ext:120"),
        ],
        [
            InlineKeyboardButton(text: "Apagar", callbackData: "off"),
            InlineKeyboardButton(text: "Captura", callbackData: "shot"),
        ],
    ])

    /// Botones del aviso de los 10 minutos.
    static let tenMinutesLeft = InlineKeyboardMarkup(inlineKeyboard: [
        [
            InlineKeyboardButton(text: "+30 min", callbackData: "ext:30"),
            InlineKeyboardButton(text: "+1 h", callbackData: "ext:60"),
            InlineKeyboardButton(text: "+2 h", callbackData: "ext:120"),
        ],
        [
            InlineKeyboardButton(text: "Dejar terminar", callbackData: "dismiss"),
        ],
    ])
}

nonisolated enum BotText {
    static let inactive = "Vigilia está inactiva. Actívala desde el menú de la Mac."

    static let help = """
        ☕ Comandos de Vigilia

        /estado — si está activa y cuánto queda
        /mas 30m — suma tiempo (30m, 1h, 1h30m…)
        /set 2h — reemplaza el tiempo restante
        /indefinido — sin límite de tiempo
        /off — desactiva la sesión
        /captura — captura de pantalla
        /captura hd — captura en resolución completa
        /ayuda — esta lista
        """

    static let linked = "✅ Cuenta vinculada. Desde ahora Vigilia solo obedece a esta cuenta."
    static let wrongCode = "Código incorrecto."
    static let linkExpired = "El código caducó. Genera uno nuevo en Ajustes de Vigilia."
    static let tooManyAttempts = "Demasiados intentos. Genera un código nuevo en Ajustes de Vigilia."
}
