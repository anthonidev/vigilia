import Foundation
import Observation
import os

/// Bot de Telegram: lee mensajes con long polling, solo obedece a la cuenta autorizada
/// y se enciende y apaga solo según la sesión y los ajustes.
@Observable
final class TelegramBot {
    nonisolated enum Status: Equatable, Sendable {
        case off
        case connecting
        case running
        /// Sin conexión; se reintenta con espera creciente.
        case reconnecting
        case invalidToken
        /// Otro programa está usando este mismo bot.
        case conflict
    }

    private(set) var status: Status = .off

    @ObservationIgnored private let session: any SessionControlling
    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let token: TelegramTokenStore
    @ObservationIgnored private let linker: AccountLinker
    @ObservationIgnored private let makeClient: (String) -> any TelegramClient
    @ObservationIgnored private let router: CommandRouter

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    @ObservationIgnored private var runningTokenRevision: Int?
    @ObservationIgnored private var isHandling = false
    @ObservationIgnored private var stopRequested = false

    private static let logger = Logger(subsystem: "com.tonis.vigilia", category: "telegram")
    private static let pollTimeout = 50
    private static let maxBackoff: Duration = .seconds(60)
    /// Un 409 justo al arrancar suele ser la conexión anterior que aún no se cerró.
    private static let conflictRetries = 3

    init(
        session: any SessionControlling,
        settings: AppSettings,
        token: TelegramTokenStore,
        linker: AccountLinker,
        makeClient: @escaping (String) -> any TelegramClient = { TelegramAPI(token: $0) }
    ) {
        self.session = session
        self.settings = settings
        self.token = token
        self.linker = linker
        self.makeClient = makeClient
        router = CommandRouter(session: session)
        observeConditions()
    }

    /// Encendido mientras se vincula la cuenta, o durante una sesión si el bot está activado y hay cuenta.
    var shouldRun: Bool {
        guard token.hasToken else { return false }
        if linker.isLinking { return true }
        return settings.botEnabled && settings.isAccountLinked && session.isActive
    }

    /// Comprueba el token con `getMe` y devuelve el bot.
    func testToken() async throws -> TelegramUser {
        guard let value = try token.load() else { throw TelegramError.invalidToken }
        return try await makeClient(value).getMe()
    }

    // MARK: - Encendido y apagado

    /// Re-evalúa `shouldRun` cada vez que cambia algo de lo que depende.
    private func observeConditions() {
        withObservationTracking {
            _ = shouldRun
            _ = token.revision
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.reconcile()
                self?.observeConditions()
            }
        }
        reconcile()
    }

    func reconcile() {
        if shouldRun {
            stopRequested = false
            if pollTask == nil {
                start()
            } else if runningTokenRevision != token.revision {
                stop()
                start()
            }
        } else if pollTask != nil {
            // Si está respondiendo un mensaje, termina de responder antes de apagarse.
            if isHandling {
                stopRequested = true
            } else {
                stop()
            }
        } else if status != .off, !token.hasToken || !settings.botEnabled {
            status = .off
        }
    }

    private func start() {
        guard let value = try? token.load() else {
            status = .off
            return
        }
        let client = makeClient(value)
        runningTokenRevision = token.revision
        status = .connecting
        pollTask = Task { [weak self] in
            await self?.poll(client)
        }
    }

    private func stop() {
        pollTask?.cancel()
        pollTask = nil
        runningTokenRevision = nil
        stopRequested = false
        status = .off
    }

    // MARK: - Polling

    private func poll(_ client: any TelegramClient) async {
        var offset: Int?
        var backoff: Duration = .seconds(1)
        var conflicts = 0
        var prepared = false

        while !Task.isCancelled, !stopRequested {
            do {
                if !prepared {
                    offset = try await discardPendingUpdates(client)
                    try await client.setMyCommands(BotCommand.menu)
                    prepared = true
                }

                let updates = try await client.getUpdates(offset: offset, timeout: Self.pollTimeout)
                guard !Task.isCancelled else { break }
                status = .running
                backoff = .seconds(1)
                conflicts = 0

                isHandling = true
                for update in updates {
                    offset = update.updateId + 1
                    await handle(update, client: client)
                }
                isHandling = false
            } catch is CancellationError {
                break
            } catch TelegramError.invalidToken {
                finishPolling(with: .invalidToken)
                return
            } catch TelegramError.conflict where conflicts < Self.conflictRetries {
                conflicts += 1
                try? await Task.sleep(for: .seconds(2))
            } catch TelegramError.conflict {
                finishPolling(with: .conflict)
                return
            } catch {
                Self.logger.error("Error de Telegram, reintentando: \(String(describing: error), privacy: .public)")
                status = .reconnecting
                try? await Task.sleep(for: backoff)
                backoff = min(backoff * 2, Self.maxBackoff)
            }
        }

        isHandling = false
        if stopRequested, !Task.isCancelled {
            finishPolling(with: .off)
        }
    }

    /// Descarta lo que se envió mientras el bot estaba apagado, para no ejecutar un `/off` antiguo.
    private func discardPendingUpdates(_ client: any TelegramClient) async throws -> Int? {
        let last = try await client.getUpdates(offset: -1, timeout: 0).last
        return last.map { $0.updateId + 1 }
    }

    private func finishPolling(with status: Status) {
        pollTask = nil
        runningTokenRevision = nil
        isHandling = false
        stopRequested = false
        self.status = status
    }

    // MARK: - Mensajes

    private func handle(_ update: TelegramUpdate, client: any TelegramClient) async {
        if let message = update.message {
            await handle(message, client: client)
        } else if let callback = update.callbackQuery {
            await handle(callback, client: client)
        }
    }

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
        guard let chat = callback.message?.chat, isAuthorized(callback.from, chat: chat) else { return }

        // Quita el reloj de carga del botón cuanto antes.
        try? await client.answerCallbackQuery(id: callback.id, text: nil)

        guard let data = callback.data, let command = BotCommand(callbackData: data) else { return }
        await respond(to: command, chatID: chat.id, client: client)
    }

    private func respond(to command: BotCommand, chatID: Int64, client: any TelegramClient) async {
        let reply = router.reply(to: command)
        await send(reply, to: chatID, client: client)

        switch reply.followUp {
        case .none: break
        case .deactivate: session.deactivate()
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
