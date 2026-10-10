import AppKit
import Observation

/// Ícono de la barra de menú. Al iniciar o cambiar una sesión, el vapor sube unos segundos y se desvanece.
@Observable
final class MenuBarIcon {
    /// Fotograma actual del vapor; `nil` cuando no hay animación.
    private(set) var steam: SteamFrame?

    @ObservationIgnored private var animation: Task<Void, Never>?
    @ObservationIgnored private var listener: Task<Void, Never>?

    nonisolated private static let duration = 3.0
    nonisolated private static let cycle = 1.2
    nonisolated private static let fadeIn = 0.3
    nonisolated private static let fadeOut = 0.8

    init(session: SessionManager) {
        let events = session.events()
        listener = Task { [weak self] in
            for await event in events {
                switch event {
                case .started, .changed: self?.playSteam()
                case .ended: self?.stopSteam()
                case .tenMinutesLeft: break
                }
            }
        }
    }

    func image(active: Bool) -> NSImage {
        CupIcon.image(active: active, steam: steam)
    }

    func playSteam() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        animation?.cancel()
        animation = Task { [weak self] in
            let clock = ContinuousClock()
            let start = clock.now
            while !Task.isCancelled {
                let elapsed = (clock.now - start) / .seconds(1)
                guard elapsed < Self.duration else { break }
                self?.steam = SteamFrame(
                    phase: (elapsed / Self.cycle).truncatingRemainder(dividingBy: 1),
                    intensity: Self.intensity(at: elapsed)
                )
                // ~20 fotogramas por segundo: suficiente para un ícono de 18 pt.
                try? await Task.sleep(for: .milliseconds(50))
            }
            self?.steam = nil
        }
    }

    func stopSteam() {
        animation?.cancel()
        animation = nil
        steam = nil
    }

    /// Aparece al principio y se desvanece al final, para no cortar de golpe.
    nonisolated static func intensity(at elapsed: Double) -> Double {
        let fadingIn = elapsed / fadeIn
        let fadingOut = (duration - elapsed) / fadeOut
        return min(1, max(0, min(fadingIn, fadingOut)))
    }
}
