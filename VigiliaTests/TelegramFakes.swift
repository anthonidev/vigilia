import Foundation
import Observation
@testable import Vigilia

@Observable
final class FakeSession: SessionControlling {
    var isActive = true
    var isIndefinite = false
    var remaining: TimeInterval? = 60 * 60
    var extendResult: ExtendResult = .extended
    private(set) var extendCalls: [Int] = []
    private(set) var setCalls: [Int] = []
    private(set) var deactivated = false
    private(set) var deactivatedRemotely = false

    func extend(byMinutes minutes: Int) -> ExtendResult {
        extendCalls.append(minutes)
        if extendResult == .extended, let current = remaining {
            remaining = current + TimeInterval(minutes * 60)
        }
        return extendResult
    }

    func set(minutes: Int) {
        setCalls.append(minutes)
        remaining = TimeInterval(minutes * 60)
    }

    func makeIndefinite() {
        isIndefinite = true
        remaining = nil
    }

    func deactivate(remotely: Bool) {
        deactivated = true
        deactivatedRemotely = remotely
        isActive = false
    }
}

struct SentMessage: Equatable, Sendable {
    let chatID: Int64
    let text: String
    let keyboard: InlineKeyboardMarkup?
}

/// Telegram falso: devuelve los updates que el test encola y guarda lo que el bot envía.
actor FakeTelegramClient {
    /// Lo que había antes de arrancar el bot (lo que devuelve `getUpdates(offset: -1)`).
    var pending: [TelegramUpdate] = []
    private var queue: [[TelegramUpdate]] = []
    private var error: TelegramError?
    private(set) var offsets: [Int?] = []
    private(set) var sent: [SentMessage] = []
    private(set) var answeredCallbacks: [String] = []
    private(set) var commandsSet = false
    /// Mensajes a los que se les quitaron los botones (chat, mensaje).
    private(set) var clearedKeyboards: [Int] = []

    func setPending(_ updates: [TelegramUpdate]) { pending = updates }
    func setError(_ error: TelegramError?) { self.error = error }
    func enqueue(_ updates: TelegramUpdate...) { queue.append(updates) }

}

// La conformidad va en una extensión: declarada en el actor, el compilador le infiere
// `nonisolated` del protocolo y lo rechaza.
extension FakeTelegramClient: TelegramClient {
    func getMe() async throws -> TelegramUser {
        TelegramUser(id: 1, isBot: true, firstName: "Vigilia", username: "vigilia_test_bot")
    }

    func getUpdates(offset: Int?, timeout: Int) async throws -> [TelegramUpdate] {
        offsets.append(offset)
        if let error { throw error }
        if offset == -1 { return Array(pending.suffix(1)) }
        // Long polling: espera hasta que el test encole algo o se cancele la tarea.
        while queue.isEmpty {
            try await Task.sleep(for: .milliseconds(5))
        }
        return queue.removeFirst()
    }

    @discardableResult
    func sendMessage(chatID: Int64, text: String, keyboard: InlineKeyboardMarkup?) async throws -> TelegramMessage {
        sent.append(SentMessage(chatID: chatID, text: text, keyboard: keyboard))
        return TelegramMessage(messageId: sent.count, from: nil, chat: TelegramChat(id: chatID, type: "private"), text: text)
    }

    func editMessageReplyMarkup(chatID: Int64, messageID: Int, keyboard: InlineKeyboardMarkup?) async throws {
        if keyboard == nil { clearedKeyboards.append(messageID) }
    }

    func answerCallbackQuery(id: String, text: String?) async throws {
        answeredCallbacks.append(id)
    }

    func setMyCommands(_ commands: [BotCommandDescription]) async throws {
        commandsSet = true
    }
}

enum Updates {
    static func text(_ text: String, id: Int, from userID: Int64, chatType: String = "private") -> TelegramUpdate {
        TelegramUpdate(
            updateId: id,
            message: TelegramMessage(
                messageId: id,
                from: user(userID),
                chat: TelegramChat(id: userID, type: chatType),
                text: text
            ),
            callbackQuery: nil
        )
    }

    static func button(_ data: String, id: Int, from userID: Int64) -> TelegramUpdate {
        TelegramUpdate(
            updateId: id,
            message: nil,
            callbackQuery: TelegramCallbackQuery(
                id: "cb\(id)",
                from: user(userID),
                message: TelegramMessage(messageId: 1, from: nil, chat: TelegramChat(id: userID, type: "private"), text: nil),
                data: data
            )
        )
    }

    static func user(_ id: Int64) -> TelegramUser {
        TelegramUser(id: id, isBot: false, firstName: "Usuario \(id)", username: "user\(id)")
    }
}

/// Espera hasta que se cumpla la condición, o falla tras el tiempo límite.
@MainActor
func eventually(
    timeout: Duration = .seconds(2),
    _ condition: () async -> Bool
) async -> Bool {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if await condition() { return true }
        try? await Task.sleep(for: .milliseconds(10))
    }
    return await condition()
}
