import Foundation

nonisolated enum TelegramError: Error, Equatable, Sendable {
    /// El token no es válido (401) o no existe el bot (404).
    case invalidToken
    /// Otro proceso está leyendo los mensajes de este bot (409).
    case conflict
    case network(URLError.Code)
    case api(code: Int, description: String)
    case invalidResponse
}

/// Lo que el bot necesita de Telegram. Permite usar un cliente falso en los tests.
nonisolated protocol TelegramClient: Sendable {
    func getMe() async throws -> TelegramUser
    func getUpdates(offset: Int?, timeout: Int) async throws -> [TelegramUpdate]
    @discardableResult
    func sendMessage(chatID: Int64, text: String, keyboard: InlineKeyboardMarkup?) async throws -> TelegramMessage
    func editMessageReplyMarkup(chatID: Int64, messageID: Int, keyboard: InlineKeyboardMarkup?) async throws
    func answerCallbackQuery(id: String, text: String?) async throws
    func setMyCommands(_ commands: [BotCommandDescription]) async throws
    /// Envía una foto o un documento.
    func send(_ upload: TelegramUpload, chatID: Int64) async throws
    /// Envía varias fotos o documentos como un álbum (todos del mismo tipo, máximo 10).
    func sendMediaGroup(_ uploads: [TelegramUpload], chatID: Int64) async throws
    /// Muestra "enviando foto…" en el chat. `action`: "upload_photo" o "upload_document".
    func sendChatAction(_ action: String, chatID: Int64) async throws
}

/// Cliente HTTP de la Bot API. El token forma parte de la URL, así que nunca se registran URLs ni errores con URL.
actor TelegramAPI: TelegramClient {
    private let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(token: String, session: URLSession = .shared) {
        baseURL = URL(string: "https://api.telegram.org/bot\(token)/")!
        self.session = session
        encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
    }

    func getMe() async throws -> TelegramUser {
        try await call("getMe", Empty())
    }

    func getUpdates(offset: Int?, timeout: Int) async throws -> [TelegramUpdate] {
        try await call(
            "getUpdates",
            GetUpdates(offset: offset, timeout: timeout, allowedUpdates: ["message", "callback_query"]),
            // La petición debe durar más que el long polling.
            requestTimeout: TimeInterval(timeout + 15)
        )
    }

    @discardableResult
    func sendMessage(chatID: Int64, text: String, keyboard: InlineKeyboardMarkup?) async throws -> TelegramMessage {
        try await call("sendMessage", SendMessage(chatId: chatID, text: text, replyMarkup: keyboard))
    }

    func editMessageReplyMarkup(chatID: Int64, messageID: Int, keyboard: InlineKeyboardMarkup?) async throws {
        let _: IgnoredResult = try await call(
            "editMessageReplyMarkup",
            EditReplyMarkup(chatId: chatID, messageId: messageID, replyMarkup: keyboard)
        )
    }

    func answerCallbackQuery(id: String, text: String?) async throws {
        let _: IgnoredResult = try await call("answerCallbackQuery", AnswerCallback(callbackQueryId: id, text: text))
    }

    func setMyCommands(_ commands: [BotCommandDescription]) async throws {
        let _: IgnoredResult = try await call("setMyCommands", SetMyCommands(commands: commands))
    }

    func send(_ upload: TelegramUpload, chatID: Int64) async throws {
        var form = MultipartFormData()
        form.append(field: "chat_id", value: String(chatID))
        if let caption = upload.caption {
            form.append(field: "caption", value: caption)
        }
        form.append(file: upload.kind.rawValue, filename: upload.filename, mimeType: upload.mimeType, data: upload.data)

        let method = upload.kind == .photo ? "sendPhoto" : "sendDocument"
        let _: IgnoredResult = try await perform(multipart(method, form))
    }

    func sendMediaGroup(_ uploads: [TelegramUpload], chatID: Int64) async throws {
        var form = MultipartFormData()
        form.append(field: "chat_id", value: String(chatID))

        let media = uploads.enumerated().map { index, upload in
            InputMedia(type: upload.kind.rawValue, media: "attach://file\(index)", caption: upload.caption)
        }
        form.append(field: "media", value: String(decoding: try encoder.encode(media), as: UTF8.self))
        for (index, upload) in uploads.enumerated() {
            form.append(file: "file\(index)", filename: upload.filename, mimeType: upload.mimeType, data: upload.data)
        }

        let _: IgnoredResult = try await perform(multipart("sendMediaGroup", form))
    }

    func sendChatAction(_ action: String, chatID: Int64) async throws {
        let _: IgnoredResult = try await call("sendChatAction", ChatAction(chatId: chatID, action: action))
    }

    // MARK: - Privado

    private func call<Params: Encodable, Result: Decodable>(
        _ method: String,
        _ params: Params,
        requestTimeout: TimeInterval = 20
    ) async throws -> Result {
        var request = URLRequest(url: baseURL.appending(path: method))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(params)
        request.timeoutInterval = requestTimeout
        return try await perform(request)
    }

    /// Las subidas pueden tardar: una captura HD pesa varios MB.
    private func multipart(_ method: String, _ form: MultipartFormData) -> URLRequest {
        var request = URLRequest(url: baseURL.appending(path: method))
        request.httpMethod = "POST"
        request.setValue(form.contentType, forHTTPHeaderField: "Content-Type")
        request.httpBody = form.data
        request.timeoutInterval = 120
        return request
    }

    private func perform<Result: Decodable>(_ request: URLRequest) async throws -> Result {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch let error as URLError {
            // Solo el código: la descripción del error incluye la URL, y con ella el token.
            throw TelegramError.network(error.code)
        }

        let decoded = try? decoder.decode(TelegramResponse<Result>.self, from: data)
        if let decoded, decoded.ok, let result = decoded.result {
            return result
        }
        let code = decoded?.errorCode ?? (response as? HTTPURLResponse)?.statusCode ?? 0
        switch code {
        case 401, 404: throw TelegramError.invalidToken
        case 409: throw TelegramError.conflict
        case 0: throw TelegramError.invalidResponse
        default: throw TelegramError.api(code: code, description: decoded?.description ?? "")
        }
    }

    private struct Empty: Encodable {}

    private struct GetUpdates: Encodable {
        let offset: Int?
        let timeout: Int
        let allowedUpdates: [String]
    }

    private struct SendMessage: Encodable {
        let chatId: Int64
        let text: String
        let replyMarkup: InlineKeyboardMarkup?
    }

    private struct EditReplyMarkup: Encodable {
        let chatId: Int64
        let messageId: Int
        let replyMarkup: InlineKeyboardMarkup?
    }

    private struct AnswerCallback: Encodable {
        let callbackQueryId: String
        let text: String?
    }

    private struct SetMyCommands: Encodable {
        let commands: [BotCommandDescription]
    }

    private struct ChatAction: Encodable {
        let chatId: Int64
        let action: String
    }

    private struct InputMedia: Encodable {
        let type: String
        let media: String
        let caption: String?
    }
}
