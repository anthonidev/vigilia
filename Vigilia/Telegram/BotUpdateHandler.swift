import Foundation
import os

/// Decide qué hacer con cada mensaje o botón que llega al bot: autoriza, vincula, responde
/// y lanza capturas. No sabe nada de cómo se reciben (eso es `TelegramBot`).
final class BotUpdateHandler {
    private let session: any SessionControlling
    private let settings: AppSettings
    private let linker: AccountLinker
    private let router: CommandRouter
    private let screenshots: ScreenshotSender

    private static let logger = Logger(subsystem: "com.tonis.vigilia", category: "telegram")

    init(
        session: any SessionControlling,
        settings: AppSettings,
        linker: AccountLinker,
        screenshots: ScreenshotSender
    ) {
        self.session = session
        self.settings = settings
        self.linker = linker
        self.screenshots = screenshots
        router = CommandRouter(session: session)
    }

    func handle(_ update: TelegramUpdate, client: any TelegramClient) async {
        if let message = update.message {
            await handle(message, client: client)
        } else if let callback = update.callbackQuery {
            await handle(callback, client: client)
        }
    }

    // MARK: - Mensajes y botones

    private func handle(_ message: TelegramMessage, client: any TelegramClient) async {
        guard let user = message.from, message.chat.isPrivate,
              let text = message.text, let command = BotCommand(text: text)
        else { return }

        // Durante la vinculación, cualquiera puede enviar el código; nada más.
        if case .link(let code) = command, linker.isLinking {
            let reply: String
            switch linker.verify(code, from: user) {
            case .linked: reply = BotText.linked
            case .wrongCode: reply = BotText.wrongCode
            case .expired: reply = BotText.linkExpired
            case .tooManyAttempts: reply = BotText.tooManyAttempts
            case .notLinking: return
            }
            await send(BotReply(text: reply), to: message.chat.id, client: client)
            return
        }

        guard isAuthorized(user, chat: message.chat) else { return }
        await respond(to: command, chatID: message.chat.id, client: client)
    }

    private func handle(_ callback: TelegramCallbackQuery, client: any TelegramClient) async {
        guard let message = callback.message, isAuthorized(callback.from, chat: message.chat) else { return }

        // Quita el reloj de carga del botón cuanto antes, y los botones de ese mensaje
        // para no pulsarlos dos veces. La respuesta trae botones nuevos.
        try? await client.answerCallbackQuery(id: callback.id, text: nil)
        try? await client.editMessageReplyMarkup(chatID: message.chat.id, messageID: message.messageId, keyboard: nil)

        guard let data = callback.data, let command = BotCommand(callbackData: data) else { return }
        await respond(to: command, chatID: message.chat.id, client: client)
    }

    private func respond(to command: BotCommand, chatID: Int64, client: any TelegramClient) async {
        let reply = router.reply(to: command)
        if !reply.text.isEmpty {
            await send(reply, to: chatID, client: client)
        }

        switch reply.followUp {
        case .none: break
        case .deactivate: session.deactivate(remotely: true)
        case .screenshot(let request): await screenshots.handle(request, chatID: chatID, client: client)
        }
    }

    private func send(_ reply: BotReply, to chatID: Int64, client: any TelegramClient) async {
        do {
            try await client.sendMessage(chatID: chatID, text: reply.text, keyboard: reply.keyboard)
        } catch {
            Self.logger.error("No se pudo enviar la respuesta: \(String(describing: error), privacy: .public)")
        }
    }

    /// Solo la cuenta vinculada, y solo en su chat privado con el bot.
    private func isAuthorized(_ user: TelegramUser, chat: TelegramChat) -> Bool {
        guard let authorized = settings.authorizedUserID else { return false }
        return user.id == authorized && chat.isPrivate
    }
}
