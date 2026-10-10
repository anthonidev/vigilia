import Foundation
import Testing
@testable import Vigilia

@MainActor
struct AppSettingsTests {
    let defaults: UserDefaults

    init() {
        let suite = "VigiliaTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
    }

    @Test func defaultValues() {
        let settings = AppSettings(defaults: defaults)

        #expect(!settings.botEnabled)
        #expect(settings.notificationsEnabled)
        #expect(settings.authorizedUserID == nil)
        #expect(!settings.isAccountLinked)
    }

    @Test func valuesPersistAcrossInstances() {
        let settings = AppSettings(defaults: defaults)
        settings.botEnabled = true
        settings.notificationsEnabled = false
        settings.authorizedUserID = 123_456_789_012
        settings.authorizedUserName = "tonis"

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.botEnabled)
        #expect(!reloaded.notificationsEnabled)
        #expect(reloaded.authorizedUserID == 123_456_789_012)
        #expect(reloaded.authorizedUserName == "tonis")
    }

    @Test func unlinkClearsAccount() {
        let settings = AppSettings(defaults: defaults)
        settings.authorizedUserID = 42
        settings.authorizedUserName = "tonis"
        settings.unlinkAccount()

        let reloaded = AppSettings(defaults: defaults)
        #expect(reloaded.authorizedUserID == nil)
        #expect(reloaded.authorizedUserName == nil)
    }
}

/// Usa el Keychain real con un servicio propio de los tests, que se limpia al terminar.
@MainActor
@Suite(.serialized)
struct KeychainTests {
    let keychain = KeychainStore(service: "com.tonis.vigilia.tests")
    let validToken = "123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"

    @Test func saveLoadUpdateDelete() throws {
        defer { try? keychain.delete(account: "test") }

        #expect(try keychain.load(account: "test") == nil)
        try keychain.save("uno", account: "test")
        #expect(try keychain.load(account: "test") == "uno")
        try keychain.save("dos", account: "test")
        #expect(try keychain.load(account: "test") == "dos")
        try keychain.delete(account: "test")
        #expect(try keychain.load(account: "test") == nil)
        try keychain.delete(account: "test") // borrar algo que no existe no falla
    }

    @Test func tokenStoreTrimsAndTracksPresence() throws {
        let store = TelegramTokenStore(keychain: keychain)
        defer { try? store.delete() }
        try? store.delete()

        #expect(!store.hasToken)
        try store.save("  \(validToken)\n")
        #expect(store.hasToken)
        #expect(try store.load() == validToken)
        #expect(TelegramTokenStore(keychain: keychain).hasToken)

        try store.delete()
        #expect(!store.hasToken)
    }

    @Test func tokenStoreRejectsInvalidTokens() {
        let store = TelegramTokenStore(keychain: keychain)
        #expect(throws: TelegramTokenStore.TokenError.self) {
            try store.save("hola")
        }
        #expect(!store.hasToken)
    }
}

struct TokenFormatTests {
    @Test(arguments: [
        "123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw",
        "7012345678:AAF-abc_DEF123ghi456JKL789mno012PQR3",
    ])
    func acceptsBotFatherTokens(token: String) {
        #expect(TelegramTokenStore.isPlausible(token))
    }

    @Test(arguments: ["", "hola", "123:abc", "abc:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw", "123456789 AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw"])
    func rejectsOtherText(token: String) {
        #expect(!TelegramTokenStore.isPlausible(token))
    }
}
