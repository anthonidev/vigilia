import Foundation
import Testing
@testable import Vigilia

@MainActor
struct AccountLinkerTests {
    let clock = FakeTimeSource()
    let settings: AppSettings
    let linker: AccountLinker
    let user = TelegramUser(id: 777, isBot: false, firstName: "Toni", username: "tonis")

    init() {
        let suite = "VigiliaTests.\(UUID().uuidString)"
        settings = AppSettings(defaults: UserDefaults(suiteName: suite)!)
        linker = AccountLinker(settings: settings, timeSource: clock)
    }

    @Test func startGeneratesSixDigitCode() {
        let code = linker.start()

        #expect(code.wholeMatch(of: /\d{6}/) != nil)
        #expect(linker.isLinking)
    }

    @Test func correctCodeLinksAccount() {
        let code = linker.start()

        #expect(linker.verify(code, from: user) == .linked)
        #expect(settings.authorizedUserID == 777)
        #expect(settings.authorizedUserName == "tonis")
        #expect(linker.state == .finished(.linked(name: "@tonis")))
        #expect(!linker.isLinking)
    }

    @Test func wrongCodeKeepsWaitingUntilTooManyAttempts() {
        let code = linker.start()
        let wrong = code == "000000" ? "111111" : "000000"

        for _ in 1..<AccountLinker.maxAttempts {
            #expect(linker.verify(wrong, from: user) == .wrongCode)
        }
        #expect(linker.verify(wrong, from: user) == .tooManyAttempts)
        #expect(linker.verify(code, from: user) == .notLinking)
        #expect(settings.authorizedUserID == nil)
    }

    @Test func expiredCodeIsRejected() {
        let code = linker.start()
        clock.advance(minutes: 5)

        #expect(linker.verify(code, from: user) == .expired)
        #expect(settings.authorizedUserID == nil)
    }

    @Test func newCodeReplacesOldOne() {
        let first = linker.start()
        let second = linker.start()
        guard first != second else { return }

        #expect(linker.verify(first, from: user) == .wrongCode)
        #expect(linker.verify(second, from: user) == .linked)
    }

    @Test func cancel() {
        linker.start()
        linker.cancel()

        #expect(linker.state == .finished(.cancelled))
        linker.reset()
        #expect(linker.state == .idle)
    }
}
