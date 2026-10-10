import SwiftUI

@main
struct VigiliaApp: App {
    @State private var model = AppModel()

    init() {
        #if DEBUG
        DebugLaunch.apply(to: model.session)
        #endif
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContent(
                session: model.session,
                bot: model.bot,
                settings: model.settings,
                token: model.token,
                notifier: model.notifier
            )
        } label: {
            Image(nsImage: model.icon.image(active: model.session.isActive))
                .accessibilityLabel(model.session.statusText)
                #if DEBUG
                .modifier(DebugLaunch.OpenSettingsOnLaunch())
                #endif
        }

        Settings {
            SettingsView(
                settings: model.settings,
                token: model.token,
                loginItem: model.loginItem,
                linker: model.linker,
                bot: model.bot
            )
        }
    }
}
