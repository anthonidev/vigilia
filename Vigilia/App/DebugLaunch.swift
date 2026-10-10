#if DEBUG
import Foundation

/// Solo en Debug: permite iniciar una sesión al arrancar, para probar sin hacer clic en el menú.
///
///     open Vigilia.app --args -activate 10           # 10 minutos
///     open Vigilia.app --args -activate indefinite
enum DebugLaunch {
    static func apply(to session: SessionManager) {
        guard let value = UserDefaults.standard.string(forKey: "activate") else { return }
        // Tras un instante, para que el ícono ya esté en la barra y se vea la animación.
        Task {
            try? await Task.sleep(for: .seconds(1))
            if value == "indefinite" {
                session.activate(.indefinite)
            } else if let minutes = Int(value), minutes > 0 {
                session.activate(.minutes(minutes))
            }
        }
    }
}
#endif
