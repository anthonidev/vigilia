import Foundation
import Testing
@testable import Vigilia

@MainActor
struct SessionNotifierMessageTests {
    let now = Date(timeIntervalSinceReferenceDate: 1_000_000)

    @Test func startedMessages() {
        let timed = SessionNotifier.message(for: .started(.minutes(120)), now: now)
        #expect(timed?.text == "☕ Vigilia activa por 2 h.")
        #expect(timed?.keyboard == BotKeyboards.controls)

        let indefinite = SessionNotifier.message(for: .started(.indefinite), now: now)
        #expect(indefinite?.text.contains("indefinida") == true)
    }

    @Test func tenMinutesLeftOffersMoreTime() {
        let message = SessionNotifier.message(for: .tenMinutesLeft, now: now)
        #expect(message?.text == "⏳ Quedan 10 min. ¿Ampliar?")
        #expect(message?.keyboard == BotKeyboards.tenMinutesLeft)
    }

    @Test func endedOnTime() {
        let message = SessionNotifier.message(for: .ended(.expired(at: now)), now: now.addingTimeInterval(1))
        #expect(message?.text == "😴 Sesión terminada. Tu Mac ya puede dormir.")
    }

    @Test func endedWhileAsleepMentionsTheTime() {
        let message = SessionNotifier.message(for: .ended(.expired(at: now)), now: now.addingTimeInterval(3600))
        #expect(message?.text.contains("mientras la Mac dormía") == true)
    }

    @Test func noMessageForChangesOrRemoteOff() {
        #expect(SessionNotifier.message(for: .changed, now: now) == nil)
        #expect(SessionNotifier.message(for: .ended(.deactivatedRemotely), now: now) == nil)
        #expect(SessionNotifier.message(for: .ended(.deactivated), now: now) != nil)
    }
}

@MainActor
@Suite(.serialized)
final class SessionNotifierTests {
    let clock = FakeTimeSource()
    let session: SessionManager
    let settings: AppSettings
    let token: TelegramTokenStore
    private let keychain = KeychainStore(service: "com.tonis.vigilia.tests.\(UUID().uuidString)")
    private(set) var sent: [String] = []
    private var notifier: SessionNotifier!

    init() throws {
        session = SessionManager(timeSource: clock, power: FakePowerAssertion())
        settings = AppSettings(defaults: UserDefaults(suiteName: "VigiliaTests.\(UUID().uuidString)")!)
        settings.botEnabled = true
        settings.authorizedUserID = 42
        token = TelegramTokenStore(keychain: keychain)
        try token.save("123456789:AAHdqTcvCH1vGWJxfSeofSAs0K5PALDsaw")
        notifier = SessionNotifier(session: session, settings: settings, token: token, timeSource: clock) { [weak self] reply in
            self?.sent.append(reply.text)
        }
    }

    deinit {
        try? keychain.delete(account: "telegram-bot-token")
    }

    @Test func sendsTheThreeNotices() async {
        session.activate(.minutes(30))
        clock.advance(minutes: 20)
        session.tick()
        clock.advance(minutes: 10)
        session.tick()

        await notifier.flush(timeout: .seconds(2))
        #expect(sent.count == 3)
        #expect(sent[0].contains("activa por 30 min"))
        #expect(sent[1].contains("Quedan 10 min"))
        #expect(sent[2].contains("Sesión terminada"))
    }

    @Test func respectsTheSetting() async {
        settings.notificationsEnabled = false
        session.activate(.minutes(30))
        session.deactivate()

        await notifier.flush(timeout: .seconds(1))
        #expect(sent.isEmpty)
    }

    @Test func silentWithoutLinkedAccountOrBot() async {
        settings.unlinkAccount()
        session.activate(.minutes(30))
        settings.authorizedUserID = 42
        settings.botEnabled = false
        session.deactivate()

        await notifier.flush(timeout: .seconds(1))
        #expect(sent.isEmpty)
    }

    @Test func endNoticeIsQueuedBeforeDeactivateReturns() async {
        session.activate(.indefinite)
        await notifier.flush(timeout: .seconds(1))
        sent.removeAll()

        // Lo que hace "Salir": desactivar y esperar a que salga el aviso.
        session.deactivate()
        await notifier.flush(timeout: .seconds(2))
        #expect(sent == ["😴 Sesión desactivada desde la Mac. Tu Mac ya puede dormir."])
    }
}
