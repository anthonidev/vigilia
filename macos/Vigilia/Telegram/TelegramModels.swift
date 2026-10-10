import Foundation

// Modelos de la Bot API de Telegram (https://core.telegram.org/bots/api).
// Se codifican con snake_case automático, por eso los campos usan `Id` en vez de `ID`.

nonisolated struct TelegramResponse<Result: Decodable>: Decodable {
    let ok: Bool
    let result: Result?
    let description: String?
    let errorCode: Int?
}

nonisolated struct TelegramUser: Codable, Equatable, Sendable {
    let id: Int64
    let isBot: Bool
    let firstName: String
    let username: String?

    /// "@usuario" si tiene, o el nombre.
    var displayName: String {
        username.map { "@\($0)" } ?? firstName
    }
}

nonisolated struct TelegramChat: Codable, Equatable, Sendable {
    let id: Int64
    /// "private", "group", "supergroup" o "channel".
    let type: String

    var isPrivate: Bool { type == "private" }
}

nonisolated struct TelegramMessage: Codable, Equatable, Sendable {
    let messageId: Int
    let from: TelegramUser?
    let chat: TelegramChat
    let text: String?
}

nonisolated struct TelegramCallbackQuery: Codable, Equatable, Sendable {
    let id: String
    let from: TelegramUser
    /// Mensaje que tenía el botón. Puede venir "inaccesible" (solo chat e ID) si es antiguo.
    let message: TelegramMessage?
    let data: String?
}

nonisolated struct TelegramUpdate: Codable, Equatable, Sendable {
    let updateId: Int
    let message: TelegramMessage?
    let callbackQuery: TelegramCallbackQuery?
}

nonisolated struct InlineKeyboardMarkup: Codable, Equatable, Sendable {
    let inlineKeyboard: [[InlineKeyboardButton]]
}

nonisolated struct InlineKeyboardButton: Codable, Equatable, Sendable {
    let text: String
    let callbackData: String
}

nonisolated struct BotCommandDescription: Codable, Equatable, Sendable {
    let command: String
    let description: String
}

/// Para métodos cuyo resultado no nos interesa (devuelven `true` o un mensaje).
nonisolated struct IgnoredResult: Decodable {
    init(from decoder: any Decoder) throws {}
}
