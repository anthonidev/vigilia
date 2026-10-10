import Foundation
import Observation

/// Vinculación de la cuenta de Telegram con un código de 6 dígitos, válido 5 minutos.
@Observable
final class AccountLinker {
    nonisolated enum State: Equatable, Sendable {
        case idle
        case waiting(code: String, expiresAt: Date)
        case finished(Outcome)
    }

    nonisolated enum Outcome: Equatable, Sendable {
        case linked(name: String)
        case expired
        case tooManyAttempts
        case cancelled
    }

    nonisolated enum VerifyResult: Equatable, Sendable {
        case linked
        case wrongCode
        case expired
        case tooManyAttempts
        case notLinking
    }

    static let validity: TimeInterval = 5 * 60
    static let maxAttempts = 5

    private(set) var state: State = .idle

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private let timeSource: TimeSource
    @ObservationIgnored private var attempts = 0
    @ObservationIgnored private var expiryTask: Task<Void, Never>?

    init(settings: AppSettings, timeSource: TimeSource = SystemTimeSource()) {
        self.settings = settings
        self.timeSource = timeSource
    }

    var isLinking: Bool {
        if case .waiting = state { true } else { false }
    }

    /// Genera un código nuevo; invalida el anterior si lo había.
    @discardableResult
    func start() -> String {
        let code = String(format: "%06d", Int.random(in: 0...999_999))
        attempts = 0
        state = .waiting(code: code, expiresAt: timeSource.now.addingTimeInterval(Self.validity))

        expiryTask?.cancel()
        expiryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.validity))
            guard !Task.isCancelled else { return }
            self?.expireIfNeeded()
        }
        return code
    }

    /// Comprueba el código enviado al bot. Si es correcto, guarda la cuenta como autorizada.
    func verify(_ code: String, from user: TelegramUser) -> VerifyResult {
        guard case .waiting(let expected, let expiresAt) = state else { return .notLinking }

        guard timeSource.now < expiresAt else {
            finish(.expired)
            return .expired
        }
        guard code.trimmingCharacters(in: .whitespaces) == expected else {
            attempts += 1
            if attempts >= Self.maxAttempts {
                finish(.tooManyAttempts)
                return .tooManyAttempts
            }
            return .wrongCode
        }

        settings.authorizedUserID = user.id
        settings.authorizedUserName = user.username ?? user.firstName
        finish(.linked(name: user.displayName))
        return .linked
    }

    func cancel() {
        guard isLinking else { return }
        finish(.cancelled)
    }

    /// Vuelve al estado inicial (por ejemplo, al cerrar el mensaje de resultado en Ajustes).
    func reset() {
        guard !isLinking else { return }
        state = .idle
    }

    private func expireIfNeeded() {
        guard case .waiting(_, let expiresAt) = state, timeSource.now >= expiresAt else { return }
        finish(.expired)
    }

    private func finish(_ outcome: Outcome) {
        expiryTask?.cancel()
        expiryTask = nil
        state = .finished(outcome)
    }
}
