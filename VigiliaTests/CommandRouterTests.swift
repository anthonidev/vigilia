import Testing
@testable import Vigilia

@MainActor
struct CommandRouterTests {
    let session = FakeSession()
    var router: CommandRouter { CommandRouter(session: session) }

    @Test func statusShowsRemainingTimeWithControls() {
        session.remaining = 83 * 60
        let reply = router.reply(to: .status)

        #expect(reply.text.contains("Quedan 1 h 23 min"))
        #expect(reply.keyboard == BotKeyboards.controls)
    }

    @Test func statusWhenIndefinite() {
        session.isIndefinite = true
        session.remaining = nil
        #expect(router.reply(to: .status).text.contains("indefinida"))
    }

    @Test func extendAddsTime() {
        let reply = router.reply(to: .extend(minutes: 30))

        #expect(session.extendCalls == [30])
        #expect(reply.text.contains("Sumados 30 min"))
        #expect(reply.text.contains("Quedan 1 h 30 min"))
    }

    @Test func extendWhenIndefinite() {
        session.extendResult = .alreadyIndefinite
        #expect(router.reply(to: .extend(minutes: 30)).text == "La sesión ya es indefinida.")
    }

    @Test func setReplacesTime() {
        let reply = router.reply(to: .set(minutes: 120))

        #expect(session.setCalls == [120])
        #expect(reply.text.contains("Quedan 2 h"))
    }

    @Test func indefinite() {
        _ = router.reply(to: .indefinite)
        #expect(session.isIndefinite)
    }

    @Test func offRepliesFirstAndDeactivatesAfter() {
        let reply = router.reply(to: .off)

        #expect(reply.followUp == .deactivate)
        #expect(!session.deactivated, "El router no desactiva: lo hace el bot después de responder")
    }

    @Test func inactiveSessionDoesNothing() {
        session.isActive = false

        for command in [BotCommand.status, .set(minutes: 30), .indefinite, .off] {
            let reply = router.reply(to: command)
            #expect(reply.text == BotText.inactive)
            #expect(reply.followUp == .none)
        }
        #expect(session.setCalls.isEmpty)
        #expect(!session.isIndefinite)
    }

    @Test func screenshotIsHandedToTheBot() {
        let reply = router.reply(to: .screenshot(ScreenshotRequest(hd: true)))
        #expect(reply.text.isEmpty)
        #expect(reply.followUp == .screenshot(ScreenshotRequest(hd: true)))

        session.isActive = false
        #expect(router.reply(to: .screenshot(ScreenshotRequest())).followUp == .none)
    }

    @Test func helpAndUnknown() {
        #expect(router.reply(to: .help).text.contains("/captura hd"))
        #expect(router.reply(to: .unknown).text.contains("/ayuda"))
        #expect(router.reply(to: .invalidArgument(usage: "Uso: /mas 30m")).text == "Uso: /mas 30m")
    }
}
