import Testing
@testable import Vigilia

struct BotCommandTests {
    @Test(arguments: [
        ("/estado", BotCommand.status),
        ("/ESTADO", .status),
        ("/estado@VigiliaBot", .status),
        ("/mas 30m", .extend(minutes: 30)),
        ("/más 1h", .extend(minutes: 60)),
        ("/set 2h", .set(minutes: 120)),
        ("/indefinido", .indefinite),
        ("/off", .off),
        ("/captura", .screenshot(hd: false)),
        ("/captura hd", .screenshot(hd: true)),
        ("/captura HD", .screenshot(hd: true)),
        ("/ayuda", .help),
        ("/start", .help),
        ("/start 482913", .link(code: "482913")),
        ("/vincular 482913", .link(code: "482913")),
        ("/foo", .unknown),
    ])
    func parsesText(text: String, expected: BotCommand) {
        #expect(BotCommand(text: text) == expected)
    }

    @Test func missingOrInvalidArgumentsExplainUsage() {
        guard case .invalidArgument = BotCommand(text: "/mas") else {
            Issue.record("/mas sin argumento debería explicar el uso")
            return
        }
        guard case .invalidArgument = BotCommand(text: "/set mañana") else {
            Issue.record("/set con texto inválido debería explicar el uso")
            return
        }
    }

    @Test func plainTextIsNotACommand() {
        #expect(BotCommand(text: "hola") == nil)
        #expect(BotCommand(text: "") == nil)
    }

    @Test(arguments: [
        ("ext:30", BotCommand.extend(minutes: 30)),
        ("ext:120", .extend(minutes: 120)),
        ("off", .off),
        ("shot", .screenshot(hd: false)),
        ("dismiss", .dismiss),
    ])
    func parsesCallbackData(data: String, expected: BotCommand) {
        #expect(BotCommand(callbackData: data) == expected)
    }

    @Test(arguments: ["", "ext:", "ext:0", "ext:99999", "ext:abc", "rm -rf"])
    func rejectsUnknownCallbackData(data: String) {
        #expect(BotCommand(callbackData: data) == nil)
    }
}
