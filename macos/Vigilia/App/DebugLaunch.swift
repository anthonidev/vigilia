#if DEBUG
import Foundation

/// Solo en Debug: atajos de arranque para probar sin hacer clic en el menú.
///
///     open Vigilia.app --args -activate 10           # sesión de 10 minutos
///     open Vigilia.app --args -activate indefinite
///     open Vigilia.app --args -openSettings YES      # abre la configuración
enum DebugLaunch {
    static func apply(to session: SessionManager, openSettings: @escaping () -> Void) {
        let defaults = UserDefaults.standard
        let activate = defaults.string(forKey: "activate")
        let showSettings = defaults.bool(forKey: "openSettings")
        guard activate != nil || showSettings else { return }

        // Tras un instante, para que el ícono ya esté en la barra y se vea la animación.
        Task {
            try? await Task.sleep(for: .seconds(1))
            if showSettings {
                openSettings()
            }
            if activate == "indefinite" {
                session.activate(.indefinite)
            } else if let minutes = activate.flatMap(Int.init), minutes > 0 {
                session.activate(.minutes(minutes))
            }
        }
    }
}
#endif
