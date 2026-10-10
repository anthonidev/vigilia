import Foundation
import Observation

/// Ajustes de la app guardados en `UserDefaults`. El token va aparte, en el Keychain.
@Observable
final class AppSettings {
    var botEnabled: Bool {
        didSet { defaults.set(botEnabled, forKey: Keys.botEnabled) }
    }

    var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Keys.notificationsEnabled) }
    }

    /// ID de usuario de Telegram al que obedece el bot.
    var authorizedUserID: Int64? {
        didSet { defaults.set(authorizedUserID, forKey: Keys.authorizedUserID) }
    }

    /// Nombre de esa cuenta, solo para mostrarlo en Ajustes.
    var authorizedUserName: String? {
        didSet { defaults.set(authorizedUserName, forKey: Keys.authorizedUserName) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.register(defaults: [
            Keys.botEnabled: false,
            Keys.notificationsEnabled: true,
        ])
        botEnabled = defaults.bool(forKey: Keys.botEnabled)
        notificationsEnabled = defaults.bool(forKey: Keys.notificationsEnabled)
        authorizedUserID = (defaults.object(forKey: Keys.authorizedUserID) as? NSNumber)?.int64Value
        authorizedUserName = defaults.string(forKey: Keys.authorizedUserName)
    }

    var isAccountLinked: Bool { authorizedUserID != nil }

    func unlinkAccount() {
        authorizedUserID = nil
        authorizedUserName = nil
    }

    private enum Keys {
        static let botEnabled = "botEnabled"
        static let notificationsEnabled = "notificationsEnabled"
        static let authorizedUserID = "authorizedUserID"
        static let authorizedUserName = "authorizedUserName"
    }
}
