import Foundation

/// Un comando del bot, venga de un mensaje de texto o de un botón.
nonisolated enum BotCommand: Equatable, Sendable {
    case status
    case extend(minutes: Int)
    case set(minutes: Int)
    case indefinite
    case off
    case screenshot(hd: Bool)
    case help
    /// `/vincular 123456`, o `/start 123456` desde el enlace de Ajustes.
    case link(code: String)
    /// Comando conocido con un argumento que falta o no se entiende.
    case invalidArgument(usage: String)
    case unknown

    /// Comandos que Telegram muestra en el menú del chat (`setMyCommands`).
    static let menu: [BotCommandDescription] = [
        .init(command: "estado", description: "Si está activa y cuánto tiempo queda"),
        .init(command: "mas", description: "Suma tiempo: /mas 30m, /mas 1h"),
        .init(command: "set", description: "Reemplaza el tiempo restante: /set 2h"),
        .init(command: "indefinido", description: "Pasa la sesión a tiempo indefinido"),
        .init(command: "off", description: "Desactiva la sesión"),
        .init(command: "captura", description: "Captura de pantalla (/captura hd en resolución completa)"),
        .init(command: "ayuda", description: "Lista los comandos"),
    ]

    /// Analiza un mensaje de texto. Devuelve `nil` si no es un comando (no empieza por "/").
    init?(text: String) {
        let parts = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ", maxSplits: 1)
        guard let first = parts.first, first.hasPrefix("/") else { return nil }

        // "/mas@VigiliaBot" → "mas". Se ignoran mayúsculas y tildes ("/Más" = "/mas").
        let name = first.dropFirst()
            .split(separator: "@", maxSplits: 1).first.map(String.init)?
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil) ?? ""
        let argument = parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : ""

        switch name {
        case "estado":
            self = .status
        case "mas":
            self = DurationParser.minutes(from: argument).map { .extend(minutes: $0) }
                ?? .invalidArgument(usage: "Uso: /mas 30m, /mas 1h o /mas 1h30m")
        case "set":
            self = DurationParser.minutes(from: argument).map { .set(minutes: $0) }
                ?? .invalidArgument(usage: "Uso: /set 2h, /set 45m")
        case "indefinido":
            self = .indefinite
        case "off":
            self = .off
        case "captura":
            self = .screenshot(hd: argument.lowercased() == "hd")
        case "ayuda", "help":
            self = .help
        case "vincular", "start":
            // "/start" sin código es el primer mensaje que envía Telegram al abrir el bot.
            self = argument.isEmpty ? .help : .link(code: argument)
        default:
            self = .unknown
        }
    }

    /// Analiza el `callback_data` de un botón: "ext:30", "off", "shot".
    init?(callbackData: String) {
        switch callbackData {
        case "off":
            self = .off
        case "shot":
            self = .screenshot(hd: false)
        default:
            guard let minutes = callbackData.wholeMatch(of: /ext:(\d+)/).flatMap({ Int($0.1) }),
                  (1...DurationParser.maxMinutes).contains(minutes)
            else { return nil }
            self = .extend(minutes: minutes)
        }
    }
}
