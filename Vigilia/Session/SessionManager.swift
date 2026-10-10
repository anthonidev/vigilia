import Foundation
import Observation

/// Única fuente de verdad de la sesión. El menú y el bot solo llaman a estos métodos.
///
/// La sesión guarda su hora de fin, no un contador, así sigue siendo correcta aunque la Mac se duerma.
@Observable
final class SessionManager {
    private(set) var state: SessionState = .inactive
    /// Segundos restantes; `nil` si está inactiva o es indefinida. Se refresca en cada `tick()`.
    private(set) var remaining: TimeInterval?
    /// Opción del menú que inició la sesión; se borra al ampliar o reemplazar el tiempo.
    private(set) var selectedOption: SessionDuration?

    @ObservationIgnored private let timeSource: TimeSource
    @ObservationIgnored private let power: PowerAsserting
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var continuations: [UUID: AsyncStream<SessionEvent>.Continuation] = [:]

    init(timeSource: TimeSource = SystemTimeSource(), power: PowerAsserting = PowerAssertion()) {
        self.timeSource = timeSource
        self.power = power
    }

    var isActive: Bool { state != .inactive }

    var isIndefinite: Bool { state == .active(endDate: nil) }

    // MARK: - Acciones

    /// Inicia una sesión, reemplazando la actual si la hay.
    func activate(_ duration: SessionDuration) {
        state = .active(endDate: endDate(for: duration))
        selectedOption = duration
        power.acquire()
        startTimer()
        refreshRemaining()
        emit(.started(duration))
    }

    @discardableResult
    func extend(byMinutes minutes: Int) -> ExtendResult {
        switch state {
        case .inactive:
            return .inactive
        case .active(endDate: nil):
            return .alreadyIndefinite
        case .active(endDate: let endDate?):
            // Si el fin ya pasó pero aún no se procesó, se suma desde ahora.
            let base = max(endDate, timeSource.now)
            state = .active(endDate: base.addingTimeInterval(TimeInterval(minutes * 60)))
            selectedOption = nil
            refreshRemaining()
            emit(.changed)
            return .extended
        }
    }

    /// Reemplaza el tiempo restante. Si no hay sesión, la inicia.
    func set(minutes: Int) {
        guard isActive else {
            activate(.minutes(minutes))
            return
        }
        state = .active(endDate: endDate(for: .minutes(minutes)))
        selectedOption = nil
        refreshRemaining()
        emit(.changed)
    }

    func makeIndefinite() {
        guard isActive else {
            activate(.indefinite)
            return
        }
        guard !isIndefinite else { return }
        state = .active(endDate: nil)
        selectedOption = .indefinite
        refreshRemaining()
        emit(.changed)
    }

    func deactivate() {
        end(.deactivated)
    }

    /// Comprueba si el tiempo se acabó y refresca el tiempo restante. Lo llama el temporizador cada segundo.
    func tick() {
        guard case .active(endDate: let endDate?) = state else { return }
        if timeSource.now >= endDate {
            end(.expired)
        } else {
            refreshRemaining()
        }
    }

    // MARK: - Eventos

    /// Un flujo nuevo de eventos. Puede haber varios oyentes a la vez (bot, avisos…).
    func events() -> AsyncStream<SessionEvent> {
        let (stream, continuation) = AsyncStream.makeStream(of: SessionEvent.self)
        let id = UUID()
        continuations[id] = continuation
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        return stream
    }

    // MARK: - Privado

    private func end(_ reason: SessionEndReason) {
        guard isActive else { return }
        state = .inactive
        selectedOption = nil
        remaining = nil
        timerTask?.cancel()
        timerTask = nil
        power.release()
        emit(.ended(reason))
    }

    private func endDate(for duration: SessionDuration) -> Date? {
        switch duration {
        case .indefinite: nil
        case .minutes(let minutes): timeSource.now.addingTimeInterval(TimeInterval(minutes * 60))
        }
    }

    private func refreshRemaining() {
        guard case .active(endDate: let endDate?) = state else {
            remaining = nil
            return
        }
        remaining = max(0, endDate.timeIntervalSince(timeSource.now))
    }

    private func startTimer() {
        guard timerTask == nil else { return }
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                self?.tick()
            }
        }
    }

    private func emit(_ event: SessionEvent) {
        for continuation in continuations.values {
            continuation.yield(event)
        }
    }
}
