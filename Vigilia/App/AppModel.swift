import Foundation

/// Crea y conecta las piezas de la app. Vive mientras la app esté abierta.
final class AppModel {
    let session: SessionManager
    let icon: MenuBarIcon
    let settings: AppSettings
    let token: TelegramTokenStore
    let loginItem: LoginItem
    let linker: AccountLinker
    let screenshots: ScreenshotService
    let bot: TelegramBot
    let notifier: SessionNotifier

    init() {
        session = SessionManager()
        icon = MenuBarIcon(session: session)
        settings = AppSettings()
        token = TelegramTokenStore()
        loginItem = LoginItem()
        linker = AccountLinker(settings: settings)
        screenshots = ScreenshotService()
        bot = TelegramBot(
            session: session,
            settings: settings,
            token: token,
            linker: linker,
            capturer: screenshots
        )
        notifier = SessionNotifier(session: session, settings: settings, token: token) { [bot] reply in
            try await bot.notify(reply)
        }
    }
}
