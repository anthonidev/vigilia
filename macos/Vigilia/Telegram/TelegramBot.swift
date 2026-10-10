import Foundation
import Observation
import os

/// Bot de Telegram: se enciende y apaga solo según la sesión y los ajustes, y lee los mensajes
/// con long polling. Qué hacer con cada mensaje lo decide `BotUpdateHandler`.
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
    @ObservationIgnored private let handler: BotUpdateHandler

    @ObservationIgnored private var pollTask: Task<Void, Never>?
    /// Identifica la tarea de polling vigente. Una tarea cancelada puede tardar en terminar;
    /// con esto no pisa el estado de la nueva.
    @ObservationIgnored private var generation = 0
    /// Siguiente update a pedir. Se conserva al reconectar para no perder mensajes.
    @ObservationIgnored private var offset: Int?
    /// Si ya se descartaron los mensajes antiguos desde que se encendió el bot.
    @ObservationIgnored private var isPrepared = false
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
        capturer: any ScreenCapturing,
        makeClient: @escaping (String) -> any TelegramClient = { TelegramAPI(token: $0) }
    ) {
        self.session = session
        self.settings = settings
        self.token = token
        self.linker = linker
        self.makeClient = makeClient
        handler = BotUpdateHandler(
            session: session,
            settings: settings,
            linker: linker,
            screenshots: ScreenshotSender(capturer: capturer)
        )
        observeConditions()
    }

    /// Encendido mientras se vincula la cuenta, o durante una sesión si el bot está activado y hay cuenta.
    var shouldRun: Bool {
        guard token.hasToken else { return false }
        if linker.isLinking { return true }
        return settings.botEnabled && settings.isAccountLinked && session.isActive
    }

    /// Envía un aviso a la cuenta vinculada. No necesita que el polling esté encendido.
    func notify(_ reply: BotReply) async throws {
        // En un chat privado, el ID del chat es el del usuario.
        guard let chatID = settings.authorizedUserID, let value = try token.load() else { return }
        try await makeClient(value).sendMessage(chatID: chatID, text: reply.text, keyboard: reply.keyboard)
    }

    /// Comprueba el token con `getMe` y devuelve el bot.
    func testToken() async throws -> TelegramUser {
        guard let value = try token.load() else { throw TelegramError.invalidToken }
        return try await makeClient(value).getMe()
    }

    /// Tras despertar la Mac o recuperar la red: corta la petición colgada (o la espera entre
    /// reintentos) y vuelve a pedir enseguida, sin descartar los mensajes pendientes.
    func reconnectNow() {
        // Si el bot se va a apagar (por ejemplo, la sesión caducó mientras la Mac dormía), no reconecta.
        guard shouldRun, pollTask != nil, !isHandling else { return }
        Self.logger.info("Reconectando el bot")
        pollTask?.cancel()
        // Si aún no había descartado los mensajes antiguos, tiene que hacerlo ahora.
        start(discardPending: !isPrepared)
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
                start(discardPending: true)
            } else if runningTokenRevision != token.revision {
                stop()
                start(discardPending: true)
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

    /// - Parameter discardPending: al encender el bot se descarta lo antiguo; al reconectar, no.
    private func start(discardPending: Bool) {
        guard let value = try? token.load() else {
            status = .off
            return
        }
        let client = makeClient(value)
        generation += 1
        let generation = generation
        runningTokenRevision = token.revision
        isHandling = false
        if discardPending {
            Self.logger.info("Bot encendido")
            isPrepared = false
            status = .connecting
        }
        pollTask = Task { [weak self] in
            await self?.poll(client, generation: generation)
        }
    }

    private func stop() {
        Self.logger.info("Bot apagado")
        pollTask?.cancel()
        finishPolling(with: .off)
    }

    private func finishPolling(with status: Status) {
        generation += 1
        pollTask = nil
        runningTokenRevision = nil
        isHandling = false
        stopRequested = false
        self.status = status
    }

    // MARK: - Polling

    /// Si la tarea con este número sigue siendo la vigente.
    private func isCurrent(_ generation: Int) -> Bool {
        generation == self.generation && !Task.isCancelled
    }

    private func poll(_ client: any TelegramClient, generation: Int) async {
        var backoff: Duration = .seconds(1)
        var conflicts = 0

        while isCurrent(generation), !stopRequested {
            do {
                if !isPrepared {
                    let next = try await discardPendingUpdates(client)
                    try await client.setMyCommands(BotCommand.menu)
                    guard isCurrent(generation) else { return }
                    offset = next
                    isPrepared = true
                }

                let updates = try await client.getUpdates(offset: offset, timeout: Self.pollTimeout)
                guard isCurrent(generation) else { return }
                status = .running
                backoff = .seconds(1)
                conflicts = 0

                isHandling = true
                for update in updates {
                    offset = update.updateId + 1
                    await handler.handle(update, client: client)
                    guard isCurrent(generation) else { return }
                }
                isHandling = false
            } catch is CancellationError {
                return
            } catch TelegramError.invalidToken {
                if isCurrent(generation) { finishPolling(with: .invalidToken) }
                return
            } catch TelegramError.conflict where conflicts < Self.conflictRetries {
                conflicts += 1
                try? await Task.sleep(for: .seconds(2))
            } catch TelegramError.conflict {
                if isCurrent(generation) { finishPolling(with: .conflict) }
                return
            } catch {
                guard isCurrent(generation) else { return }
                Self.logger.error("Error de Telegram, reintentando: \(String(describing: error), privacy: .public)")
                status = .reconnecting
                try? await Task.sleep(for: backoff)
                backoff = min(backoff * 2, Self.maxBackoff)
            }
        }

        // Se pidió apagar mientras respondía: ya terminó de responder.
        if isCurrent(generation), stopRequested {
            finishPolling(with: .off)
        }
    }

    /// Descarta lo que se envió mientras el bot estaba apagado, para no ejecutar un `/off` antiguo.
    private func discardPendingUpdates(_ client: any TelegramClient) async throws -> Int? {
        let last = try await client.getUpdates(offset: -1, timeout: 0).last
        return last.map { $0.updateId + 1 }
    }
}
