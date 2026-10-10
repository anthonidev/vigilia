import Foundation
import os

/// Envía avisos automáticos por Telegram: al activar, cuando quedan 10 minutos y al terminar.
final class SessionNotifier {
    private let settings: AppSettings
    private let token: TelegramTokenStore
    private let timeSource: TimeSource
    private let send: (BotReply) async throws -> Void
    private var inFlight: [UUID: Task<Void, Never>] = [:]

    private static let logger = Logger(subsystem: "com.tonis.vigilia", category: "telegram")
    private static let retryDelays: [Duration] = [.seconds(5), .seconds(15)]

    init(
        session: SessionManager,
        settings: AppSettings,
        token: TelegramTokenStore,
        timeSource: TimeSource = SystemTimeSource(),
        send: @escaping (BotReply) async throws -> Void
    ) {
        self.settings = settings
        self.token = token
        self.timeSource = timeSource
        self.send = send
        // Síncrono: así el aviso ya está en marcha cuando `deactivate()` vuelve (importa al salir).
        session.observe { [weak self] event in
            self?.handle(event)
        }
    }

    var isEnabled: Bool {
        settings.botEnabled && settings.notificationsEnabled && settings.isAccountLinked && token.hasToken
    }

    func handle(_ event: SessionEvent) {
        guard isEnabled, let message = Self.message(for: event, now: timeSource.now) else { return }
        let id = UUID()
        inFlight[id] = Task { [weak self] in
            await self?.deliver(message)
            self?.inFlight[id] = nil
        }
    }

    /// Espera a que salgan los avisos pendientes, como mucho `timeout`. Se usa antes de cerrar la app.
    func flush(timeout: Duration) async {
        let pending = Array(inFlight.values)
        guard !pending.isEmpty else { return }
        await withTaskGroup { group in
            group.addTask {
                for task in pending { await task.value }
            }
            group.addTask {
                try? await Task.sleep(for: timeout)
            }
            await group.next()
            group.cancelAll()
        }
    }

    /// Reintenta si falla la red; por ejemplo, justo al despertar la Mac.
    private func deliver(_ message: BotReply) async {
        for attempt in 0...Self.retryDelays.count {
            do {
                try await send(message)
                return
            } catch TelegramError.network where attempt < Self.retryDelays.count {
                try? await Task.sleep(for: Self.retryDelays[attempt])
            } catch {
                Self.logger.error("No se pudo enviar el aviso: \(String(describing: error), privacy: .public)")
                return
            }
        }
    }

    // MARK: - Textos

    /// Si la sesión terminó hace más de esto, el aviso dice a qué hora (la Mac estaba dormida).
    nonisolated static let lateThreshold: TimeInterval = 2 * 60

    nonisolated static func message(for event: SessionEvent, now: Date) -> BotReply? {
        switch event {
        case .started(.indefinite):
            return BotReply(text: "☕ Vigilia activa de forma indefinida.", keyboard: BotKeyboards.controls)
        case .started(.minutes(let minutes)):
            return BotReply(
                text: "☕ Vigilia activa por \(DurationText.label(minutes: minutes)).",
                keyboard: BotKeyboards.controls
            )
        case .changed:
            return nil
        case .tenMinutesLeft:
            return BotReply(text: "⏳ Quedan 10 min. ¿Ampliar?", keyboard: BotKeyboards.tenMinutesLeft)
        case .ended(.expired(let endDate)):
            var text = "😴 Sesión terminada. Tu Mac ya puede dormir."
            if now.timeIntervalSince(endDate) > lateThreshold {
                let time = endDate.formatted(date: .omitted, time: .shortened)
                text += "\n(Terminó a las \(time), mientras la Mac dormía.)"
            }
            return BotReply(text: text)
        case .ended(.deactivated):
            return BotReply(text: "😴 Sesión desactivada desde la Mac. Tu Mac ya puede dormir.")
        case .ended(.deactivatedRemotely):
            // El bot ya respondió al /off.
            return nil
        }
    }
}
