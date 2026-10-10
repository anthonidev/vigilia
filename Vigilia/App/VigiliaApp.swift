import SwiftUI

@main
struct VigiliaApp: App {
    @State private var session: SessionManager
    @State private var icon: MenuBarIcon
    @State private var settings = AppSettings()
    @State private var token = TelegramTokenStore()
    @State private var loginItem = LoginItem()

    init() {
        let session = SessionManager()
        _session = State(initialValue: session)
        _icon = State(initialValue: MenuBarIcon(session: session))

        #if DEBUG
        DebugLaunch.apply(to: session)
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(session: session)
        } label: {
            Image(nsImage: icon.image(active: session.isActive))
                .accessibilityLabel(session.statusText)
                #if DEBUG
                .modifier(DebugLaunch.OpenSettingsOnLaunch())
                #endif
        }

        Settings {
            SettingsView(settings: settings, token: token, loginItem: loginItem)
        }
    }
}
