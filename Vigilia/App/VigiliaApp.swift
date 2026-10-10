import SwiftUI

@main
struct VigiliaApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        // La barra de menú y los ajustes los gestiona AppDelegate con AppKit.
        // SwiftUI exige al menos una escena; sin menú de app, esta nunca se abre.
        Settings { EmptyView() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var model: AppModel?
    private var statusItem: StatusItemController?
    private var settingsWindow: SettingsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Los tests usan la app como anfitrión: no hace falta ícono ni bot.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let model = AppModel()
        let settingsWindow = SettingsWindowController(model: model)
        statusItem = StatusItemController(model: model) { settingsWindow.show() }
        self.model = model
        self.settingsWindow = settingsWindow

        #if DEBUG
        DebugLaunch.apply(to: model.session, openSettings: settingsWindow.show)
        #endif
    }
}
