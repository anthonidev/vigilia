import Foundation
import Observation

/// Token del bot de Telegram, guardado en el Keychain. Nunca se guarda en `UserDefaults` ni se registra.
@Observable
final class TelegramTokenStore {
    private(set) var hasToken = false

    @ObservationIgnored private let keychain: KeychainStore
    private static let account = "telegram-bot-token"

    init(keychain: KeychainStore = KeychainStore(service: "com.tonis.vigilia")) {
        self.keychain = keychain
        hasToken = (try? keychain.load(account: Self.account)) != nil
    }

    func load() throws -> String? {
        try keychain.load(account: Self.account)
    }

    /// Guarda el token sin espacios alrededor. Lanza `TokenError.invalidFormat` si no parece de BotFather.
    func save(_ token: String) throws {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard Self.isPlausible(trimmed) else { throw TokenError.invalidFormat }
        try keychain.save(trimmed, account: Self.account)
        hasToken = true
    }

    func delete() throws {
        try keychain.delete(account: Self.account)
        hasToken = false
    }

    /// Los tokens de BotFather tienen la forma `123456789:AAH…` (ID numérico, dos puntos y unos 35 caracteres).
    nonisolated static func isPlausible(_ token: String) -> Bool {
        token.wholeMatch(of: /\d{5,}:[A-Za-z0-9_-]{30,}/) != nil
    }

    nonisolated enum TokenError: Error {
        case invalidFormat
    }
}
