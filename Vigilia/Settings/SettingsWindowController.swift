import AppKit
import SwiftUI

/// Ventana de ajustes propia: la escena `Settings` de SwiftUI solo se puede abrir desde vistas SwiftUI.
final class SettingsWindowController {
    private let model: AppModel
    private var window: NSWindow?

    init(model: AppModel) {
        self.model = model
    }

    func show() {
        let window = window ?? makeWindow()
        self.window = window
        // Una app sin Dock no trae sus ventanas al frente por sí sola.
        NSApplication.shared.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow() -> NSWindow {
        let view = SettingsView(
            settings: model.settings,
            token: model.token,
            loginItem: model.loginItem,
            linker: model.linker,
            bot: model.bot,
            screenshots: model.screenshots,
            icon: model.icon
        )
        let hosting = NSHostingController(rootView: view)
        // Que la ventana siga al contenido (por ejemplo, al mostrar el código de vinculación).
        hosting.sizingOptions = .intrinsicContentSize

        let window = NSWindow(contentViewController: hosting)
        window.title = "Ajustes de Vigilia"
        window.styleMask = [.titled, .closable]
        window.isReleasedWhenClosed = false
        window.center()
        return window
    }
}
