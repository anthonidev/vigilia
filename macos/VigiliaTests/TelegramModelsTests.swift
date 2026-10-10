import Foundation
import Testing
@testable import Vigilia

struct TelegramModelsTests {
    let decoder: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }()

    @Test func decodesMessageUpdate() throws {
        let json = """
            {"ok":true,"result":[{"update_id":10,"message":{"message_id":5,"date":1760000000,
            "from":{"id":123456789,"is_bot":false,"first_name":"Toni","username":"tonis","language_code":"es"},
            "chat":{"id":123456789,"first_name":"Toni","type":"private"},"text":"/estado",
            "entities":[{"offset":0,"length":7,"type":"bot_command"}]}}]}
            """
        let response = try decoder.decode(TelegramResponse<[TelegramUpdate]>.self, from: Data(json.utf8))
        let message = try #require(response.result?.first?.message)

        #expect(message.text == "/estado")
        #expect(message.from?.id == 123_456_789)
        #expect(message.chat.isPrivate)
    }

    @Test func decodesCallbackWithInaccessibleMessage() throws {
        let json = """
            {"update_id":11,"callback_query":{"id":"4382","chat_instance":"-1",
            "from":{"id":42,"is_bot":false,"first_name":"Toni"},
            "message":{"message_id":9,"date":0,"chat":{"id":42,"type":"private"}},"data":"ext:30"}}
            """
        let update = try decoder.decode(TelegramUpdate.self, from: Data(json.utf8))

        #expect(update.callbackQuery?.data == "ext:30")
        #expect(update.callbackQuery?.message?.chat.id == 42)
    }

    @Test func decodesErrorResponse() throws {
        let json = #"{"ok":false,"error_code":401,"description":"Unauthorized"}"#
        let response = try decoder.decode(TelegramResponse<TelegramUser>.self, from: Data(json.utf8))

        #expect(!response.ok)
        #expect(response.errorCode == 401)
    }

    @Test func encodesKeyboardInSnakeCase() throws {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let json = try #require(String(data: encoder.encode(BotKeyboards.controls), encoding: .utf8))

        #expect(json.contains("\"inline_keyboard\""))
        #expect(json.contains("\"callback_data\":\"ext:30\""))
    }
}
