import Testing
@testable import Vigilia

@MainActor
struct StatusTextTests {
    @Test func sessionStatus() {
        let clock = FakeTimeSource()
        let session = SessionManager(timeSource: clock, power: FakePowerAssertion())
        #expect(session.statusText == "Vigilia inactiva")

        session.activate(.minutes(83))
        #expect(session.statusText == "Activa · quedan 1 h 23 min")

        session.makeIndefinite()
        #expect(session.statusText == "Activa · indefinida")
    }

    @Test func botStatusHiddenWhenBotDisabled() {
        #expect(BotStatusText.text(botEnabled: false, hasToken: true, isAccountLinked: true, status: .running) == nil)
    }

    @Test func botStatusExplainsWhatIsMissing() {
        #expect(BotStatusText.text(botEnabled: true, hasToken: false, isAccountLinked: true, status: .off) == "Bot: falta el token")
        #expect(BotStatusText.text(botEnabled: true, hasToken: true, isAccountLinked: false, status: .off) == "Bot: falta vincular la cuenta")
        #expect(BotStatusText.text(botEnabled: true, hasToken: true, isAccountLinked: true, status: .running) == "Bot conectado")
        #expect(BotStatusText.text(botEnabled: true, hasToken: true, isAccountLinked: true, status: .invalidToken) == "Bot: token inválido")
    }
}
