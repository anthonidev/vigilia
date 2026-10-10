import AppKit
import Observation

/// Ícono de la barra de menú. Al iniciar o cambiar una sesión, se anima unos segundos
/// según el estilo elegido en Ajustes (vapor, llama o rayos de luz).
@Observable
final class MenuBarIcon {
    /// Fotograma actual de la animación; `nil` cuando no hay animación.
    private(set) var frame: IconAnimationFrame?

    @ObservationIgnored private let settings: AppSettings
    @ObservationIgnored private var animation: Task<Void, Never>?
    @ObservationIgnored private var listener: Task<Void, Never>?

    nonisolated private static let duration = 3.0
    nonisolated private static let cycle = 1.2
    nonisolated private static let fadeIn = 0.3
    nonisolated private static let fadeOut = 0.8

    init(session: SessionManager, settings: AppSettings) {
        self.settings = settings
        let events = session.events()
        listener = Task { [weak self] in
            for await event in events {
                switch event {
                case .started, .changed: self?.playAnimation()
                case .ended: self?.stopAnimation()
                case .tenMinutesLeft: break
                }
            }
        }
    }

    func image(active: Bool) -> NSImage {
        MenuBarIconRenderer.image(style: settings.iconStyle, active: active, frame: frame)
    }

    func playAnimation() {
        guard !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        animation?.cancel()
        animation = Task { [weak self] in
            let clock = ContinuousClock()
            let start = clock.now
            while !Task.isCancelled {
                let elapsed = (clock.now - start) / .seconds(1)
                guard elapsed < Self.duration else { break }
                self?.frame = IconAnimationFrame(
                    phase: (elapsed / Self.cycle).truncatingRemainder(dividingBy: 1),
                    intensity: Self.intensity(at: elapsed)
                )
                // ~20 fotogramas por segundo: suficiente para un ícono de 18 pt.
                try? await Task.sleep(for: .milliseconds(50))
            }
            self?.frame = nil
        }
    }

    func stopAnimation() {
        animation?.cancel()
        animation = nil
        frame = nil
    }

    /// Aparece al principio y se desvanece al final, para no cortar de golpe.
    nonisolated static func intensity(at elapsed: Double) -> Double {
        let fadingIn = elapsed / fadeIn
        let fadingOut = (duration - elapsed) / fadeOut
        return min(1, max(0, min(fadingIn, fadingOut)))
    }
}
