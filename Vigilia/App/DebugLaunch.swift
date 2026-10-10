#if DEBUG
import SwiftUI

/// Solo en Debug: atajos de arranque para probar sin hacer clic en el menú.
///
///     open Vigilia.app --args -activate 10           # sesión de 10 minutos
///     open Vigilia.app --args -activate indefinite
///     open Vigilia.app --args -openSettings YES      # abre la configuración
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

    struct OpenSettingsOnLaunch: ViewModifier {
        @Environment(\.openSettings) private var openSettings

        func body(content: Content) -> some View {
            content.task {
                guard UserDefaults.standard.bool(forKey: "openSettings") else { return }
                try? await Task.sleep(for: .seconds(1))
                NSApplication.shared.activate()
                openSettings()
            }
        }
    }
}
#endif
