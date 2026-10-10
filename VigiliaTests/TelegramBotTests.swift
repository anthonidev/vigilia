import Foundation
import Testing
@testable import Vigilia

@MainActor
@Suite(.serialized)
final class TelegramBotTests {
    static let owner: Int64 = 42
    static let stranger: Int64 = 99

    let session = FakeSession()
    let client = FakeTelegramClient()
    let capturer = FakeCapturer()
    let settings: AppSettings
    let token: TelegramTokenStore
    let linker: AccountLinker
    private let keychain = KeychainStore(service: "com.tonis.vigilia.tests.\(UUID().uuidString)")
    private var bot: TelegramBot?

    init() throws {
        settings = AppSettings(defaults: UserDefaults(suiteName: "VigiliaTests.\(UUID().uuidString)")!)
        settings.botEnabled = true
        settings.authorizedUserID = Self.owner
        token = TelegramTokenStore(keychain: keychain)
        try token.save("123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw")
        linker = AccountLinker(settings: settings)
    }

    deinit {
        try? keychain.delete(account: "telegram-bot-token")
    }

    private func startBot() -> TelegramBot {
        let client = client
        let bot = TelegramBot(
            session: session,
            settings: settings,
            token: token,
            linker: linker,
            capturer: capturer
        ) { _ in client }
        self.bot = bot
        return bot
    }

    private func sent() async -> [SentMessage] { await client.sent }

    @Test func discardsMessagesSentWhileOff() async {
        await client.setPending([Updates.text("/off", id: 10, from: Self.owner)])
        let bot = startBot()

        #expect(await eventually { await client.offsets.count >= 2 })
        #expect(await client.offsets.prefix(2) == [-1, 11])
        #expect(await client.commandsSet)
        #expect(await sent().isEmpty)
        #expect(!session.deactivated)
        #expect(bot.status == .connecting || bot.status == .running)
    }

    @Test func answersTheOwner() async {
        _ = startBot()
        await client.enqueue(Updates.text("/estado", id: 1, from: Self.owner))

        #expect(await eventually { await sent().count == 1 })
        let reply = await sent().first
        #expect(reply?.chatID == Self.owner)
        #expect(reply?.text.contains("Vigilia activa") == true)
        #expect(reply?.keyboard == BotKeyboards.controls)
    }

    @Test func ignoresOtherAccountsAndGroups() async {
        _ = startBot()
        await client.enqueue(
            Updates.text("/off", id: 1, from: Self.stranger),
            Updates.text("/off", id: 2, from: Self.owner, chatType: "group"),
            Updates.button("off", id: 3, from: Self.stranger),
            Updates.text("/estado", id: 4, from: Self.owner)
        )

        #expect(await eventually { await sent().count == 1 })
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await sent().map(\.chatID) == [Self.owner])
        #expect(await client.answeredCallbacks.isEmpty)
        #expect(!session.deactivated)
    }

    @Test func buttonsWork() async {
        _ = startBot()
        await client.enqueue(Updates.button("ext:30", id: 1, from: Self.owner))

        #expect(await eventually { await sent().count == 1 })
        #expect(session.extendCalls == [30])
        #expect(await client.answeredCallbacks == ["cb1"])
        #expect(await client.clearedKeyboards == [1])
    }

    @Test func dismissButton() async {
        _ = startBot()
        await client.enqueue(Updates.button("dismiss", id: 1, from: Self.owner))

        #expect(await eventually { await sent().count == 1 })
        #expect(await sent().first?.text.contains("terminará a su hora") == true)
        #expect(session.extendCalls.isEmpty)
    }

    @Test func notifySendsToLinkedAccountWithoutPolling() async throws {
        session.isActive = false
        let bot = startBot()
        #expect(bot.status == .off)

        try await bot.notify(BotReply(text: "Hola"))
        #expect(await sent() == [SentMessage(chatID: Self.owner, text: "Hola", keyboard: nil)])
    }

    @Test func offRepliesThenDeactivatesAndStops() async {
        let bot = startBot()
        await client.enqueue(Updates.text("/off", id: 1, from: Self.owner))

        #expect(await eventually { session.deactivated })
        #expect(session.deactivatedRemotely)
        #expect(await sent().first?.text.contains("desactivada") == true)
        #expect(await eventually { bot.status == .off })
    }

    @Test func stopsWhenSessionEnds() async {
        let bot = startBot()
        #expect(await eventually { await client.offsets.count >= 2 })

        session.isActive = false
        #expect(await eventually { bot.status == .off })

        // Ya apagado, lo que llegue no se procesa.
        await client.enqueue(Updates.text("/estado", id: 1, from: Self.owner))
        try? await Task.sleep(for: .milliseconds(50))
        #expect(await sent().isEmpty)
    }

    @Test func doesNotRunWithoutLinkedAccountOrWhenDisabled() async {
        settings.authorizedUserID = nil
        let bot = startBot()
        #expect(!bot.shouldRun)

        settings.authorizedUserID = Self.owner
        settings.botEnabled = false
        #expect(!bot.shouldRun)

        settings.botEnabled = true
        #expect(bot.shouldRun)
        #expect(await eventually { await client.offsets.count >= 1 })
    }

    @Test func linksAccountWithCode() async {
        settings.unlinkAccount()
        session.isActive = false
        let bot = startBot()
        #expect(bot.status == .off)

        let code = linker.start()
        #expect(await eventually { await client.offsets.count >= 2 })

        let newOwner: Int64 = 777
        await client.enqueue(
            Updates.text("/estado", id: 1, from: newOwner),
            Updates.text("/vincular 000000\(code == "000000" ? "1" : "")", id: 2, from: newOwner),
            Updates.text("/start \(code)", id: 3, from: newOwner)
        )

        #expect(await eventually { await sent().count == 2 })
        #expect(await sent().map(\.text) == [BotText.wrongCode, BotText.linked])
        #expect(settings.authorizedUserID == newOwner)
        // Sin sesión activa, el bot se apaga al terminar la vinculación.
        #expect(await eventually { bot.status == .off })
    }

    @Test func invalidTokenStopsWithError() async {
        await client.setError(.invalidToken)
        let bot = startBot()

        #expect(await eventually { bot.status == .invalidToken })
    }

    @Test func screenshotButtonSendsPhoto() async {
        _ = startBot()
        await client.enqueue(Updates.button("shot", id: 1, from: Self.owner))

        #expect(await eventually { await client.uploads.count == 1 })
        #expect(await client.uploads.first?.kind == .photo)
        #expect(await sent().isEmpty, "Una captura no lleva mensaje de texto aparte")
    }

    @Test func screenshotIgnoredForStrangers() async {
        _ = startBot()
        await client.enqueue(
            Updates.text("/captura", id: 1, from: Self.stranger),
            Updates.text("/estado", id: 2, from: Self.owner)
        )

        #expect(await eventually { await sent().count == 1 })
        #expect(await client.uploads.isEmpty)
        #expect(capturer.captured.isEmpty)
    }
}
