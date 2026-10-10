import Foundation

/// Duración elegida para una sesión.
nonisolated enum SessionDuration: Hashable, Sendable {
    case indefinite
    case minutes(Int)

    /// Opciones del menú desplegable, en orden.
    static let menuOptions: [SessionDuration] = [
        .indefinite,
        .minutes(10),
        .minutes(30),
        .minutes(60),
        .minutes(120),
        .minutes(240),
        .minutes(480),
        .minutes(720),
    ]

    var label: String {
        switch self {
        case .indefinite: "Indefinido"
        case .minutes(let minutes): DurationText.label(minutes: minutes)
        }
    }
}

/// Estado de la sesión. Una sesión activa sin fecha de fin es indefinida.
nonisolated enum SessionState: Equatable, Sendable {
    case inactive
    case active(endDate: Date?)
}

nonisolated enum SessionEndReason: Equatable, Sendable {
    /// El tiempo se acabó. Lleva la hora de fin prevista, que puede ser anterior
    /// si la Mac estaba dormida.
    case expired(at: Date)
    /// Se desactivó desde la Mac.
    case deactivated
    /// Se desactivó desde Telegram (el bot ya respondió, no hace falta avisar).
    case deactivatedRemotely
}

nonisolated enum SessionEvent: Equatable, Sendable {
    case started(SessionDuration)
    /// El tiempo restante cambió (ampliado, reemplazado o pasado a indefinido).
    case changed
    /// Quedan 10 minutos. Solo una vez por sesión, y solo si tenía más de 10 minutos por delante.
    case tenMinutesLeft
    case ended(SessionEndReason)
}

/// Resultado de intentar sumar tiempo a la sesión.
nonisolated enum ExtendResult: Equatable, Sendable {
    case extended
    case alreadyIndefinite
    case inactive
}
